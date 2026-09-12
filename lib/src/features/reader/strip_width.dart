import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'strip_geometry.dart';

/// The strip's width, and the two hands that change it.
///
/// One number, one owner: the width the strip is laid out at, the geometry
/// every offset is derived from, and the place the fingers are holding. Two
/// fingers change the width around their focal point and **write nothing** —
/// the width a chapter opens at is a preference (#49) and a pinch is a live
/// adjustment on top of it, so leaving the chapter and coming back is coming
/// back to the stored value.
///
/// Every pointer over the strip is arbitrated here rather than by the gesture
/// arena. One finger is handed to the scroll position's own drag — so physics
/// and flings stay the framework's — and a second finger turns the gesture
/// into a pinch, *cancelling* that drag on the way in, so a pinch that starts
/// on top of a moving list inherits none of its velocity. Lifting one of two
/// fingers starts a fresh drag where the remaining finger is. The scroll
/// view's own drag recognizer is given no device it accepts
/// ([StripWidthGestures]) so it never competes for a pointer at all.
///
/// Stage one only: `0.5`–`1.0`, the range [StripGeometry] holds. Below `1.0`
/// the strip is never wider than the screen, so there is no horizontal pan
/// and no axis to arbitrate — every bit of gesture risk lives above `1×`,
/// which is a later ticket, and nothing here is shaped for it.
///
/// A rotation is the one correction that is **not** made in the same turn:
/// the width is handed to us by a layout, and moving the strip from inside a
/// layout is what this screen has already died on. So it is named before the
/// resize ([measure]) and put back at the end of the frame that was laid out
/// at the new width — one frame drawn at the old offset, accepted and
/// recorded in ADR-0006. At a document edge no correction can hold the place
/// — there is no content left to put under the finger — so it clamps and
/// [clampedBy] says by how much rather than quietly missing.
class StripWidthController extends ChangeNotifier {
  StripWidthController({
    required ScrollController scroll,
    double widthFactor = 1.0,
    // A private field cannot be a named parameter, so the lint's suggestion
    // is not available here.
    // ignore: prefer_initializing_formals
  }) : _scroll = scroll,
       _factor = clampWidthFactor(widthFactor),
       _settled = clampWidthFactor(widthFactor);

  /// The range is [StripGeometry]'s to hold — a preference and a pinch both
  /// move this number and must not clamp it differently — so every clamp of
  /// it asks the same question.
  static double clampWidthFactor(double value) => value.clamp(
    StripGeometry.minWidthFactor,
    StripGeometry.maxWidthFactor,
  );

  final ScrollController _scroll;

  /// How wide the strip is laid out, as a fraction of the canvas. `1.0` is the
  /// whole screen.
  double _factor;
  double get widthFactor => _factor;

  /// The strip at [_factor]: every page's height and where every page starts.
  StripGeometry _geometry = StripGeometry.empty();
  StripGeometry get geometry => _geometry;

  /// What the strip is made of, and how wide the canvas is — the last things
  /// [measure] was told.
  double _screenWidth = 0;
  int _pages = 0;
  double Function(int page) _aspectRatioFor = _squareAspectRatio;
  Object? _identity;
  double? _measuredFactor;

  /// What a page's shape is before the strip has been told what it is made
  /// of: square, and never read, since a strip with no pages asks for no
  /// height. Not the default a chapter with no dimensions is read at, which
  /// is `PageDimension`'s to say.
  static double _squareAspectRatio(int page) => 1.0;

  /// The width the strip *settled* at: the one pages are decoded for, which a
  /// live pinch does not move. See [decodeWidth].
  double _settled;

  /// The width the strip settled at, in points: not [geometry]'s, which is
  /// the width it is being drawn at this instant.
  double get _settledWidth => _screenWidth * _settled;

  final Map<int, Offset> _pointers = <int, Offset>{};
  Drag? _drag;
  VelocityTracker? _tracker;
  Offset? _downAt;
  var _dragging = false;
  var _pinching = false;
  double? _startSpan;
  double? _startFactor;

  /// The place under the fingers: a page and a fraction down it, which is the
  /// form that survives every height changing at once.
  StripAnchor? _anchor;

  /// The same kind of place, held across a rotation: the canvas is being
  /// laid out at another width and there is nowhere to put the old offset
  /// yet. Kept apart from [_anchor], which belongs to the fingers.
  StripAnchor? _resizeAnchor;

  /// How far the last correction fell short. See [clampedBy].
  double _clampedBy = 0;

  /// Two fingers are down and the pinch has the gesture.
  ///
  /// The strip is being moved without anybody reading their way there, so
  /// nothing it lands on is progress.
  bool get pinching => _pinching;

  /// The canvas changed size under the strip — a rotation — and the place
  /// has not been put back yet.
  ///
  /// True from the layout that found the new width to the end of the frame
  /// that was drawn at it. What the strip shows in between is the old offset
  /// read against the new heights, which is not where the reader is, so
  /// nothing it lands on in that window is progress either.
  bool get resizing => _resizeAnchor != null;

  /// How far the last move of the strip fell short of the place it was asked
  /// to put it, in points. `0` when it landed where it was told to.
  ///
  /// Every move the module makes goes through [jumpToAnchor] — a correction,
  /// a seek, a chapter being opened — and what is short is always the same
  /// thing: a place the strip has no content for. At a document edge the
  /// anchor cannot be held, because there is no content left to put under the
  /// finger, so the correction clamps. A clamp nobody can see is a correction
  /// that looks as though it worked when it did not, so it is measured and
  /// left where anybody can read it rather than swallowed. (ADR-0006 measured
  /// 189px at the last page, on the prototype's chapter and device: what is
  /// lost is the whole of the strip that shrank away below the anchor, so it
  /// grows with the page and with how far the width moved.)
  double get clampedBy => _clampedBy;

  /// The width a page is asked of the decoder, in device pixels: the width the
  /// strip is drawn at *settled*, not the one a live pinch is passing through.
  ///
  /// Narrowing the strip puts more pages in the same cache extent — about
  /// three to five between full width and half — so a decode left at the
  /// file's own size multiplies decoded memory for a change nobody can see.
  /// But `ResizeImage` puts the width it is asked for in its cache key, and a
  /// pinch changes the drawn width continuously: a decode width that followed
  /// it would ask for a new image on every frame of the gesture and re-decode
  /// every live page throughout. So the width the decoder is asked for is the
  /// one the strip settled at — the preference, or where the last pinch let
  /// go — and it changes once, when the pinch is over: the moment the width
  /// stops moving, which is the last finger but one lifting and not the last
  /// one. What is drawn in between is the image already in the cache, which
  /// is also the memory the strip was already paying for.
  int decodeWidth(double devicePixelRatio) =>
      StripGeometry.decodeWidthFor(_settledWidth, devicePixelRatio);

  /// Told what the strip is made of, and how wide the canvas is — from the
  /// layout, the only place the width is known.
  ///
  /// Notifies nobody, because this runs *during* a layout: a build there is
  /// one this screen has already died on. What it does is leave [geometry]
  /// rebuilt, so the strip laid out in that same pass is laid out at the width
  /// it is about to be drawn at.
  ///
  /// [identity] is what the strip is made of, compared by identity: another
  /// chapter with as many pages is still another strip.
  void measure({
    required double screenWidth,
    required int pages,
    required double Function(int page) aspectRatioFor,
    Object? identity,
  }) {
    if (identity == _identity &&
        screenWidth == _screenWidth &&
        pages == _pages &&
        _factor == _measuredFactor) {
      // A pinch frame has already rebuilt the geometry at this width and this
      // factor, and the layout that follows it must not build it twice.
      return;
    }
    // The same chapter, the same number of pages, another width: the canvas
    // was turned. Not a new chapter, which places itself, and not a different
    // page count, which is a different strip.
    final resized =
        identity == _identity &&
        pages == _pages &&
        screenWidth != _screenWidth &&
        _geometry.pages > 0;
    // Once a frame, and not while two fingers hold the width: a second
    // width in the same frame would name the place off heights the strip has
    // not been drawn at yet, and a pinch has an owner already — its own
    // correction, about the fingers, on its next update at the new width.
    // Two owners of one correction is what this module exists to avoid. The
    // correction owed is paid at the end of the frame it was named in, which
    // is what empties [_resizeAnchor].
    if (resized && !_pinching && _resizeAnchor == null) {
      _resizeAnchor = _capture(0);
      _scheduleResizeCorrection();
    }
    _identity = identity;
    _screenWidth = screenWidth;
    _pages = pages;
    _aspectRatioFor = aspectRatioFor;
    _rebuild();
  }

  /// Puts the place back after the frame that was laid out at the new width.
  ///
  /// The one correction this module waits a frame for, and the only one that
  /// may: [measure] is handed the width *during* a layout, and a `jumpTo`
  /// from inside a layout is what this screen has already died on — it leaves
  /// a node needing layout whose relayout boundary does not know it. So the
  /// frame right after a rotation is drawn at the old offset: one frame,
  /// accepted, and the place is put back at the end of it, before the next
  /// one is built. A pinch never pays this, because a pinch knows its width
  /// before it asks for it.
  void _scheduleResizeCorrection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _resizeAnchor;
      if (anchor == null) return;
      if (!_scroll.hasClients) {
        // The strip it was going to move is gone. Dropped rather than left
        // owed, or [resizing] would stay true for the rest of the session
        // and the reader would go on gagging its own progress reports.
        _resizeAnchor = null;
        return;
      }
      // Still held until the strip has moved: the correction is a `jumpTo`,
      // and the scroll this screen listens to is told about it synchronously.
      jumpToAnchor(anchor, 0);
      _resizeAnchor = null;
      notifyListeners();
    });
  }

  /// The width a chapter opens at: the preference (#49), and the only width
  /// that is ever written.
  ///
  /// Setting it drops whatever the last pinch left, which is the whole of "a
  /// pinch writes nothing": leaving the chapter and coming back builds one of
  /// these from the preference and not from where the last one was pinched to.
  ///
  /// The place is held the same way a pinch holds it and in the same turn,
  /// about the top of the screen rather than about a pair of fingers: what
  /// must not move when every height changes is the page the reader is on. A
  /// correction that waited for the frame after would paint one frame at the
  /// old offset — once, for a preference set from a menu, and on every one of
  /// the dozens of steps of the width slider, which is the strip jumping
  /// through the whole drag.
  set openingWidthFactor(double value) {
    final next = clampWidthFactor(value);
    if (next == _factor && next == _settled) return;
    final anchor = _capture(0);
    _factor = next;
    _settled = next;
    _rebuild();
    if (anchor != null) jumpToAnchor(anchor, 0);
    notifyListeners();
  }

  // --- pointers -----------------------------------------------------------

  /// A finger has landed. The first is a scroll waiting to happen; the second
  /// turns the gesture into a pinch.
  void pointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1) {
      _downAt = event.localPosition;
      _dragging = false;
      _pinching = false;
      _tracker = VelocityTracker.withKind(event.kind);
      return;
    }
    if (_pointers.length == 2) {
      _startSpan = _span();
      _startFactor = _factor;
      _pinching = true;
      // The drag that was scrolling is dropped, and with it its velocity: a
      // pinch that starts on top of a moving list must not inherit a fling.
      // `cancel` and not `end`, which is the difference between dropping the
      // scroll and throwing it.
      final drag = _drag;
      _drag = null;
      _dragging = false;
      drag?.cancel();
      // And whatever was still moving under it — a fling the last gesture
      // left — is stopped too, or it carries the place out from under the
      // fingers while they are holding it.
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset);
      _anchor = _capture(_focal().dy);
    }
  }

  void pointerMove(PointerMoveEvent event) {
    final previous = _pointers[event.pointer];
    if (previous == null) return;
    _pointers[event.pointer] = event.localPosition;
    _tracker?.addPosition(event.timeStamp, event.localPosition);

    if (_pointers.length >= 2) {
      final span = _span();
      if (!_pinching || _startSpan == null || _startSpan! <= 0) return;
      // Measured against where the fingers started, not against the frame
      // before: a pinch that runs past the end of the range and comes back
      // picks the width up where it left it instead of accumulating, and a
      // pinch that is clamped does not creep.
      _pinchTo(_startFactor! * span / _startSpan!, _focal().dy);
      return;
    }

    if (!_dragging) {
      // Our own touch slop: the framework's belongs to a recognizer this
      // strip does not use, and a wobble is not a scroll.
      if ((event.localPosition - _downAt!).dy.abs() < kTouchSlop) return;
      _dragging = true;
      _startDrag(event);
    }
    final dy = event.localPosition.dy - previous.dy;
    _drag?.update(
      DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        globalPosition: event.position,
        delta: Offset(0, dy),
        primaryDelta: dy,
      ),
    );
  }

  void pointerUp(PointerUpEvent event) => _release(event, cancelled: false);

  void pointerCancel(PointerCancelEvent event) =>
      _release(event, cancelled: true);

  /// A finger is gone, whether it lifted or was taken away.
  ///
  /// A cancelled one drops what it was doing rather than throwing it, so no
  /// fling comes of a pointer the system took back.
  void _release(PointerEvent event, {required bool cancelled}) {
    final wasPinching = _pinching;
    _pointers.remove(event.pointer);
    if (cancelled) {
      final drag = _drag;
      _drag = null;
      _dragging = false;
      drag?.cancel();
    }

    if (_pointers.isEmpty) {
      // The last one: whatever it was doing ends with it — a fling if it was
      // scrolling — and the width it leaves is the width pages are decoded at.
      _endDrag();
      _pinching = false;
      if (wasPinching) _settle();
      return;
    }

    if (!wasPinching) return;

    if (_pointers.length == 1) {
      // One finger left: the pinch is over and the strip goes back to the
      // scroll, from where that finger is *now*, so nothing jumps on the way
      // out of the gesture.
      _pinching = false;
      _settle();
      _downAt = _pointers.values.first;
      _dragging = false;
      _tracker = VelocityTracker.withKind(event.kind);
      return;
    }

    // Two or more left — a third finger that has been ignored throughout, or
    // one of three that has just gone. The pair the width is measured between
    // is not the pair it was, so the pinch starts again from the width the
    // strip is at: without this the width jumps by the difference between the
    // two spans the moment a finger leaves.
    _startSpan = _span();
    _startFactor = _factor;
  }

  // --- the width ----------------------------------------------------------

  /// Relays out at [next] and puts the place the fingers are holding back
  /// under them in the same turn, before the frame that draws it is laid out.
  ///
  /// In the same turn, because these two are one correction and not two: a
  /// width on its own leaves the strip somewhere else in the chapter, and a
  /// correction deferred to a post-frame callback is drawn a frame late, while
  /// one made from a layout callback is what this screen has already died on.
  void _pinchTo(double next, double focalY) {
    final before = _factor;
    final anchor = _anchor;
    _factor = next;
    _rebuild();
    if (_factor == before || anchor == null) return;
    jumpToAnchor(anchor, focalY);
    notifyListeners();
  }

  /// Rebuilds the geometry at [_factor], taking the width back clamped: the
  /// range is [StripGeometry]'s to hold, since a preference and a pinch both
  /// move this number and must not clamp it differently.
  void _rebuild() {
    _geometry = StripGeometry(
      screenWidth: _screenWidth,
      widthFactor: _factor,
      pages: _pages,
      aspectRatioFor: _aspectRatioFor,
    );
    _factor = _geometry.widthFactor;
    _measuredFactor = _factor;
  }

  /// The place at [focalY], named off the geometry the strip is drawn at now
  /// — the one the current offset belongs to.
  ///
  /// Null when there is nothing to name: no scroll position yet, or a strip
  /// that has not been measured. A caller holding one of these for later
  /// simply has nothing to put back.
  StripAnchor? _capture(double focalY) {
    if (!_scroll.hasClients || _geometry.pages == 0) return null;
    return _geometry.anchorAt(_scroll.offset + focalY);
  }

  /// Puts [anchor] at [focalY] in the viewport — at the top of it by default
  /// — and nowhere else: clamped to what the strip can actually scroll to.
  ///
  /// Clamped against this geometry and not against `maxScrollExtent`, which is
  /// the last frame's layout and an extent the strip has not been laid out at
  /// yet: `jumpTo` clamps nothing at all, an offset past either end of the
  /// strip is a strip drawn off its own content, and widening it at the end of
  /// a chapter asks for an offset the old extent does not have.
  ///
  /// The reader asks for this whenever it moves the strip itself — opening a
  /// chapter, a seek from the scrubber, a width the preference changed — and
  /// the pinch asks for the same thing about a point under the fingers.
  ///
  /// Where it cannot hold the place it clamps, and leaves by how much in
  /// [clampedBy] rather than swallowing it: at a document edge the shortfall
  /// is the whole of what the strip lost below the fingers, and a correction
  /// that reported nothing would read as one that worked.
  void jumpToAnchor(StripAnchor anchor, [double focalY = 0.0]) {
    if (!_scroll.hasClients || _geometry.pages == 0) return;
    // `jumpTo` calls `goIdle` on the way in, so whatever was still moving the
    // strip — a fling the last gesture left — is dropped rather than left to
    // carry the place away from the one that is being put back.
    final wanted = _geometry.offsetFor(anchor) - focalY;
    final most = math.max(
      0.0,
      _geometry.total - _scroll.position.viewportDimension,
    );
    _clampedBy = (wanted - wanted.clamp(0.0, most)).abs();
    _scroll.jumpTo(wanted.clamp(0.0, most));
  }

  /// The gesture is over: the width it left is the width pages are decoded
  /// at, until the next one moves it.
  void _settle() {
    if (_settled == _factor) return;
    _settled = _factor;
    notifyListeners();
  }

  // --- the scroll ---------------------------------------------------------

  /// One finger, handed to the scroll position's own drag: physics, flings and
  /// overscroll stay the framework's, and this is the only thing that starts
  /// one.
  void _startDrag(PointerMoveEvent event) {
    if (!_scroll.hasClients) return;
    _drag = _scroll.position.drag(
      DragStartDetails(
        sourceTimeStamp: event.timeStamp,
        globalPosition: event.position,
        kind: event.kind,
      ),
      () => _drag = null,
    );
  }

  void _endDrag() {
    final drag = _drag;
    _drag = null;
    _dragging = false;
    if (drag == null) return;
    var vertical = _tracker?.getVelocity().pixelsPerSecond.dy ?? 0.0;
    // A gesture whose samples all carry the same clock — a synthetic one —
    // has no velocity to speak of, and a velocity that is not a number is not
    // one the position can be handed.
    if (!vertical.isFinite) vertical = 0;
    drag.end(
      DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(0, vertical)),
        primaryVelocity: vertical,
      ),
    );
  }

  Offset _focal() {
    var x = 0.0;
    var y = 0.0;
    for (final position in _pointers.values) {
      x += position.dx;
      y += position.dy;
    }
    return Offset(x / _pointers.length, y / _pointers.length);
  }

  /// How far apart the first two fingers are. A third is read and ignored,
  /// which is what stops it from changing the width.
  double _span() {
    if (_pointers.length < 2) return 0;
    final first = _pointers.values.take(2).toList();
    return (first[0] - first[1]).distance;
  }

  @override
  void dispose() {
    _drag = null;
    _pointers.clear();
    // A correction still owed is dropped rather than made: the strip it was
    // going to move is gone.
    _resizeAnchor = null;
    super.dispose();
  }
}

/// Every pointer over [child], whether it scrolls the strip or changes the
/// width it is laid out at.
///
/// Above the scroll view, and the scroll view is given no device its drag
/// recognizer accepts, so nothing beneath competes for the same pointer — the
/// strip's motion has one owner, and it is not the framework's. A vertical
/// drag and a pinch cannot both win the gesture arena, and the stock
/// composition settles that contest by luck: measured, a pinch that starts
/// while the first finger is already scrolling does not start at all, and one
/// that does holds on to the previous gesture's anchor. (ADR-0006, and the
/// prototype it records: `prototype/reader-strip-width`, variant A against B.)
///
/// [StripWidthController] does the rest.
class StripWidthGestures extends StatelessWidget {
  const StripWidthGestures({
    super.key,
    required this.controller,
    required this.child,
  });

  final StripWidthController controller;

  /// The strip: a scroll view, whose own drag recognizer is about to be given
  /// no device it accepts.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Translucent and not opaque: the scroll view beneath still has to be
      // hit, because a wheel and a trackpad reach it as a pointer signal,
      // which is not a drag and is not ours to arbitrate.
      behavior: HitTestBehavior.translucent,
      onPointerDown: controller.pointerDown,
      onPointerMove: controller.pointerMove,
      onPointerUp: controller.pointerUp,
      onPointerCancel: controller.pointerCancel,
      child: ScrollConfiguration(
        // The ambient behaviour with no device left that can drag it, which is
        // what keeps the framework's own recognizer out of the arena.
        // `copyWith` and not a `ScrollBehavior` of our own, because a
        // behaviour written from scratch would quietly leave the strip without
        // the platform's physics — and with them without the fling a
        // one-finger drag ends in.
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: const <PointerDeviceKind>{}),
        child: child,
      ),
    );
  }
}
