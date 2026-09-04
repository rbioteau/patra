import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/magnify_gesture.dart';

/// A phone-shaped canvas and a 2:3 scan, which is letterboxed in it: the
/// artwork fills the width and leaves a bar above and below. That mismatch is
/// the normal case, not an edge case, and most of what can go wrong here goes
/// wrong in those bars.
const _viewport = Size(380, 620);
final _content = drawnContent(_viewport, const [2 / 3]);

MagnifyGesture _from(Offset anchor) =>
    MagnifyGesture(viewport: _viewport, content: _content, anchor: anchor);

/// Which point of the artwork (0..1 each way) is under [at].
Offset _under(MagnifyTransform t, Offset at) => Offset(
  (at.dx - t.origin.dx) / (t.content.width * t.scale),
  (at.dy - t.origin.dy) / (t.content.height * t.scale),
);

void main() {
  group('the page at rest', () {
    test('a 2:3 scan fills the width and is centred in the height', () {
      expect(_content.left, 0);
      expect(_content.width, 380);
      expect(_content.height, closeTo(570, 0.01));
      expect(_content.top, closeTo(25, 0.01));
    });

    test('a finger down but not moved leaves the page exactly where it was', () {
      final anchor = const Offset(190, 310);
      final t = _from(anchor).to(anchor);
      expect(t.scale, 1);
      expect(t.origin, _content.topLeft);
      expect(t.isRest, isTrue);
    });
  });

  group('the direction rule', () {
    // The design asked for this in terms of directions — pull down to see
    // above, pull right to see the left — and the implementation answers it
    // with one rule rather than four cases: the page is carried along with
    // the finger. What has to hold is where the *view* ends up, which is the
    // thing a reader can see; whether the artwork stayed exactly under the
    // finger is a mechanism, and at the shipped settings the page spends most
    // of a drag pinned against an edge instead (see 'the border is what is
    // held' below).
    const anchor = Offset(190, 310);

    /// The part of the artwork on screen, in fractions of the page.
    Rect windowOf(MagnifyTransform t) {
      final width = t.content.width * t.scale;
      final height = t.content.height * t.scale;
      return Rect.fromLTRB(
        ((0 - t.origin.dx) / width).clamp(0.0, 1.0),
        ((0 - t.origin.dy) / height).clamp(0.0, 1.0),
        ((_viewport.width - t.origin.dx) / width).clamp(0.0, 1.0),
        ((_viewport.height - t.origin.dy) / height).clamp(0.0, 1.0),
      );
    }

    test('at rest the whole page is on screen', () {
      expect(windowOf(_from(anchor).to(anchor)), const Rect.fromLTRB(0, 0, 1, 1));
    });

    test('pulling down shows the part above', () {
      final window = windowOf(_from(anchor).to(anchor + const Offset(0, 120)));
      expect(window.center.dy, lessThan(0.5));
      expect(window.top, closeTo(0, 0.01));
    });

    test('pulling up shows the part below', () {
      final window = windowOf(_from(anchor).to(anchor - const Offset(0, 120)));
      expect(window.center.dy, greaterThan(0.5));
      expect(window.bottom, closeTo(1, 0.01));
    });

    test('pulling right shows the part to the left', () {
      final window = windowOf(_from(anchor).to(anchor + const Offset(120, 0)));
      expect(window.center.dx, lessThan(0.5));
      expect(window.left, closeTo(0, 0.01));
    });

    test('pulling left shows the part to the right', () {
      final window = windowOf(_from(anchor).to(anchor - const Offset(120, 0)));
      expect(window.center.dx, greaterThan(0.5));
      expect(window.right, closeTo(1, 0.01));
    });

    test('the view keeps travelling that way for the whole drag', () {
      // Not merely right at the end: a gesture that reversed itself halfway
      // would pass the four tests above and be unusable.
      var previous = 1.0;
      for (var drag = 20.0; drag <= 400; drag += 20) {
        final window = windowOf(_from(anchor).to(anchor + Offset(0, drag)));
        expect(window.center.dy, lessThan(previous), reason: 'at $drag');
        previous = window.center.dy;
      }
    });

    test('and does so from every reference point, not just a centred one', () {
      // The version of this test that swept only drag length, at one anchor in
      // the middle of the page, could not see the thing that was actually
      // wrong: a press near either end of the screen used to invert the rule —
      // pulling down walked the view *down* the page. Small (~1.6% of the
      // page) and entirely invisible to a centred sweep. The anchor is the
      // axis that has to be exhaustive here, exactly as it already is for the
      // border.
      // A hair of tolerance: the comparison is between two ratios of
      // floating-point sums, and a stationary result lands a few ulps either
      // side of the resting value. The defect being guarded against was four
      // orders of magnitude larger.
      const slack = 1e-9;
      for (var ay = 0.0; ay <= _viewport.height; ay += 5) {
        final at = Offset(190, ay);
        final rest = windowOf(_from(at).to(at)).center.dy;
        for (final drag in const [25.0, 50.0, 100.0, 200.0, 300.0, 400.0]) {
          expect(
            windowOf(_from(at).to(at + Offset(0, drag))).center.dy,
            lessThanOrEqualTo(rest + slack),
            reason: 'pulling down $drag from y=$ay must not walk the view down',
          );
          expect(
            windowOf(_from(at).to(at - Offset(0, drag))).center.dy,
            greaterThanOrEqualTo(rest - slack),
            reason: 'pulling up $drag from y=$ay must not walk the view up',
          );
        }
      }
    });

    test('the same holds across the other axis', () {
      const slack = 1e-9;
      for (var ax = 0.0; ax <= _viewport.width; ax += 5) {
        final at = Offset(ax, 310);
        final rest = windowOf(_from(at).to(at)).center.dx;
        for (final drag in const [25.0, 100.0, 250.0, 400.0]) {
          expect(
            windowOf(_from(at).to(at + Offset(drag, 0))).center.dx,
            lessThanOrEqualTo(rest + slack),
            reason: 'pulling right $drag from x=$ax must not walk the view right',
          );
          expect(
            windowOf(_from(at).to(at - Offset(drag, 0))).center.dx,
            greaterThanOrEqualTo(rest - slack),
            reason: 'pulling left $drag from x=$ax must not walk the view left',
          );
        }
      }
    });

    test('the artwork stays under the finger wherever there is room for it', () {
      // The underlying rule, shown where the page is big enough to obey it: a
      // drag at full travel has slack to spare.
      final t = _from(anchor).to(anchor + const Offset(0, kMagnifyTravel));
      final under = _under(t, anchor + const Offset(0, kMagnifyTravel));
      expect(under.dx, closeTo(0.5, 0.01));
      expect(under.dy, closeTo(0.5, 0.01));
    });

    test('the same drag magnifies the same amount whichever way it points', () {
      final scales = [
        for (final drag in const [
          Offset(0, 120),
          Offset(0, -120),
          Offset(120, 0),
          Offset(-120, 0),
          Offset(84.853, 84.853),
        ])
          _from(anchor).to(anchor + drag).scale,
      ];
      for (final scale in scales) {
        expect(scale, closeTo(scales.first, 1e-3));
      }
    });
  });

  group('the length of the drag sets the magnification', () {
    const anchor = Offset(190, 310);

    test('it grows from 1 to the ceiling over the travel distance', () {
      expect(_from(anchor).to(anchor).scale, 1);
      final half = _from(anchor).to(anchor + const Offset(0, kMagnifyTravel / 2));
      expect(half.scale, closeTo(1 + (kMagnifyMaxScale - 1) / 2, 0.001));
      final full = _from(anchor).to(anchor + const Offset(0, kMagnifyTravel));
      expect(full.scale, closeTo(kMagnifyMaxScale, 0.001));
    });

    test('it never passes the ceiling, however far the drag runs', () {
      final t = _from(anchor).to(anchor + const Offset(0, kMagnifyTravel * 4));
      expect(t.scale, kMagnifyMaxScale);
    });

    test('only the length counts, not the direction', () {
      final down = _from(anchor).to(anchor + const Offset(0, 100));
      final across = _from(anchor).to(anchor + const Offset(100, 0));
      final diagonal = _from(
        anchor,
      ).to(anchor + const Offset(70.71067, 70.71067));
      expect(across.scale, closeTo(down.scale, 1e-9));
      expect(diagonal.scale, closeTo(down.scale, 1e-4));
    });

    test('the travel distance is the same on any screen', () {
      // It was briefly capped at the screen's longest side. That was dead on
      // every real device and said the opposite of why the constant is
      // absolute: the ruler is a thumb, and a thumb does not shrink with the
      // display.
      const small = Size(120, 200);
      final gesture = MagnifyGesture(
        viewport: small,
        content: drawnContent(small, const [2 / 3]),
        anchor: const Offset(60, 100),
      );
      final half = gesture.to(const Offset(60, 100 + kMagnifyTravel / 2));
      expect(half.scale, closeTo(1 + (kMagnifyMaxScale - 1) / 2, 0.001));
    });
  });

  group('the border is what is held', () {
    // The constraint the design put above everything else: magnifying must
    // never open a band of black beside the artwork.
    void expectCovers(MagnifyTransform t, Size viewport, {String? reason}) {
      final r = t.rect;
      if (r.width >= viewport.width) {
        expect(r.left, lessThanOrEqualTo(0.01), reason: reason);
        expect(r.right, greaterThanOrEqualTo(viewport.width - 0.01),
            reason: reason);
      } else {
        // Too small to cover: it must at least stay wholly on screen.
        expect(r.left, greaterThanOrEqualTo(-0.01), reason: reason);
        expect(r.right, lessThanOrEqualTo(viewport.width + 0.01),
            reason: reason);
      }
      if (r.height >= viewport.height) {
        expect(r.top, lessThanOrEqualTo(0.01), reason: reason);
        expect(r.bottom, greaterThanOrEqualTo(viewport.height - 0.01),
            reason: reason);
      } else {
        expect(r.top, greaterThanOrEqualTo(-0.01), reason: reason);
        expect(r.bottom, lessThanOrEqualTo(viewport.height + 0.01),
            reason: reason);
      }
    }

    test('pressing at the very top and pulling down cannot pull the page off '
        'the top of the screen', () {
      const anchor = Offset(190, 30);
      final t = _from(anchor).to(anchor + const Offset(0, 300));
      expectCovers(t, _viewport);
      // The grip is what gave way, which is the chosen answer: the artwork
      // slid out from under the finger rather than the border opening.
      expect(t.rect.top, closeTo(0, 0.01));
      final now = _under(t, anchor + const Offset(0, 300));
      expect(now.dy, isNot(closeTo(0.0088, 0.01)));
    });

    test('no gesture anywhere on the canvas can uncover the artwork', () {
      var checked = 0;
      for (var ax = 2.0; ax < _viewport.width; ax += 17) {
        for (var ay = 2.0; ay < _viewport.height; ay += 23) {
          final gesture = _from(Offset(ax, ay));
          for (var fx = 2.0; fx < _viewport.width; fx += 41) {
            for (var fy = 2.0; fy < _viewport.height; fy += 53) {
              final t = gesture.to(Offset(fx, fy));
              expectCovers(t, _viewport, reason: '($ax,$ay) -> ($fx,$fy)');
              expect(t.scale, inInclusiveRange(1, kMagnifyMaxScale));
              checked++;
            }
          }
        }
      }
      expect(checked, greaterThan(5000));
    });

    test('a drag far outside the canvas is still bounded', () {
      final t = _from(const Offset(190, 310)).to(const Offset(-4000, 9000));
      expectCovers(t, _viewport);
    });
  });

  group('letting go', () {
    test('the way back ends exactly at rest', () {
      const anchor = Offset(190, 310);
      final held = _from(anchor).to(anchor + const Offset(0, 200));
      final rest = MagnifyTransform.rest(held.content);
      expect(MagnifyTransform.lerp(held, rest, 0).origin, held.origin);
      final landed = MagnifyTransform.lerp(held, rest, 1);
      expect(landed.scale, 1);
      expect(landed.origin, _content.topLeft);
      expect(landed.isRest, isTrue);
    });
  });

  group('the matrix', () {
    test('carries the artwork from where it rests to where it is drawn', () {
      const anchor = Offset(190, 310);
      final t = _from(anchor).to(anchor + const Offset(0, 180));
      // The child draws the artwork at `content`; after the transform its
      // corners must be exactly `rect`.
      final m = t.matrix;
      Offset apply(Offset p) => Offset(
        m.storage[0] * p.dx + m.storage[4] * p.dy + m.storage[12],
        m.storage[1] * p.dx + m.storage[5] * p.dy + m.storage[13],
      );
      expect(apply(t.content.topLeft).dx, closeTo(t.rect.left, 0.001));
      expect(apply(t.content.topLeft).dy, closeTo(t.rect.top, 0.001));
      expect(apply(t.content.bottomRight).dx, closeTo(t.rect.right, 0.001));
      expect(apply(t.content.bottomRight).dy, closeTo(t.rect.bottom, 0.001));
    });
  });

  group('where the artwork is drawn', () {
    test('a landscape scan letterboxes at the sides instead', () {
      final wide = drawnContent(_viewport, const [3 / 2]);
      expect(wide.width, closeTo(380, 0.01));
      expect(wide.height, closeTo(380 / 1.5, 0.01));
      expect(wide.top, closeTo((620 - 380 / 1.5) / 2, 0.01));
    });

    test('a spread is the box around both scans, meeting on the spine', () {
      const landscape = Size(1180, 820);
      final pair = drawnContent(landscape, const [2 / 3, 2 / 3]);
      final half = landscape.width / 2;
      final each = math.min(landscape.height, half / (2 / 3));
      expect(pair.width, closeTo(each * (2 / 3) * 2, 0.01));
      // Centred on the spine, because the two scans are the same shape.
      expect(pair.center.dx, closeTo(half, 0.01));
    });

    test('a spread of two different shapes does not jump when touched', () {
      const landscape = Size(1180, 820);
      final pair = drawnContent(landscape, const [2 / 3, 1 / 2]);
      // Off-centre at rest, since the narrower scan takes less of its half.
      expect(pair.center.dx, isNot(closeTo(landscape.width / 2, 1)));
      final gesture = MagnifyGesture(
        viewport: landscape,
        content: pair,
        anchor: pair.center,
      );
      // A touch with no movement must leave it exactly where it was, rather
      // than sliding it to the middle of the screen.
      expect(gesture.to(pair.center).origin, pair.topLeft);
    });

    test('an unmeasurable page falls back to the whole canvas', () {
      expect(drawnContent(_viewport, const []), Offset.zero & _viewport);
      expect(drawnContent(Size.zero, const [2 / 3]), Rect.zero);
    });
  });

  group('a degenerate gesture is inert rather than a crash', () {
    test('an empty viewport or empty artwork resolves to rest', () {
      const empty = MagnifyGesture(
        viewport: Size.zero,
        content: Rect.zero,
        anchor: Offset.zero,
      );
      expect(empty.to(const Offset(50, 50)).isRest, isTrue);
    });
  });
}
