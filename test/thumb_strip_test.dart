import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/thumb_strip.dart';

void main() {
  group('ThumbLoadQueue', () {
    late List<int> started;
    late Map<int, Completer<void>> gates;

    Future<void> load(int page) {
      started.add(page);
      return (gates[page] = Completer<void>()).future;
    }

    setUp(() {
      started = [];
      gates = {};
    });

    test('serves the current page, then its neighbours, outwards', () async {
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: Duration.zero,
        maxConcurrent: 1,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {4, 5, 6, 7, 8, 9, 10}, current: 7, pages: 11);
      await pumpEventQueue();
      expect(started, [7]);

      for (final expected in [6, 8, 5, 9, 4, 10]) {
        gates[started.last]!.complete();
        await pumpEventQueue();
        expect(started.last, expected);
      }
    });

    test('never runs more than maxConcurrent fetches at once', () async {
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: Duration.zero,
        maxConcurrent: 2,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1, 2, 3, 4, 5}, current: 3, pages: 6);
      await pumpEventQueue();
      // The first goes alone; the cap governs everything after it.
      expect(started, [3]);

      gates[3]!.complete();
      await pumpEventQueue();
      expect(started, [3, 2, 4]);

      gates[2]!.complete();
      await pumpEventQueue();
      expect(started, [3, 2, 4, 1]);
    });

    test('holds everything back for the start delay', () async {
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: const Duration(milliseconds: 60),
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1, 2}, current: 1, pages: 3);
      await pumpEventQueue();
      expect(started, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(started, isNotEmpty);
    });

    test('a scroll before the delay elapses only moves the queue', () async {
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: const Duration(milliseconds: 60),
        maxConcurrent: 1,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1, 2}, current: 1, pages: 43);
      queue.update(visible: {40, 41, 42}, current: 41, pages: 43);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(started, [41]);
    });

    test('scrolling does not push the start delay back', () async {
      // The strip calls update on every scroll frame, and glides for 200 ms on
      // every page turn. If each call rescheduled the delay, nothing would
      // start loading until the strip stood perfectly still.
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: const Duration(milliseconds: 60),
        maxConcurrent: 1,
      );
      addTearDown(queue.dispose);

      for (var frame = 0; frame < 12; frame++) {
        queue.update(
          visible: {frame, frame + 1, frame + 2},
          current: 1,
          pages: 20,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(started, isNotEmpty);
    });

    test('the first fetch of a chapter goes alone', () async {
      // Kavita renders every page's thumbnail inside the first request for a
      // chapter, and guards that on a directory nothing has created yet: a
      // second request sent before the first answers makes the server do the
      // whole chapter twice.
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: Duration.zero,
        maxConcurrent: 4,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1, 2, 3, 4, 5}, current: 2, pages: 6);
      await pumpEventQueue();
      expect(started, [2]);

      // Answered: the chapter is rendered, and the rest may go in parallel.
      gates[2]!.complete();
      await pumpEventQueue();
      expect(started.length, 5);
    });

    test('an idle strip works through the rest of the chapter', () async {
      // A thumbnail costs ~200 ms to fetch and ~2 ms to read back, so the
      // scrubber that has been left open once is instant the next time.
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: Duration.zero,
        maxConcurrent: 4,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1, 2}, current: 1, pages: 8);
      await pumpEventQueue();
      expect(started, [1]);

      gates[1]!.complete();
      await pumpEventQueue();
      expect(started, [1, 0, 2], reason: 'the rest of the screen, in parallel');

      gates[0]!.complete();
      gates[2]!.complete();
      await pumpEventQueue();
      expect(started, [1, 0, 2, 3], reason: 'then off screen, one at a time');

      gates[3]!.complete();
      await pumpEventQueue();
      expect(started, [1, 0, 2, 3, 4]);
    });

    test('the backfill never gets ahead of what is on screen', () async {
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: Duration.zero,
        maxConcurrent: 4,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0}, current: 0, pages: 40);
      await pumpEventQueue();
      gates[0]!.complete();
      await pumpEventQueue();
      expect(started, [0, 1], reason: 'one page beyond the screen');

      // The strip scrolls while that backfill is still out: the pages now on
      // screen must not queue behind the rest of the chapter.
      queue.update(visible: {20, 21, 22}, current: 21, pages: 40);
      gates[1]!.complete();
      await pumpEventQueue();
      expect(started.sublist(2), [21, 20, 22]);
    });

    test('a page that fails is not retried, and is shown anyway', () async {
      final queue = ThumbLoadQueue(
        load: (page) => Future<void>.error(Exception('404')),
        startDelay: Duration.zero,
        maxConcurrent: 1,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1}, current: 0, pages: 2);
      await pumpEventQueue();
      expect(queue.isReady(0), isTrue);
      expect(queue.isReady(1), isTrue);
    });

    test('a disposed queue starts nothing', () async {
      final queue = ThumbLoadQueue(load: load, startDelay: Duration.zero)
        ..dispose();
      queue.update(visible: {0, 1}, current: 0, pages: 2);
      await pumpEventQueue();
      expect(started, isEmpty);
    });
  });

  group('ThumbStrip', () {
    Future<void> pump(
      WidgetTester tester,
      int current, {
      int pages = 40,
      bool tablet = false,
      double width = 300,
    }) async {
      // The strip reads its scale off the screen, so a test that pins its
      // geometry has to say which screen it is on. The default test surface
      // (800x600) is a tablet by the app's own rule.
      tester.view.physicalSize = tablet
          ? const Size(1640, 2360) // an iPad in portrait
          : const Size(1170, 2532); // a phone
      tester.view.devicePixelRatio = tablet ? 2 : 3;
      addTearDown(tester.view.reset);
      // No delay: the strip owns none of the queue's timers any more, and a
      // widget test refuses to end with one still pending.
      final queue = ThumbLoadQueue(
        load: (_) async {},
        startDelay: Duration.zero,
      );
      addTearDown(queue.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: ThumbStrip(
                  pages: pages,
                  current: current,
                  queue: queue,
                  // No image at all: the accordion is pure geometry.
                  providerBuilder: (_) => null,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Size sizeOf(WidgetTester tester, int page) =>
        tester.getSize(find.byKey(ValueKey(page)));

    testWidgets('the current page is the widest, its neighbours next', (
      tester,
    ) async {
      await pump(tester, 20);

      expect(sizeOf(tester, 20), const Size(92, 128));
      expect(sizeOf(tester, 19), const Size(80, 112));
      expect(sizeOf(tester, 21), const Size(80, 112));
      expect(sizeOf(tester, 18), const Size(68, 96));
      expect(sizeOf(tester, 22), const Size(68, 96));
    });

    testWidgets('the swollen thumbnail travels where the slider handle does', (
      tester,
    ) async {
      // The chrome shows a strip and a slider one above the other; a bulge
      // that stays centred while the handle moves reads as two different
      // "you are here" markers. 41 pages puts page 20 exactly halfway.
      const pages = 41;
      // Half the current thumbnail plus the strip's own padding: the inset
      // the handle also starts from.
      const inset = 12 + 92 / 2;

      await pump(tester, 0, pages: pages);
      final strip = tester.getRect(find.byType(ThumbStrip));
      expect(
        tester.getCenter(find.byKey(const ValueKey(0))).dx,
        moreOrLessEquals(strip.left + inset, epsilon: 0.5),
      );

      await pump(tester, 20, pages: pages);
      expect(
        tester.getCenter(find.byKey(const ValueKey(20))).dx,
        moreOrLessEquals(strip.center.dx, epsilon: 0.5),
      );

      await pump(tester, pages - 1, pages: pages);
      expect(
        tester.getCenter(find.byKey(const ValueKey(pages - 1))).dx,
        moreOrLessEquals(strip.right - inset, epsilon: 0.5),
      );
    });

    testWidgets('a chapter that fits spreads across the strip', (tester) async {
      // A handful of pages cannot fill a scrolling strip, so the thumbnails
      // spread out instead: each one lands under the slider handle for its own
      // page, which is what the scrolling strip achieves by moving.
      const pages = 3;
      const inset = 12 + 92 / 2;
      // Wide enough that thumbnails this size can spread without the two
      // widest touching, which is where spreading gives up.
      await pump(tester, 1, pages: pages, width: 340);

      final strip = tester.getRect(find.byType(ThumbStrip));
      final travel = strip.width - inset * 2;
      for (var page = 0; page < pages; page++) {
        expect(
          tester.getCenter(find.byKey(ValueKey(page))).dx,
          moreOrLessEquals(
            strip.left + inset + travel * page / (pages - 1),
            epsilon: 0.5,
          ),
          reason: 'page $page',
        );
      }
    });

    testWidgets('a single page sits in the middle', (tester) async {
      await pump(tester, 0, pages: 1);

      final strip = tester.getRect(find.byType(ThumbStrip));
      expect(
        tester.getCenter(find.byKey(const ValueKey(0))).dx,
        moreOrLessEquals(strip.center.dx, epsilon: 0.5),
      );
    });

    testWidgets('the accordion follows the page being read', (tester) async {
      await pump(tester, 20);
      await pump(tester, 21);

      expect(sizeOf(tester, 21), const Size(92, 128));
      expect(sizeOf(tester, 20), const Size(80, 112));
      expect(sizeOf(tester, 19), const Size(68, 96));
    });

    testWidgets('a tablet gets the same strip, drawn larger', (tester) async {
      // The scrubber is aimed at, not merely read: 34pt of it on an iPad is a
      // stamp. Every length scales together, so the accordion's law — widest
      // in the middle, its neighbours halfway — is the one pinned above.
      // Wide enough to hold the current page and two on either side: they
      // are what the accordion is made of.
      await pump(tester, 20, tablet: true, width: 600);

      final current = sizeOf(tester, 20);
      final near = sizeOf(tester, 19);
      final base = sizeOf(tester, 18);
      expect(current.width, greaterThan(120));
      expect(base.width, greaterThan(90));
      expect(current.width / current.height, closeTo(92 / 128, 0.001));
      expect(near.width / base.width, closeTo(80 / 68, 0.001));
      // Still an accordion, and still centred on the tallest.
      expect(current.height, greaterThan(near.height));
      expect(near.height, greaterThan(base.height));
      expect(
        tester.getCenter(find.byKey(const ValueKey(20))).dy,
        moreOrLessEquals(
          tester.getCenter(find.byKey(const ValueKey(18))).dy,
          epsilon: 0.5,
        ),
      );
    });
  });
}
