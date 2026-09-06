import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;

/// A one-finger drag that magnifies the page — the reader's alternative to
/// pinching, which needs two thumbs and a free hand.
///
/// The whole gesture is one rule: **the artwork under the finger stays under
/// the finger while it grows**, and how far the finger has travelled decides
/// how much it grows. Every direction the design asked for falls out of that
/// rule rather than being cased on: pulling *down* carries the page down with
/// the finger, so what was *above* comes into view; pulling *right* brings the
/// part to the *left*. There is no `if (dy > 0)` anywhere here, and there
/// should never be one.
///
/// The artwork never stops covering the screen. Where the drag asks to go past
/// an edge, the page stops at that edge and the artwork slides out from under
/// the finger instead — **the border is what is held, and the grip is what
/// gives way**. That is not a rare corner: at [kMagnifyMaxScale] over
/// [kMagnifyTravel] there is little slack, so a page is pinned against an edge
/// for most of a typical drag and properly glued only near full travel. The
/// guarantee a reader can see is therefore about the *view* — pulling down
/// walks it towards the top of the page, and keeps walking that way for the
/// whole drag — rather than about a point staying under the fingertip. That
/// holds from *every* reference point, which took a correction: a press within
/// [_band] of a screen edge used to invert it (see there). Both are pinned in
/// `test/magnify_gesture_test.dart`, whose anchor sweep is exhaustive for the
/// same reason the border sweep is.
///
/// Three other answers were built and rejected: refusing the rest of the drag
/// once the page runs out (near an edge it refuses almost the whole gesture),
/// magnifying harder to make room (a jump straight to the ceiling off a short
/// drag), and aiming a loupe without carrying the page at all (workable, but
/// it gives up direct manipulation). See
/// `docs/adr/0001-reader-magnify-gesture.md`.

/// How far the finger travels for [kMagnifyMaxScale], in logical pixels.
///
/// Deliberately **not** a fraction of the screen. The ruler for this gesture is
/// a thumb, and a thumb is the same size on a phone and on a tablet — scaling
/// the distance with the screen would make the same magnification cost twice
/// the reach on the bigger device, for no reason a hand would recognise. A
/// logical pixel is already density-independent, so this is a physical
/// distance: roughly 6 cm, about one comfortable sweep plus a short regrip.
const kMagnifyTravel = 400.0;

/// The strongest magnification a drag can reach. Low on purpose: a gentle
/// ceiling is what makes the whole range of the drag useful for aiming, where
/// a large one spends most of the gesture overshooting.
const kMagnifyMaxScale = 2.5;

/// Where the page is, and how big, for one frame of the gesture.
@immutable
class MagnifyTransform {
  const MagnifyTransform({
    required this.content,
    required this.scale,
    required this.origin,
  });

  /// Where the artwork sits when nothing is being pressed.
  final Rect content;

  final double scale;

  /// Where the artwork's top-left corner sits now, in viewport coordinates.
  final Offset origin;

  MagnifyTransform.rest(Rect content)
    : this(content: content, scale: 1, origin: content.topLeft);

  bool get isRest => scale == 1 && origin == content.topLeft;

  /// The artwork as drawn.
  Rect get rect => origin & (content.size * scale);

  /// What to apply to a child filling the viewport, so that the artwork it
  /// draws at [content] lands on [rect].
  Matrix4 get matrix {
    // A point p in the child maps to origin + scale * (p - content.topLeft),
    // which is a scale about the child's own origin plus this translation.
    final dx = origin.dx - content.left * scale;
    final dy = origin.dy - content.top * scale;
    return Matrix4(
      scale,
      0,
      0,
      0, //
      0,
      scale,
      0,
      0, //
      0,
      0,
      1,
      0, //
      dx,
      dy,
      0,
      1, //
    );
  }

  static MagnifyTransform lerp(
    MagnifyTransform a,
    MagnifyTransform b,
    double t,
  ) => MagnifyTransform(
    content: a.content,
    scale: a.scale + (b.scale - a.scale) * t,
    origin: Offset.lerp(a.origin, b.origin, t)!,
  );
}

/// A gesture in progress: the finger went down at [anchor], and every position
/// it reaches from there resolves to a [MagnifyTransform].
@immutable
class MagnifyGesture {
  const MagnifyGesture({
    required this.viewport,
    required this.content,
    required this.anchor,
    this.travel = kMagnifyTravel,
    this.maxScale = kMagnifyMaxScale,
  });

  final Size viewport;

  /// Where the artwork is drawn at rest — not the viewport, which on most
  /// scans has letterbox bars down two of its sides. Holding the *artwork*
  /// against the screen edges is the point; holding the bars there would let
  /// the drag pan over black.
  final Rect content;

  /// Where the finger went down. Anywhere on screen, including a bar: a
  /// reference point off the artwork is pulled to its nearest edge rather
  /// than refused, since refusing a touch says nothing to the person making
  /// it.
  final Offset anchor;

  final double travel;
  final double maxScale;

  bool get _degenerate =>
      content.isEmpty || viewport.isEmpty || travel <= 0 || maxScale <= 1;

  /// How far from the middle of the screen a reference point may sit before
  /// the direction rule starts to invert.
  ///
  /// Derived rather than tuned. The view's position in the page is
  ///
  ///     centre(d) = v - (a + d - V/2) / h,   h = H + d·H·(m-1)/T
  ///
  /// for a reference point `v` of the way down artwork of height `H`, pressed
  /// at viewport `a` on a viewport of height `V` and dragged `d`. Differentiate
  /// and the `d` terms cancel, leaving a condition on the anchor alone: the
  /// centre moves the way the drag asked only while
  ///
  ///     |a - V/2| < T / (m - 1)
  ///
  /// Outside that band the page grows faster than the glue can carry it, and
  /// pulling down walks the view *down* the page instead of up — by little
  /// (~1.6% of the page at the shipped settings), but the wrong way. `H` and
  /// `V` cancel out, so this is one number for both axes and every page shape.
  double get _band => travel / (maxScale - 1);

  /// Where the gesture is treated as having started.
  ///
  /// A press outside the band above is pulled to its edge, and the finger is
  /// carried along by the same amount so the drag vector — and therefore the
  /// magnification — is untouched. At the shipped settings this only moves a
  /// press within ~43pt of a screen edge, which is imperceptible, and it is
  /// what makes the direction rule true everywhere rather than almost
  /// everywhere.
  Offset get _start => Offset(
    anchor.dx.clamp(viewport.width / 2 - _band, viewport.width / 2 + _band),
    anchor.dy.clamp(viewport.height / 2 - _band, viewport.height / 2 + _band),
  );

  MagnifyTransform to(Offset finger) {
    if (_degenerate) return MagnifyTransform.rest(content);

    final start = _start;
    // The drag is the finger's own travel, so shifting where the gesture is
    // deemed to have begun must shift the finger with it.
    final at = finger + (start - anchor);

    // The reference point, as a fraction of the artwork.
    final u = ((start.dx - content.left) / content.width).clamp(0.0, 1.0);
    final v = ((start.dy - content.top) / content.height).clamp(0.0, 1.0);

    // Length of the drag decides the magnification, and only its length: the
    // direction is already spoken for, by which part of the page the finger
    // is carrying towards itself.
    //
    // [travel] is used as given. It was briefly capped at the screen's longest
    // side, which was dead on every real device and, worse, said the opposite
    // of the reason the constant is absolute: a cap by screen size is exactly
    // the screen-relative ruler that comment rejects.
    final scale = (1 + (finger - anchor).distance / travel * (maxScale - 1))
        .clamp(1.0, maxScale);

    final width = content.width * scale;
    final height = content.height * scale;
    return MagnifyTransform(
      content: content,
      scale: scale,
      origin: Offset(
        _place(
          at.dx - u * width,
          width,
          viewport.width,
          content.left,
          content.width,
        ),
        _place(
          at.dy - v * height,
          height,
          viewport.height,
          content.top,
          content.height,
        ),
      ),
    );
  }

  /// One axis. [want] is where the artwork's leading edge must be for the
  /// reference point to stay under the finger.
  ///
  /// While the artwork is bigger than the screen on this axis it may slide,
  /// but only as far as still covers it — that clamp is the border constraint,
  /// and it is the only thing standing between a magnified page and a band of
  /// black down one side. While it is *smaller* than the screen it cannot
  /// slide at all: it grows about its own resting centre and stays there, so a
  /// spread whose two scans are different widths does not jump sideways the
  /// moment it is touched.
  static double _place(
    double want,
    double drawn,
    double viewport,
    double restLeading,
    double restLength,
  ) {
    if (drawn >= viewport) return want.clamp(viewport - drawn, 0.0);
    final held = restLeading - (drawn - restLength) / 2;
    return held.clamp(0.0, viewport - drawn);
  }
}

/// Where the artwork is actually drawn inside [viewport], given the aspect
/// ratio of each page sharing the screen, in the order they are drawn.
///
/// One page is contained and centred. Two are a spread: each is contained in
/// its own half and pushed against the spine, so the pair meets on the centre
/// line — this returns the box around both, which is what has to stay on
/// screen. A page whose scan is taller than its half leaves the pair shorter
/// than the screen, and that is the resting shape, not a fault.
Rect drawnContent(Size viewport, List<double> aspectRatios) {
  if (viewport.isEmpty || aspectRatios.isEmpty) return Offset.zero & viewport;

  Size contain(Size box, double aspect) {
    if (box.isEmpty || aspect <= 0) return Size.zero;
    final height = math.min(box.height, box.width / aspect);
    return Size(height * aspect, height);
  }

  if (aspectRatios.length == 1) {
    final size = contain(viewport, aspectRatios.first);
    return Alignment.center.inscribe(size, Offset.zero & viewport);
  }

  final half = Size(viewport.width / 2, viewport.height);
  final leading = contain(half, aspectRatios[0]);
  final trailing = contain(half, aspectRatios[1]);
  final tallest = math.max(leading.height, trailing.height);
  return Rect.fromLTWH(
    viewport.width / 2 - leading.width,
    (viewport.height - tallest) / 2,
    leading.width + trailing.width,
    tallest,
  );
}
