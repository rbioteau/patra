import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verso/src/features/reader/thumb_strip.dart';

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

      queue.update(visible: {4, 5, 6, 7, 8, 9, 10}, current: 7);
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

      queue.update(visible: {0, 1, 2, 3, 4, 5}, current: 3);
      await pumpEventQueue();
      expect(started, [3, 2]);

      gates[3]!.complete();
      await pumpEventQueue();
      expect(started, [3, 2, 4]);
    });

    test('holds everything back for the start delay', () async {
      final queue = ThumbLoadQueue(
        load: load,
        startDelay: const Duration(milliseconds: 60),
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1, 2}, current: 1);
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

      queue.update(visible: {0, 1, 2}, current: 1);
      queue.update(visible: {40, 41, 42}, current: 41);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(started, [41]);
    });

    test('a page that fails is not retried, and is shown anyway', () async {
      final queue = ThumbLoadQueue(
        load: (page) => Future<void>.error(Exception('404')),
        startDelay: Duration.zero,
        maxConcurrent: 1,
      );
      addTearDown(queue.dispose);

      queue.update(visible: {0, 1}, current: 0);
      await pumpEventQueue();
      expect(queue.isReady(0), isTrue);
      expect(queue.isReady(1), isTrue);
    });

    test('a disposed queue starts nothing', () async {
      final queue = ThumbLoadQueue(load: load, startDelay: Duration.zero)
        ..dispose();
      queue.update(visible: {0, 1}, current: 0);
      await pumpEventQueue();
      expect(started, isEmpty);
    });
  });

  group('ThumbStrip', () {
    Future<void> pump(WidgetTester tester, int current, {int pages = 40}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ThumbStrip(
                  pages: pages,
                  current: current,
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

      expect(sizeOf(tester, 20), const Size(46, 64));
      expect(sizeOf(tester, 19), const Size(40, 56));
      expect(sizeOf(tester, 21), const Size(40, 56));
      expect(sizeOf(tester, 18), const Size(34, 48));
      expect(sizeOf(tester, 22), const Size(34, 48));
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
      const inset = 12 + 46 / 2;

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
      // Five pages cannot fill a scrolling strip, so the thumbnails spread out
      // instead: each one lands under the slider handle for its own page,
      // which is what the scrolling strip achieves by moving.
      const pages = 5;
      const inset = 12 + 46 / 2;
      await pump(tester, 1, pages: pages);

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

      expect(sizeOf(tester, 21), const Size(46, 64));
      expect(sizeOf(tester, 20), const Size(40, 56));
      expect(sizeOf(tester, 19), const Size(34, 48));
    });
  });
}
