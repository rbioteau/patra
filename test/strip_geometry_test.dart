import 'dart:convert';

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
const _screenWidth = 400.0;
const _viewportHeight = 600.0;
const _pages = 200;

/// The device pixel ratio the strip is on: the width asked of the decoder is
/// asked in device pixels, so a test has to say how many there are to a point.
const _pixelRatio = 3.0;

/// The height of [page] at [_screenWidth]: mostly 400, with a short scan, a tall one
/// and an exceptionally tall one mixed in.
double _heightAt(int page) => switch (page) {
  7 => 200,
  100 => 800,
  150 => 1200,
  _ => 400,
};

/// Where [page] starts at [_screenWidth]: 400 a page, plus the running difference
/// the three odd pages make.
double _topAt(int page) => switch (page) {
  < 8 => 400.0 * page,
  <= 100 => 400.0 * page - 200,
  <= 150 => 400.0 * page + 200,
  _ => 400.0 * page + 1000,
};

/// The whole strip at [_screenWidth]: the last page's bottom, 200x400 plus the three
/// differences.
const _total = 81000.0;

StripGeometry _geometry(double screenWidth, {double widthFactor = 1.0}) =>
    StripGeometry(
      screenWidth: screenWidth,
      widthFactor: widthFactor,
      pages: _pages,
      aspectRatioFor: (page) => _screenWidth / _heightAt(page),
    );

/// A one-pixel picture. What a page is decoded at is a question about width,
/// and a widget test has no business arguing with a decoder.
final _onePixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
);
final _pageImage = MemoryImage(_onePixel);

/// The strip under test: the module's sliver in a viewport, every page a plain
/// box carrying its own key so the render tree can be asked where it is.
///
/// [images] draws each page as a picture instead, asked of the decoder at the
/// width the geometry says, so the tree can be asked what width that is.
Widget _strip(
  ScrollController controller,
  double screenWidth, {
  double widthFactor = 1.0,
  bool images = false,
}) {
  final geometry = _geometry(screenWidth, widthFactor: widthFactor);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      // The reader's canvas, as its own Scaffold paints it: the strip is
      // drawn over it, and what the strip does not take is it. The colour is
      // the screen's business and not this module's, so nothing below
      // asserts it — what is asserted is that the strip leaves the margins
      // alone, which is what lets the canvas show through.
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: screenWidth,
          height: _viewportHeight,
          child: CustomScrollView(
            controller: controller,
            slivers: <Widget>[
              StripExtentList(
                geometry: geometry,
                itemBuilder: (_, int page) => images
                    ? Image(
                        key: ValueKey(page),
                        image: ResizeImage(
                          _pageImage,
                          width: geometry.decodeWidth(_pixelRatio),
                        ),
                        fit: BoxFit.fitWidth,
                      )
                    : SizedBox.expand(
                        key: ValueKey(page),
                        child: const ColoredBox(color: Color(0xFF203040)),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<ScrollController> _pump(
  WidgetTester tester, {
  double width = _screenWidth,
  double widthFactor = 1.0,
  bool images = false,
}) {
  // The test surface *is* the screen: the strip is given the whole of it, so a
  // page's left edge can be read straight off the render tree.
  tester.view.physicalSize = Size(
    width * _pixelRatio,
    _viewportHeight * _pixelRatio,
  );
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return tester
      .pumpWidget(_strip(controller, width, widthFactor: widthFactor, images: images))
      .then((_) => tester.pump())
      .then((_) => controller);
}

/// Moves the strip to [page] the way the reader does: to the top of the
/// page, or partway down it, clamped to what the strip can actually scroll
/// to.
Future<void> _seek(
  WidgetTester tester,
  ScrollController controller,
  StripGeometry geometry,
  int page, {
  double fraction = 0,
}) async {
  controller.jumpTo(
    geometry
        .offsetFor(StripAnchor(page, fraction))
        .clamp(0, controller.position.maxScrollExtent),
  );
  await tester.pump();
}

/// Where the top of [page] is painted, in the coordinates of the viewport:
/// 0 is the top of the screen, [_viewportHeight] its bottom.
double _topOf(WidgetTester tester, int page) =>
    tester.getTopLeft(find.byKey(ValueKey(page))).dy;

/// The box [page] is painted in, in the same coordinates: how wide the strip
/// really is, which is the only witness worth asking about a decode width.
Rect _rectOf(WidgetTester tester, int page) =>
    tester.getRect(find.byKey(ValueKey(page)));

void main() {
  group('a strip laid out at a width', () {
    testWidgets('every page is as tall as its dimensions say', (tester) async {
      final controller = await _pump(tester);

      for (final page in [0, 1]) {
        expect(
          tester.getSize(find.byKey(ValueKey(page))),
          const Size(_screenWidth, 400),
          reason: 'page $page',
        );
      }

      // The three pages whose dimensions differ: reached by seeking, since a
      // lazy sliver only builds what is near the viewport.
      for (final page in [7, 100, 150]) {
        await _seek(tester, controller, _geometry(_screenWidth), page);
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
      await _seek(tester, controller, _geometry(_screenWidth), 7);
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
      final geometry = _geometry(_screenWidth);

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
      await _seek(tester, controller, _geometry(_screenWidth), 199);

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
      final geometry = _geometry(_screenWidth);

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
      final controller = await _pump(tester, width: _screenWidth);
      await _seek(tester, controller, _geometry(_screenWidth), 100);
      expect(_topOf(tester, 100), moreOrLessEquals(0, epsilon: 0.5));

      // Half the width: every height halves with it.
      await tester.pumpWidget(_strip(controller, _screenWidth / 2));
      await tester.pump();
      expect(controller.offset, moreOrLessEquals(_topAt(100), epsilon: 0.5));

      await _seek(tester, controller, _geometry(_screenWidth / 2), 100);
      expect(_topOf(tester, 100), moreOrLessEquals(0, epsilon: 0.5));

      // And the total halved with the pages.
      expect(
        controller.position.maxScrollExtent,
        moreOrLessEquals(_total / 2 - _viewportHeight, epsilon: 0.5),
      );
    });
  });

  group('a strip laid out at a width factor', () {
    // `1.0` is the whole screen, which is exactly how a chapter opens today,
    // and `0.5` is as narrow as the strip goes. Both ends and a factor in
    // between: the arithmetic is linear, and a linear mistake is invisible
    // at `1.0`.
    const factors = [0.5, 0.7, 1.0];

    for (final factor in factors) {
      testWidgets('at $factor every page is as wide and as tall as the factor says', (
        tester,
      ) async {
        final controller = await _pump(tester, widthFactor: factor);
        final geometry = _geometry(_screenWidth, widthFactor: factor);

        for (final page in [0, 1]) {
          final size = tester.getSize(find.byKey(ValueKey(page)));
          expect(
            size.width,
            moreOrLessEquals(geometry.width, epsilon: 0.5),
            reason: 'page $page',
          );
          expect(
            size.height,
            moreOrLessEquals(_heightAt(page) * factor, epsilon: 0.5),
            reason: 'page $page',
          );
        }

        // The three pages whose dimensions differ: reached by seeking, since
        // a lazy sliver only builds what is near the viewport.
        for (final page in [7, 100, 150]) {
          await _seek(tester, controller, geometry, page);
          expect(
            tester.getSize(find.byKey(ValueKey(page))).height,
            moreOrLessEquals(_heightAt(page) * factor, epsilon: 0.5),
            reason: 'page $page',
          );
        }
      });

      testWidgets('at $factor the tops and the whole strip are exact', (
        tester,
      ) async {
        final controller = await _pump(tester, widthFactor: factor);
        final geometry = _geometry(_screenWidth, widthFactor: factor);

        // Partway down the tallest page in the chapter, so both sides of
        // the seam below it are on the screen at once.
        await _seek(tester, controller, geometry, 100, fraction: 0.75);
        expect(
          _topOf(tester, 101) - _topOf(tester, 100),
          moreOrLessEquals(_heightAt(100) * factor, epsilon: 0.5),
          reason: 'no gap and no overlap across the seam',
        );

        expect(
          controller.position.maxScrollExtent,
          moreOrLessEquals(_total * factor - _viewportHeight, epsilon: 0.5),
          reason: 'the whole strip, less the screen it is seen through',
        );

        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        // The end of the chapter, reachable: an extent that is estimated
        // rather than known leaves the last page thousands of points away.
        expect(
          tester.getBottomRight(find.byKey(const ValueKey(199))).dy,
          moreOrLessEquals(_viewportHeight, epsilon: 0.5),
        );
      });

      testWidgets('at $factor a seek lands on the page it asked for', (tester) async {
        final controller = await _pump(tester, widthFactor: factor);
        final geometry = _geometry(_screenWidth, widthFactor: factor);

        // The start, the middle and the end of a long chapter.
        for (final page in [0, 100, 190]) {
          await _seek(tester, controller, geometry, page);
          expect(
            _topOf(tester, page),
            moreOrLessEquals(0, epsilon: 0.5),
            reason: 'page $page',
          );
        }
      });

      testWidgets('at $factor the strip sits centred on the canvas', (tester) async {
        await _pump(tester, widthFactor: factor);
        final geometry = _geometry(_screenWidth, widthFactor: factor);
        final rect = _rectOf(tester, 0);

        // Narrower than the screen, the strip leaves the canvas showing
        // either side of it — the reader's own black, with nothing of the
        // strip painted over it — and the same width of it on both sides.
        expect(rect.left, moreOrLessEquals(geometry.inset, epsilon: 0.5));
        expect(
          rect.right,
          moreOrLessEquals(_screenWidth - geometry.inset, epsilon: 0.5),
        );
        // Centred on what was measured, not on the arithmetic: the same
        // width of canvas either side of the strip.
        expect(
          rect.left,
          moreOrLessEquals((_screenWidth - rect.width) / 2, epsilon: 0.5),
        );
      });

      testWidgets('at $factor a page is decoded at the width it is drawn at', (
        tester,
      ) async {
        final controller = await _pump(
          tester,
          widthFactor: factor,
          images: true,
        );
        final geometry = _geometry(_screenWidth, widthFactor: factor);
        await _seek(tester, controller, geometry, 100);

        // The width the decoder was asked for, read off the tree, against
        // the width the page was actually painted at, read off the same
        // tree: never against the arithmetic that asked for it.
        final drawn = _rectOf(tester, 100).width;
        final provider =
            tester.widget<Image>(find.byKey(const ValueKey(100))).image
                as ResizeImage;
        expect(drawn, moreOrLessEquals(geometry.width, epsilon: 0.5));
        expect(provider.width, closeTo(drawn * _pixelRatio, 1));
      });
    }

    test('the factor stays inside its range', () {
      // Half the screen is as narrow as the strip goes and the whole screen
      // as wide. The module holds the range rather than the two places that
      // will set it — a preference and a pinch — so they cannot clamp it
      // differently.
      expect(_geometry(_screenWidth, widthFactor: 0.1).widthFactor, 0.5);
      expect(_geometry(_screenWidth, widthFactor: 3).widthFactor, 1.0);

      // And it is the clamped factor the strip is laid out at.
      final geometry = _geometry(_screenWidth, widthFactor: 3);
      expect(geometry.width, _screenWidth);
      expect(geometry.inset, 0);
    });

    testWidgets('what is warmed ahead and what is drawn are one image', (
      tester,
    ) async {
      // One side off the tree: the width the strip's own pages were asked
      // the decoder for.
      await _pump(tester, widthFactor: 0.7, images: true);
      final drawn =
          tester.widget<Image>(find.byKey(const ValueKey(0))).image
              as ResizeImage;

      // The other side from the width the strip reports, which is what the
      // reader warms the page after this one at.
      final warmed = ResizeImage(
        _pageImage,
        width: _geometry(
          _screenWidth,
          widthFactor: 0.7,
        ).decodeWidth(_pixelRatio),
      );
      expect(warmed, drawn);

      // `ResizeImage` puts the width in its cache key, so a page warmed at
      // one width and drawn at another is two images: one decoded for
      // nothing, and one the strip has to fetch again. Narrowing the strip
      // puts more pages in the same cache extent, so the one that is not
      // shown is also the larger of the two.
      final narrower = ResizeImage(
        _pageImage,
        width: _geometry(
          _screenWidth,
          widthFactor: 0.5,
        ).decodeWidth(_pixelRatio),
      );
      expect(narrower, isNot(drawn));
    });
  });
}
