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
    /// What the last [pump] built, so [pumpCurrent] can turn a page without
    /// building a second strip — the state, and the accordion's clock with it,
    /// has to be the one that was already there.
    late Widget Function(int current) rebuild;

    Future<void> pump(
      WidgetTester tester,
      int current, {
      int pages = 40,
      bool tablet = false,
      bool landscape = false,
      double width = 300,
    }) async {
      // The strip reads its scale off the screen, so a test that pins its
      // geometry has to say which screen it is on. The default test surface
      // (800x600) is a tablet by the app's own rule.
      tester.view.physicalSize = switch ((tablet, landscape)) {
        (true, _) => const Size(1640, 2360), // an iPad in portrait
        (false, true) => const Size(2532, 1170), // a phone on its side
        (false, false) => const Size(1170, 2532), // a phone
      };
      tester.view.devicePixelRatio = tablet ? 2 : 3;
      addTearDown(tester.view.reset);
      // No delay: the strip owns none of the queue's timers any more, and a
      // widget test refuses to end with one still pending.
      final queue = ThumbLoadQueue(
        load: (_) async {},
        startDelay: Duration.zero,
      );
      addTearDown(queue.dispose);
      rebuild = (page) => MaterialApp(
        home: Scaffold(
          // As the reader has it: the strip sits under an `OrientationBuilder`,
          // so every build below it runs inside a layout callback. That is not
          // decoration — it is the phase in which the strip is asked to move,
          // and the reason it may not touch its scroll offset from a build.
          body: OrientationBuilder(
            builder: (context, _) => Center(
              child: SizedBox(
                width: width,
                child: ThumbStrip(
                  pages: pages,
                  current: page,
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
      await tester.pumpWidget(rebuild(current));
      await tester.pumpAndSettle();
      // The strip takes its first aim in a frame callback, and asks the queue
      // for its window there — which arms the queue's own zero-delay timer
      // after the last frame `pumpAndSettle` had to pump. One more turn of the
      // loop lets it fire, or the test ends with a timer pending.
      await tester.pump(Duration.zero);
    }

    /// Turns a page on the strip [pump] built, without pumping the frame that
    /// follows: the glide is what several of these tests are about.
    Future<void> pumpCurrent(WidgetTester tester, int current) =>
        tester.pumpWidget(rebuild(current));

    Size sizeOf(WidgetTester tester, int page) =>
        tester.getSize(find.byKey(ValueKey(page)));

    /// The shares the strip is drawn in, and the screens the tests above put
    /// it on. A thumbnail is a share of the screen's shortest side, so a size
    /// only means anything said against a screen.
    const phoneShort = 390.0; // 1170 / 3
    const tabletShort = 820.0; // 1640 / 2
    const baseShare = 0.174;
    const currentShare = 0.33;
    const nearShare = (baseShare + currentShare) / 2;
    const pageAspect = 48 / 34;
    const tabletShareFactor = 0.64;

    testWidgets('the current page is the widest, its neighbours next', (
      tester,
    ) async {
      await pump(tester, 20, width: 380);

      expect(
        sizeOf(tester, 20).width,
        moreOrLessEquals(phoneShort * currentShare, epsilon: 0.5),
        reason: 'a third of the screen',
      );
      expect(
        sizeOf(tester, 19).width,
        moreOrLessEquals(phoneShort * nearShare, epsilon: 0.5),
      );
      expect(
        sizeOf(tester, 21).width,
        moreOrLessEquals(phoneShort * nearShare, epsilon: 0.5),
      );
      expect(
        sizeOf(tester, 18).width,
        moreOrLessEquals(phoneShort * baseShare, epsilon: 0.5),
      );
      expect(
        sizeOf(tester, 22).width,
        moreOrLessEquals(phoneShort * baseShare, epsilon: 0.5),
      );
      // Only widths are shares of the screen: a thumbnail's height follows the
      // page's own proportion, so none of the three is ever out of shape.
      for (final page in [18, 19, 20]) {
        final size = sizeOf(tester, page);
        expect(size.height / size.width, closeTo(pageAspect, 0.001));
      }
    });

    testWidgets('the swollen thumbnail travels where the slider handle does', (
      tester,
    ) async {
      // The chrome shows a strip and a slider one above the other; a bulge
      // that stays centred while the handle moves reads as two different
      // "you are here" markers. 41 pages puts page 20 exactly halfway.
      const pages = 41;
      // Half the swollen thumbnail plus the strip's own padding: the inset the
      // handle also starts from.
      const inset = phoneShort * (0.031 + currentShare / 2);

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
      //
      const pages = 3;
      // On a tablet: spreading gives up where the two widest thumbnails would
      // touch, and three of these need 396pt of strip to clear that — six more
      // than a phone is wide. A short chapter on a phone scrolls instead, and
      // what keeps the bulge under the handle there is the law pinned above.
      await pump(tester, 1, pages: pages, tablet: true, width: 600);
      final inset = ThumbStrip.edgeInset(
        tester.element(find.byType(ThumbStrip)),
      );

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
      await pump(tester, 1, width: 380);
      await pump(tester, 2, width: 380);

      expect(
        sizeOf(tester, 2).width,
        moreOrLessEquals(phoneShort * currentShare, epsilon: 0.5),
      );
      expect(
        sizeOf(tester, 1).width,
        moreOrLessEquals(phoneShort * nearShare, epsilon: 0.5),
      );
      expect(
        sizeOf(tester, 3).width,
        moreOrLessEquals(phoneShort * nearShare, epsilon: 0.5),
      );
      expect(
        sizeOf(tester, 4).width,
        moreOrLessEquals(phoneShort * baseShare, epsilon: 0.5),
      );
    });

    testWidgets('a screen too short for the strip keeps the sizes it had', (
      tester,
    ) async {
      // A phone on its side is 390pt tall, and that is where a spread is read,
      // so the scrubber has to open there. No size the strip can be drawn at
      // keeps the chrome clear of the middle of a screen that short — which
      // was as true at the sizes it had before — so it comes back to those
      // rather than to the stamp the height budget alone would allow.
      await pump(tester, 20, landscape: true, width: 700);

      expect(
        sizeOf(tester, 20).width,
        moreOrLessEquals(92, epsilon: 1),
        reason: 'the swollen thumbnail the strip was drawn at before',
      );
      // The shortest side is the same in both orientations, so what shrank is
      // the strip and not the screen it is measured against.
      expect(
        sizeOf(tester, 20).width / (phoneShort * currentShare),
        closeTo(0.71, 0.01),
      );
      expect(
        sizeOf(tester, 19).width / sizeOf(tester, 18).width,
        closeTo(nearShare / baseShare, 0.001),
      );
    });

    testWidgets('a tablet takes a smaller share of a wider screen', (
      tester,
    ) async {
      // A tablet is not a big phone. A third of an iPad's shortest side would
      // be a 270pt thumbnail with no more pages beside it than a phone shows,
      // which is the mistake the rest of the app avoids by taking another
      // column rather than drawing a bigger card. So the shares come down and
      // the thumbnail still ends up one step larger than the phone's.
      await pump(tester, 20, tablet: true, width: 800);

      final current = sizeOf(tester, 20);
      final near = sizeOf(tester, 19);
      final base = sizeOf(tester, 18);
      expect(
        current.width,
        moreOrLessEquals(
          tabletShort * tabletShareFactor * currentShare,
          epsilon: 0.5,
        ),
      );
      expect(
        current.width / (phoneShort * currentShare),
        closeTo(1.35, 0.02),
        reason: 'one step up from the phone, not twice it',
      );
      // The same strip, so the same law and the same proportions.
      expect(current.height / current.width, closeTo(pageAspect, 0.001));
      expect(near.width / base.width, closeTo(nearShare / baseShare, 0.001));
      expect(current.height, greaterThan(near.height));
      expect(near.height, greaterThan(base.height));
      // Still centred on the tallest, so the accordion opens both ways.
      expect(
        tester.getCenter(find.byKey(const ValueKey(20))).dy,
        moreOrLessEquals(
          tester.getCenter(find.byKey(const ValueKey(18))).dy,
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('tapping a thumbnail pages away moves the strip', (
      tester,
    ) async {
      // A tap is what the reader turns into a new `current`, so the strip
      // hears about it from `didUpdateWidget` — which runs inside a build, and
      // under the reader inside a *layout*. That is why the strip has no
      // scroll position to command: moving one from there dirties layout in
      // the middle of a layout, and the reader's Scaffold answers with a body
      // it was never handed. Drawing the strip at a computed offset is an
      // ordinary rebuild, which any phase may ask for. Landscape because
      // sixteen thumbnails are on screen there, so a tap is almost always more
      // than one page away.
      var current = 20;
      final queue = ThumbLoadQueue(
        load: (_) async {},
        startDelay: Duration.zero,
      );
      addTearDown(queue.dispose);
      tester.view.physicalSize = const Size(2412, 1080); // a phone on its side
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Align(
                alignment: Alignment.bottomCenter,
                child: ThumbStrip(
                  pages: 200,
                  current: current,
                  queue: queue,
                  providerBuilder: (_) => null,
                  onTap: (page) => setState(() => current = page),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Whatever is on screen a few thumbnails along from the bulge.
      await tester.tap(find.byKey(const ValueKey(26)));
      await tester.pumpAndSettle();

      // One more turn of the loop, so the loader's zero-delay timer fires
      // before the test ends.
      await tester.pump(Duration.zero);

      expect(tester.takeException(), isNull);
      expect(current, 26);
    });

    testWidgets('a finger moves the strip, and the next page takes it back', (
      tester,
    ) async {
      // The strip draws itself at an offset it computes, so a drag is a value
      // this widget holds rather than a scroll position being commanded. While
      // a finger has put it somewhere, that is where it stays — and the moment
      // the reader turns a page it goes back to following the handle.
      const pages = 200;
      await pump(tester, 100, pages: pages, width: 380);
      final inset = ThumbStrip.edgeInset(
        tester.element(find.byType(ThumbStrip)),
      );
      final strip = tester.getRect(find.byType(ThumbStrip));
      double handleFor(int page) =>
          strip.left + inset + (strip.width - inset * 2) * page / (pages - 1);

      expect(
        tester.getCenter(find.byKey(const ValueKey(100))).dx,
        moreOrLessEquals(handleFor(100), epsilon: 0.5),
      );

      await tester.drag(find.byType(ThumbStrip), const Offset(-120, 0));
      await tester.pumpAndSettle();
      // The strip has moved, and the page being read has not.
      expect(
        tester.getCenter(find.byKey(const ValueKey(100))).dx,
        lessThan(handleFor(100) - 50),
      );

      await pumpCurrent(tester, 101);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(const ValueKey(101))).dx,
        moreOrLessEquals(handleFor(101), epsilon: 0.5),
        reason: 'following the handle again',
      );
      await tester.pump(Duration.zero);
    });

    testWidgets('the bulge stays under the handle while the accordion moves', (
      tester,
    ) async {
      // The sizes and the scroll offset are two views of one animation. They
      // used to be animated apart — the widths interpolating while a 200ms
      // scroll was aimed at the offset the *settled* widths called for — which
      // left the swollen thumbnail 123pt from the handle, a third of the
      // screen, for the length of every page turn. A drag on the slider
      // re-aims that scroll on every frame, so it never arrived at all.
      const pages = 200;
      await pump(tester, 100, pages: pages, width: 380);
      final strip = tester.getRect(find.byType(ThumbStrip));
      final inset = ThumbStrip.edgeInset(
        tester.element(find.byType(ThumbStrip)),
      );

      double handleFor(int page) =>
          strip.left + inset + (strip.width - inset * 2) * page / (pages - 1);

      // A page turn, sampled through the glide rather than only at its end —
      // including the frame that delivers it, which no longer has to lag: the
      // offset is drawn from the same state as the sizes, in the same build.
      await pumpCurrent(tester, 101);
      for (final frame in [
        Duration.zero,
        const Duration(milliseconds: 40),
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 160),
      ]) {
        await tester.pump(frame);
        expect(
          tester.getCenter(find.byKey(const ValueKey(101))).dx,
          moreOrLessEquals(handleFor(101), epsilon: 2),
          reason: 'mid-glide, ${frame.inMilliseconds}ms in',
        );
      }
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(const ValueKey(101))).dx,
        moreOrLessEquals(handleFor(101), epsilon: 0.5),
      );

      // A drag: a page every frame, which is what the old glide never caught.
      for (var page = 102; page <= 106; page++) {
        await pumpCurrent(tester, page);
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.getCenter(find.byKey(ValueKey(page))).dx,
          moreOrLessEquals(handleFor(page), epsilon: 2),
          reason: 'dragging through page $page',
        );
      }

      // And a jump the length of a chapter, which lands in the frame that
      // asks for it: there is no scroll to animate or re-aim.
      await pumpCurrent(tester, 0);
      await tester.pump();
      expect(
        tester.getCenter(find.byKey(const ValueKey(0))).dx,
        moreOrLessEquals(handleFor(0), epsilon: 0.5),
      );
      await tester.pump(Duration.zero);
    });
  });
}
