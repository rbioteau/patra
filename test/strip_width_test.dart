import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/strip_geometry.dart';
import 'package:patra/src/features/reader/strip_width.dart';

/// A strip of 200 pages in a 400x600 viewport.
///
/// The heights are literals — every page is 400 tall at width 400 but for
/// three of them — so where a page is painted can be worked out by hand and
/// not read back off the arithmetic that asked for it.
const _screenWidth = 400.0;
const _viewportHeight = 600.0;
const _pages = 200;

/// The device pixel ratio the strip is on: a page is decoded at the width it
/// is drawn at, in device pixels, so a test has to say how many there are to
/// a point.
const _pixelRatio = 3.0;

double _heightAt(int page) => switch (page) {
  7 => 200,
  100 => 800,
  150 => 1200,
  _ => 400,
};

double _aspectRatioFor(int page) => _screenWidth / _heightAt(page);

/// What the strip is made of, as far as the controller is concerned: one
/// chapter, compared by identity.
final _chapter = Object();

/// The strip's surface, which is the screen's: the box every painted page is
/// measured against.
final _surface = GlobalKey();

/// A one-pixel picture. What a page is decoded at is a question about width,
/// and a widget test has no business arguing with a decoder.
final _onePixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
);
final _pageImage = MemoryImage(_onePixel);

/// The strip the way the reader builds it: a `LayoutBuilder` measuring the
/// canvas, the gesture owner above a scroll view, and the module's own sliver.
class _Strip extends StatefulWidget {
  const _Strip({
    required this.scroll,
    required this.width,
    this.images = false,
  });

  final ScrollController scroll;
  final StripWidthController width;
  final bool images;

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  @override
  void initState() {
    super.initState();
    widget.width.addListener(_relayout);
  }

  /// The width changed under the strip: it is laid out again. What the
  /// controller did to the offset in the same turn is not this widget's
  /// business, and a scroll position is not told twice.
  void _relayout() => setState(() {});

  @override
  void dispose() {
    widget.width.removeListener(_relayout);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolved here and not in the item builder, for the reader's reason: a
    // lazy sliver builds its children during layout.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.width.measure(
          screenWidth: constraints.maxWidth,
          pages: _pages,
          aspectRatioFor: _aspectRatioFor,
          identity: _chapter,
        );
        return StripWidthGestures(
          controller: widget.width,
          child: CustomScrollView(
            controller: widget.scroll,
            slivers: <Widget>[
              StripExtentList(
                geometry: widget.width.geometry,
                itemBuilder: (_, int page) => widget.images
                    ? Image(
                        key: ValueKey(page),
                        image: ResizeImage(
                          _pageImage,
                          width: widget.width.decodeWidth(pixelRatio),
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
        );
      },
    );
  }
}

class _Harness {
  const _Harness(this.scroll, this.width);

  final ScrollController scroll;
  final StripWidthController width;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  double widthFactor = 1.0,
  bool images = false,
}) async {
  // The test surface *is* the screen: the strip is given the whole of it, so
  // a finger's position on the screen is its position in the strip.
  tester.view.physicalSize = Size(
    _screenWidth * _pixelRatio,
    _viewportHeight * _pixelRatio,
  );
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  final width = StripWidthController(
    scroll: scroll,
    widthFactor: widthFactor,
  );
  addTearDown(width.dispose);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            key: _surface,
            width: _screenWidth,
            height: _viewportHeight,
            child: _Strip(scroll: scroll, width: width, images: images),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(scroll, width);
}

/// Moves the strip to [page] the way the reader does: to the top of the page,
/// or partway down it, clamped to what the strip can actually scroll to.
Future<void> _seek(
  WidgetTester tester,
  _Harness harness,
  int page, {
  double fraction = 0,
}) async {
  harness.scroll.jumpTo(
    harness.width.geometry
        .offsetFor(StripAnchor(page, fraction))
        .clamp(0, harness.scroll.position.maxScrollExtent),
  );
  await tester.pump();
}

/// One page as it was actually laid out: which page it is, where its top is
/// on the screen, and how tall it was drawn.
class _Painted {
  const _Painted(this.page, this.top, this.height);

  final int page;
  final double top;
  final double height;

  double get bottom => top + height;
}

/// What the strip is showing, read out of the render tree: the pages it has
/// built, with where they were drawn.
///
/// Measured off the tree and not off the geometry the strip was built from,
/// because the geometry is the arithmetic that asked for this and can only
/// ever agree with itself — which is why a strip can claim to be showing one
/// page while it is drawing another.
List<_Painted> _painted(WidgetTester tester) {
  final surface = tester.renderObject<RenderBox>(find.byKey(_surface));
  RenderSliverMultiBoxAdaptor? sliver;
  void walk(RenderObject object) {
    if (sliver != null) return;
    if (object is RenderSliverMultiBoxAdaptor) {
      sliver = object;
      return;
    }
    object.visitChildren(walk);
  }

  walk(surface);
  final painted = <_Painted>[];
  sliver?.visitChildren((RenderObject child) {
    final box = child as RenderBox;
    final data = box.parentData;
    if (data is! SliverMultiBoxAdaptorParentData || data.index == null) return;
    final top = box.getTransformTo(surface).getTranslation().y;
    painted.add(_Painted(data.index!, top, box.size.height));
  });
  return painted;
}

/// The point of the strip painted at [y]: which page it is on, and how far
/// down that page.
({int page, double fraction}) _under(WidgetTester tester, double y) {
  for (final page in _painted(tester)) {
    if (y >= page.top && y < page.bottom) {
      return (page: page.page, fraction: (y - page.top) / page.height);
    }
  }
  return (page: -1, fraction: -1);
}

/// The box [page] is painted in, in the screen's coordinates: how wide the
/// strip really is, which is the only witness worth asking about a width.
Rect _rectOf(WidgetTester tester, int page) =>
    tester.getRect(find.byKey(ValueKey(page)));

/// Two fingers, moved apart or together about (`centreX`, `y`), one step per
/// frame.
Future<void> _pinch(
  WidgetTester tester, {
  required TestGesture a,
  required TestGesture b,
  required double centreX,
  required double y,
  required double from,
  required double to,
  int steps = 16,
}) async {
  for (var step = 1; step <= steps; step++) {
    final span = from + (to - from) * step / steps;
    await a.moveTo(Offset(centreX - span / 2, y));
    await b.moveTo(Offset(centreX + span / 2, y));
    await tester.pump();
  }
}

/// One finger dragged [by] points up the screen, over [steps] frames 16ms
/// apart: a drag with a real velocity behind it, which is what makes a fling.
///
/// [finger] keeps a drag going that a test started itself — the second finger
/// of a pinch lands on one that is already moving.
Future<TestGesture> _swipe(
  WidgetTester tester,
  Offset at,
  double by, {
  int steps = 8,
  bool lift = true,
  TestGesture? finger,
}) async {
  final moving = finger ?? await tester.startGesture(at);
  for (var step = 1; step <= steps; step++) {
    await moving.moveTo(
      at + Offset(0, by * step / steps),
      timeStamp: Duration(milliseconds: 16 * step),
    );
    await tester.pump();
  }
  if (lift) await moving.up();
  return moving;
}

void main() {
  group('a pinch from rest', () {
    testWidgets(
      'narrows the strip, and what was under the fingers stays under them',
      (tester) async {
        final harness = await _pump(tester);
        await _seek(tester, harness, 100);

        // Halfway down the tallest page in the chapter, so there is a seam
        // either side of the fingers to be wrong about.
        const y = 270.0;
        final before = _under(tester, y);
        expect(before.page, 100, reason: 'the fingers are on page 100');

        final a = await tester.startGesture(const Offset(140, y));
        final b = await tester.startGesture(const Offset(260, y));
        await tester.pump();
        await _pinch(
          tester,
          a: a,
          b: b,
          centreX: 200,
          y: y,
          from: 120,
          to: 60,
          steps: 20,
        );

        // Two fingers half as far apart: half the width.
        expect(harness.width.widthFactor, moreOrLessEquals(0.5, epsilon: 0.01));
        expect(
          _rectOf(tester, before.page).width,
          moreOrLessEquals(_screenWidth / 2, epsilon: 0.5),
          reason: 'the strip is drawn at the width it was asked for',
        );

        // And the same page, at the same point in it, under the fingers: not
        // the page the arithmetic says should be there.
        final after = _under(tester, y);
        expect(after.page, before.page);
        expect(after.fraction, moreOrLessEquals(before.fraction, epsilon: 0.01));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('stops at the ends of the range', (tester) async {
      final harness = await _pump(tester);
      await _seek(tester, harness, 100);

      const y = 270.0;
      final a = await tester.startGesture(const Offset(140, y));
      final b = await tester.startGesture(const Offset(260, y));
      await tester.pump();

      // As narrow as the strip goes, and then further: a pinch that asks for
      // more than the range is not given it.
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 120, to: 60);
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 60, to: 20);
      expect(harness.width.widthFactor, StripGeometry.minWidthFactor);

      // And as wide, which is the screen: wider than the screen is a pan this
      // stage does not have, so the range stops here.
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 60, to: 240);
      expect(harness.width.widthFactor, StripGeometry.maxWidthFactor);

      // Narrow again, from where the fingers are and not from where they were
      // clamped: the width follows the span, so it comes back to the width the
      // same span asked for before it was clamped.
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 240, to: 60);
      expect(harness.width.widthFactor, moreOrLessEquals(0.5, epsilon: 0.01));
    });
  });

  group('a pinch that starts on a moving strip', () {
    testWidgets('engages, and the scroll it interrupts is dropped', (tester) async {
      final harness = await _pump(tester);
      await _seek(tester, harness, 100);

      const y = 400.0;
      final a = await tester.startGesture(const Offset(200, y));
      await _swipe(tester, const Offset(200, y), -96, lift: false, finger: a);
      final scrolled = harness.scroll.offset;
      expect(scrolled, greaterThan(50), reason: 'one finger is scrolling');

      // The second finger lands while the first is still down and moving.
      final b = await tester.startGesture(const Offset(320, y - 96));
      await tester.pump();
      await _pinch(
        tester,
        a: a,
        b: b,
        centreX: 260,
        y: y - 96,
        from: 120,
        to: 70,
      );
      expect(
        harness.width.widthFactor,
        lessThan(0.8),
        reason: 'the pinch took effect',
      );

      // And the scroll it interrupted was dropped, not thrown: five idle
      // frames with two fingers down move nothing.
      final held = harness.scroll.offset;
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        harness.scroll.offset,
        moreOrLessEquals(held, epsilon: 0.5),
        reason: 'a pinch inherits no velocity',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('a pinch and a fling', () {
    testWidgets('the fling is stopped, during it and just after it', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _seek(tester, harness, 100);

      const y = 500.0;
      // A fling: eight frames of 34 points each, and the finger gone with a
      // velocity behind it.
      await _swipe(tester, const Offset(200, y), -272);
      final flung = harness.scroll.offset;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        harness.scroll.offset,
        greaterThan(flung + 10),
        reason: 'the strip is still moving on its own',
      );

      // Two fingers land in the middle of it: the fling is stopped by their
      // landing and not by the first pinch update a few frames later, which
      // is what would leave the place they are holding drifting away from
      // them before the width has even moved.
      final a = await tester.startGesture(const Offset(140, 270));
      final b = await tester.startGesture(const Offset(260, 270));
      final landed = harness.scroll.offset;
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        harness.scroll.offset,
        moreOrLessEquals(landed, epsilon: 0.5),
        reason: 'the fling is stopped by the fingers landing',
      );

      await _pinch(tester, a: a, b: b, centreX: 200, y: 270, from: 120, to: 70);
      expect(
        harness.width.widthFactor,
        lessThan(0.8),
        reason: 'the pinch took effect during the fling',
      );

      final held = harness.scroll.offset;
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        harness.scroll.offset,
        moreOrLessEquals(held, epsilon: 0.5),
        reason: 'and the pinch itself inherits no velocity',
      );
      await a.up();
      await b.up();
      await tester.pump();

      // And again, with a fling that has already died: the pinch engages all
      // the same, which the stock composition manages only when a previous
      // gesture happened to leave it engaged.
      await _swipe(tester, const Offset(200, y), -272);
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final c = await tester.startGesture(const Offset(140, 270));
      final d = await tester.startGesture(const Offset(260, 270));
      await tester.pump();
      await _pinch(tester, a: c, b: d, centreX: 200, y: 270, from: 120, to: 70);
      expect(
        harness.width.widthFactor,
        lessThan(0.8),
        reason: 'the pinch took effect after the fling',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('lifting one of two fingers', () {
    for (final lifted in ['the first', 'the second']) {
      testWidgets('leaves one finger scrolling, and the width alone', (
        tester,
      ) async {
        final harness = await _pump(tester);
        await _seek(tester, harness, 100);

        const y = 270.0;
        final a = await tester.startGesture(const Offset(140, y));
        final b = await tester.startGesture(const Offset(260, y));
        await tester.pump();
        await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 120, to: 70);
        final pinched = harness.width.widthFactor;

        final gone = lifted == 'the first' ? a : b;
        final kept = lifted == 'the first' ? b : a;
        await gone.up();
        await tester.pump();

        // The width is untouched by a finger leaving.
        expect(harness.width.widthFactor, moreOrLessEquals(pinched, epsilon: 0.001));

        // And the one that is left scrolls, from where it is.
        final before = harness.scroll.offset;
        var at = Offset(kept == a ? 140 : 260, y);
        for (var frame = 1; frame <= 8; frame++) {
          at = at + const Offset(0, -14);
          await kept.moveTo(at, timeStamp: Duration(milliseconds: 16 * frame));
          await tester.pump();
        }
        expect(
          (harness.scroll.offset - before).abs(),
          greaterThan(20),
          reason: 'one finger scrolls again',
        );
        await kept.up();
        await tester.pump();

        // Nothing is left stuck: a whole new one-finger scroll works, and it
        // does not change the width.
        final settled = harness.width.widthFactor;
        final after = harness.scroll.offset;
        await _swipe(tester, const Offset(200, 400), -96);
        expect((harness.scroll.offset - after).abs(), greaterThan(20));
        expect(harness.width.widthFactor, moreOrLessEquals(settled, epsilon: 0.001));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('a focal point on a seam', () {
    testWidgets('behaves as it does anywhere else', (tester) async {
      final harness = await _pump(tester);
      // Page 50, whose neighbours are all the same height, so the seam below
      // it is comfortably inside the screen.
      await _seek(tester, harness, 50);

      // A seam that is comfortably inside the screen: the top of the page
      // after the one the top of the viewport is on.
      final seam = _painted(tester)
          .where((page) => page.top > 60 && page.top < _viewportHeight - 60)
          .reduce((a, b) => a.page < b.page ? a : b);
      final y = seam.top;
      expect(_under(tester, y).page, seam.page);

      final a = await tester.startGesture(Offset(140, y));
      final b = await tester.startGesture(Offset(260, y));
      await tester.pump();
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 120, to: 60);

      // The seam is under the fingers still, to the point.
      final painted = _painted(tester)
          .where((page) => page.page == seam.page)
          .singleOrNull;
      expect(painted, isNotNull, reason: 'the page below the seam is drawn');
      expect(painted!.top, moreOrLessEquals(y, epsilon: 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('one finger', () {
    testWidgets('keeps scrolling the chapter at every width', (tester) async {
      // At half the width, which is where the strip is narrowest and the
      // pages are shortest: the drag is still the scroll, and physics and
      // flings are still the framework's.
      final harness = await _pump(tester, widthFactor: 0.5);
      await _seek(tester, harness, 100);
      expect(
        _rectOf(tester, 100).width,
        moreOrLessEquals(_screenWidth / 2, epsilon: 0.5),
      );

      final before = harness.scroll.offset;
      await _swipe(tester, const Offset(200, 400), -160);
      expect(
        harness.scroll.offset,
        greaterThan(before + 100),
        reason: 'one finger still scrolls the strip',
      );

      // A fling: the strip keeps moving after the finger is gone, and then
      // stops, which is a simulation neither this module nor the reader owns.
      final finger = await tester.startGesture(const Offset(200, 400));
      for (var step = 1; step <= 8; step++) {
        await finger.moveTo(
          const Offset(200, 400) + Offset(0, -34.0 * step),
          timeStamp: Duration(milliseconds: 16 * step),
        );
        await tester.pump();
      }
      final released = harness.scroll.offset;
      await finger.up();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        harness.scroll.offset,
        greaterThan(released + 10),
        reason: 'the fling carried on without the finger',
      );
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        harness.scroll.offset,
        lessThanOrEqualTo(harness.scroll.position.maxScrollExtent + 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('a third finger', () {
    testWidgets('changes nothing, and does not move the width when it goes', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _seek(tester, harness, 100);

      // Two fingers pinching, and a third that lands nowhere near them — a
      // palm, or the hand holding the phone. It is read and ignored.
      const y = 270.0;
      final a = await tester.startGesture(const Offset(140, y));
      final b = await tester.startGesture(const Offset(260, y));
      final c = await tester.startGesture(const Offset(200, y + 300));
      await tester.pump();
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 120, to: 70);
      final pinched = harness.width.widthFactor;

      // One of the two that set the width goes. The pair the width is measured
      // between is not the pair it was, and the strip must not jump to what
      // the span between the survivors asks for — which here is two and a half
      // times the width, and would be clamped back to the whole screen.
      await a.up();
      await tester.pump();
      await b.moveTo(const Offset(200, y));
      await c.moveTo(const Offset(200, y + 298));
      await tester.pump();
      expect(
        harness.width.widthFactor,
        moreOrLessEquals(pinched, epsilon: 0.02),
        reason: 'the pinch carries on from the width it is at',
      );

      // And the two that are left still pinch.
      await _pinch(tester, a: b, b: c, centreX: 200, y: y + 149, from: 298, to: 240);
      expect(harness.width.widthFactor, lessThan(pinched));
      expect(tester.takeException(), isNull);
    });
  });

  group('the correction', () {
    testWidgets('is applied in the same turn as the width changes', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _seek(tester, harness, 100);

      const y = 270.0;
      final before = _under(tester, y);
      final offsetBefore = harness.scroll.offset;

      final a = await tester.startGesture(const Offset(140, y));
      final b = await tester.startGesture(const Offset(260, y));
      await tester.pump();
      // One step of the pinch, and no frame in between: the strip is already
      // laid out for the new width and already sitting at the offset that
      // goes with it, which is the whole of "in the same turn".
      await a.moveTo(const Offset(170, y));
      await b.moveTo(const Offset(230, y));
      expect(harness.width.widthFactor, lessThan(1.0));
      expect(
        harness.width.geometry.widthFactor,
        lessThan(1.0),
        reason: 'the geometry the strip is about to be drawn from is the new one',
      );
      final corrected = harness.scroll.offset;
      expect(
        corrected,
        isNot(moreOrLessEquals(offsetBefore, epsilon: 1)),
        reason: 'the offset moved with the width, and not a frame later',
      );

      // And the very first frame drawn at that width has the place under the
      // fingers: a correction deferred to a post-frame callback paints this
      // frame at the old offset, arrives a frame late everywhere, and leaves
      // the offset still moving here.
      await tester.pump();
      expect(
        harness.scroll.offset,
        moreOrLessEquals(corrected, epsilon: 0.01),
        reason: 'nothing was left to correct in the frame that drew it',
      );
      final after = _under(tester, y);
      expect(after.page, before.page);
      expect(after.fraction, moreOrLessEquals(before.fraction, epsilon: 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('never puts the strip off the end of its own content', (
      tester,
    ) async {
      // The clamp is the strip's own geometry and not the scroll extent,
      // which is the last frame's: `jumpTo` clamps nothing at all.
      final harness = await _pump(tester);
      await _seek(tester, harness, 0);

      const y = 100.0;
      final a = await tester.startGesture(const Offset(140, y));
      final b = await tester.startGesture(const Offset(260, y));
      await tester.pump();
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 120, to: 60);

      expect(harness.scroll.offset, moreOrLessEquals(0, epsilon: 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('the width a chapter opens at', () {
    testWidgets('moves the strip, and the place goes with it in the same turn', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _seek(tester, harness, 100);
      final before = _under(tester, 1);
      expect(before.page, 100, reason: 'the reader is on page 100');

      // The preference moved — the width slider, or a chapter reopened at the
      // width that was chosen — and the strip is narrower in the same breath,
      // with the page the reader is on still at the top of the screen.
      harness.width.openingWidthFactor = 0.5;
      expect(harness.width.widthFactor, 0.5);
      final corrected = harness.scroll.offset;

      // Nothing left to correct in the frame that draws it: a correction that
      // waited for the frame after painted one frame at the old offset, which
      // for the slider is a jump on every one of its dozens of steps.
      await tester.pump();
      expect(
        harness.scroll.offset,
        moreOrLessEquals(corrected, epsilon: 0.01),
        reason: 'the offset moved with the width, and not a frame later',
      );
      final painted = _painted(tester)
          .where((page) => page.page == before.page)
          .singleOrNull;
      expect(painted, isNotNull, reason: 'the page it was on is still drawn');
      expect(painted!.top, moreOrLessEquals(0, epsilon: 0.5));
      expect(
        _rectOf(tester, before.page).width,
        moreOrLessEquals(_screenWidth / 2, epsilon: 0.5),
        reason: 'and it is drawn at the width that was asked for',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrowing at the end of the chapter keeps the last page', (
      tester,
    ) async {
      // The clamp is the strip's own geometry and not the scroll extent: at
      // the end of a chapter the held place asks for an offset past the end of
      // the new strip, and a clamp taken from `maxScrollExtent` — the last
      // frame's, an extent the strip has not been laid out at — is the end of
      // the chapter left hundreds of points above the bottom of the screen.
      final harness = await _pump(tester);
      harness.scroll.jumpTo(harness.scroll.position.maxScrollExtent);
      await tester.pump();

      harness.width.openingWidthFactor = 0.5;
      await tester.pump();

      expect(
        harness.scroll.offset,
        moreOrLessEquals(harness.scroll.position.maxScrollExtent, epsilon: 0.5),
      );
      expect(
        tester.getBottomRight(find.byKey(const ValueKey(199))).dy,
        moreOrLessEquals(_viewportHeight, epsilon: 0.5),
        reason: 'the last page is at the bottom of the screen',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('what a pinch writes', () {
    testWidgets('nothing: the chapter opens at the width that was chosen', (
      tester,
    ) async {
      // A chapter that opens at 0.8, which is what a preference of 0.8 buys.
      final first = await _pump(tester, widthFactor: 0.8);
      expect(
        _rectOf(tester, 0).width,
        moreOrLessEquals(_screenWidth * 0.8, epsilon: 0.5),
      );

      const y = 270.0;
      final a = await tester.startGesture(const Offset(140, y));
      final b = await tester.startGesture(const Offset(260, y));
      await tester.pump();
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 120, to: 60);
      expect(first.width.widthFactor, lessThan(0.6));

      // Reopened: another controller, built from the preference the way the
      // reader builds one, and not from where the last one was pinched to.
      await _pump(tester, widthFactor: 0.8);
      expect(
        _rectOf(tester, 0).width,
        moreOrLessEquals(_screenWidth * 0.8, epsilon: 0.5),
        reason: 'the width a pinch left does not outlive the chapter',
      );
    });

    testWidgets('nothing to the decoder until it settles', (tester) async {
      // #48 tied the decode width to the width the strip is drawn at, which
      // is right — but a pinch changes that width continuously, and
      // `ResizeImage` puts it in its cache key: a decode width that followed
      // every pinch frame would re-decode every live page throughout the
      // gesture. So it follows the width the strip *settled* at, and moves
      // once, when the fingers are gone.
      final harness = await _pump(tester, images: true);
      await _seek(tester, harness, 100);

      int asked(int page) =>
          (tester.widget<Image>(find.byKey(ValueKey(page))).image
                  as ResizeImage)
              .width!;

      // Drawn at 400, decoded at 400 in a 3x device's pixels.
      expect(asked(100), 1200);

      const y = 270.0;
      final a = await tester.startGesture(const Offset(140, y));
      final b = await tester.startGesture(const Offset(260, y));
      await tester.pump();
      await _pinch(tester, a: a, b: b, centreX: 200, y: y, from: 120, to: 60);

      // Half the width on the screen, and the same picture asked of the
      // decoder: the one already in the cache, which is also the memory the
      // strip was already paying for.
      expect(_rectOf(tester, 100).width, moreOrLessEquals(200, epsilon: 0.5));
      expect(asked(100), 1200);

      // Settled: the width stops moving with the last finger but one, and the
      // decoder is asked once, then — not on any frame of the pinch, and not
      // again when the last finger goes.
      await a.up();
      await tester.pump();
      expect(asked(100), 600);
      await b.up();
      await tester.pump();
      expect(asked(100), 600);
    });
  });
}
