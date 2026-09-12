import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/strip_geometry.dart';

/// A strip of 200 pages in a 400x600 viewport.
///
/// The heights are literals — every page is 400 tall at width 400 but for
/// three of them — so the tops and the total asserted below are sums anybody
/// can do by hand, and not the module's own arithmetic coming back at itself.
/// That is the only kind of expectation that can catch the strip being laid
/// out somewhere other than where its own geometry says it is.
const _width = 400.0;
const _viewportHeight = 600.0;
const _pages = 200;

/// The height of [page] at [_width]: mostly 400, with a short scan, a tall one
/// and an exceptionally tall one mixed in.
double _heightAt(int page) => switch (page) {
  7 => 200,
  100 => 800,
  150 => 1200,
  _ => 400,
};

/// Where [page] starts at [_width]: 400 a page, plus the running difference
/// the three odd pages make.
double _topAt(int page) => switch (page) {
  < 8 => 400.0 * page,
  <= 100 => 400.0 * page - 200,
  <= 150 => 400.0 * page + 200,
  _ => 400.0 * page + 1000,
};

/// The whole strip at [_width]: the last page's bottom, 200x400 plus the three
/// differences.
const _total = 81000.0;

StripGeometry _geometry(double width) => StripGeometry(
  width: width,
  pages: _pages,
  aspectRatioFor: (page) => _width / _heightAt(page),
);

/// The strip under test: the module's sliver in a viewport, every page a plain
/// box carrying its own key so the render tree can be asked where it is.
Widget _strip(ScrollController controller, double width) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: width,
        height: _viewportHeight,
        child: CustomScrollView(
          controller: controller,
          slivers: <Widget>[
            StripExtentList(
              geometry: _geometry(width),
              itemBuilder: (_, int page) => SizedBox.expand(
                key: ValueKey(page),
                child: const ColoredBox(color: Color(0xFF203040)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<ScrollController> _pump(WidgetTester tester, {double width = _width}) {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return tester
      .pumpWidget(_strip(controller, width))
      .then((_) => tester.pump())
      .then((_) => controller);
}

/// Moves the strip to [page] the way the reader does: to the top of the page,
/// clamped to what the strip can actually scroll to.
Future<void> _seek(
  WidgetTester tester,
  ScrollController controller,
  StripGeometry geometry,
  int page,
) async {
  controller.jumpTo(
    geometry
        .offsetFor(StripAnchor(page, 0))
        .clamp(0, controller.position.maxScrollExtent),
  );
  await tester.pump();
}

/// Where the top of [page] is painted, in the coordinates of the viewport:
/// 0 is the top of the screen, [_viewportHeight] its bottom.
double _topOf(WidgetTester tester, int page) =>
    tester.getTopLeft(find.byKey(ValueKey(page))).dy;

void main() {
  group('a strip laid out at a width', () {
    testWidgets('every page is as tall as its dimensions say', (tester) async {
      final controller = await _pump(tester);

      for (final page in [0, 1]) {
        expect(
          tester.getSize(find.byKey(ValueKey(page))),
          const Size(_width, 400),
          reason: 'page $page',
        );
      }

      // The three pages whose dimensions differ: reached by seeking, since a
      // lazy sliver only builds what is near the viewport.
      for (final page in [7, 100, 150]) {
        await _seek(tester, controller, _geometry(_width), page);
        expect(
          tester.getSize(find.byKey(ValueKey(page))).height,
          moreOrLessEquals(_heightAt(page), epsilon: 0.5),
          reason: 'page $page',
        );
      }
    });

    testWidgets('the pages are laid end to end, in the order they read', (
      tester,
    ) async {
      final controller = await _pump(tester);

      expect(_topOf(tester, 0), moreOrLessEquals(0, epsilon: 0.5));
      // No gap and no overlap: a strip is continuous.
      expect(
        _topOf(tester, 1) - _topOf(tester, 0),
        moreOrLessEquals(_heightAt(0), epsilon: 0.5),
      );

      // And across a seam where the two neighbours differ in height, which
      // is where a strip that has guessed at an extent shows it.
      await _seek(tester, controller, _geometry(_width), 7);
      expect(
        _topOf(tester, 8) - _topOf(tester, 7),
        moreOrLessEquals(_heightAt(7), epsilon: 0.5),
        reason: 'the short page, followed by an ordinary one',
      );
    });

    testWidgets('the total is exact, so the last page is reachable', (
      tester,
    ) async {
      final controller = await _pump(tester);

      expect(
        controller.position.maxScrollExtent,
        moreOrLessEquals(_total - _viewportHeight, epsilon: 0.5),
        reason: 'the whole strip, less the screen it is seen through',
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      // The end of the chapter: the last page's bottom sits at the bottom of
      // the screen. An extent that is estimated rather than known leaves it
      // thousands of points above, or below, and unreachable.
      expect(
        tester.getBottomRight(find.byKey(const ValueKey(199))).dy,
        moreOrLessEquals(_viewportHeight, epsilon: 0.5),
      );
    });
  });

  group('seeking', () {
    testWidgets('lands at the top of the page asked for', (tester) async {
      final controller = await _pump(tester);
      final geometry = _geometry(_width);

      // The start, the middle and the end of a long chapter.
      for (final page in [0, 100, 190]) {
        await _seek(tester, controller, geometry, page);
        expect(
          _topOf(tester, page),
          moreOrLessEquals(0, epsilon: 0.5),
          reason: 'page $page',
        );
        expect(
          geometry.offsetFor(StripAnchor(page, 0)),
          moreOrLessEquals(_topAt(page), epsilon: 0.5),
          reason: 'the offset page $page is asked for',
        );
      }
    });

    testWidgets('to the last page goes as far as the strip scrolls', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _seek(tester, controller, _geometry(_width), 199);

      // There is nothing after the last page to put under the top of the
      // screen: it clamps, and the chapter ends where it ends.
      expect(
        controller.offset,
        moreOrLessEquals(_total - _viewportHeight, epsilon: 0.5),
      );
      expect(
        tester.getBottomRight(find.byKey(const ValueKey(199))).dy,
        moreOrLessEquals(_viewportHeight, epsilon: 0.5),
      );
    });
  });

  group('the anchor', () {
    testWidgets('survives a round trip through the geometry', (tester) async {
      final controller = await _pump(tester);
      final geometry = _geometry(_width);

      // Somewhere in the middle of a page, not at its top: a page and a
      // fraction within it is what has to come back.
      controller.jumpTo(_topAt(62) + 137);
      await tester.pump();
      final anchor = geometry.anchorAt(controller.offset);
      final before = _topOf(tester, anchor.page);

      // Somewhere else entirely, so the round trip is a real one.
      controller.jumpTo(_topAt(120));
      await tester.pump();
      expect(_topOf(tester, 120), moreOrLessEquals(0, epsilon: 0.5));

      controller.jumpTo(geometry.offsetFor(anchor));
      await tester.pump();

      // The page it named, painted where it was painted before.
      expect(_topOf(tester, anchor.page), moreOrLessEquals(before, epsilon: 0.5));
      // And the point in it that was named is at the top of the screen.
      final rect = tester.getRect(find.byKey(ValueKey(anchor.page)));
      expect(
        rect.top + anchor.fraction * rect.height,
        moreOrLessEquals(0, epsilon: 0.5),
      );
    });
  });

  group('a strip laid out again at another width', () {
    // A rotation does this today, and the width factor will do it on every
    // pinch. A builder list remembers where its first child was *in the old
    // scale*, so changing every height at once shifts the whole strip by the
    // offset times one minus the ratio of the two — measured at ~58 pages
    // when halving the width at page 100, after which nothing the geometry
    // says is where the strip is drawn.
    testWidgets('keeps every page where its dimensions put it', (tester) async {
      final controller = await _pump(tester, width: _width);
      await _seek(tester, controller, _geometry(_width), 100);
      expect(_topOf(tester, 100), moreOrLessEquals(0, epsilon: 0.5));

      // Half the width: every height halves with it.
      await tester.pumpWidget(_strip(controller, _width / 2));
      await tester.pump();
      expect(controller.offset, moreOrLessEquals(_topAt(100), epsilon: 0.5));

      await _seek(tester, controller, _geometry(_width / 2), 100);
      expect(_topOf(tester, 100), moreOrLessEquals(0, epsilon: 0.5));

      // And the total halved with the pages.
      expect(
        controller.position.maxScrollExtent,
        moreOrLessEquals(_total / 2 - _viewportHeight, epsilon: 0.5),
      );
    });
  });
}
