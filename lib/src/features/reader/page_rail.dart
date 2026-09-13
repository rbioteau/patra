import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';
import 'strip_geometry.dart';

/// The page rail: vertical reading's seek control, and the replacement for
/// the thumbnail strip and its slider (#52).
///
/// The strip and the slider run along the axis the paged directions turn on;
/// vertical reading is scrolled along the other one, so its seek control runs
/// there too — a rail against the right edge of the screen, spanning the
/// chapter from its first page to its last. Where a chapter opens at the top,
/// the handle sits at the top of the rail; scrolled halfway down a page that
/// is a third of the chapter, it sits a third of the way down the rail.
///
/// The mapping is by the pages' **real heights**, which is the whole of the
/// module: every page is given the share of the rail its height has of the
/// chapter, from [StripGeometry] itself, and a seek lands at the top of the
/// page asked for either way — so the proportional map addresses exactly the
/// same set as an even one and loses no granularity. Positions are what the
/// rail draws, and position is the one thing an even map lies about: it would
/// give a page twice as tall as its neighbour the same rail as it. Where the
/// server measured nothing, every page shares the default ratio and the
/// proportional rail collapses into an even one by itself.
///
/// A finger on the rail is a seek: the strip lands on the top of the page
/// under the finger, on the way down and on the way off. The page **number** —
/// the address a seek lands on, nothing more — is drawn while the finger is
/// down and nowhere else, floating a thumb's height clear of the finger that
/// is dragging it; the position the handle would draw is already under the
/// finger, so drawing both at once is drawing the answer twice and the
/// question once.
///
/// The rail is part of the reader's chrome: it is built with it and hidden
/// with it, the same bargain the strip and the slider strike — the seek
/// control is one tap away rather than always on the page. It runs between
/// the top bar and the bottom counter, which is where a control of the
/// readable region belongs; the same insets keep it off the cog's corner on
/// any device, since both it and the chrome measure the safe-area padding the
/// same way — and off a device's own right-edge bar too, since a rail the
/// system overlays is a rail the reading thumb drags under the system's
/// gesture instead. A chapter of one page has nowhere to seek to — that is
/// the caller's rule ([_VerticalScrollViewState] does not build one) — and
/// what happens instead is the counter alone, as it already was.
class PageRail extends StatefulWidget {
  const PageRail({
    super.key,
    required this.geometry,
    required this.controller,
    required this.onSeek,
    required this.seeking,
    required this.topGap,
    required this.bottomGap,
  });

  /// The strip's geometry, at the width it is being drawn at: where every
  /// page starts, how tall it is, and how tall the whole chapter is.
  final StripGeometry geometry;

  /// The strip's own scroll controller: its offset is where the reader
  /// actually is, and the handle is drawn from it. The rail listens to it so
  /// the handle follows a scroll the reader has not been told about yet —
  /// the strip moves within a page long before the reader hears of a page
  /// crossing.
  final ScrollController controller;

  /// Called with the page the seek lands on, off the drag or off a tap.
  ///
  /// A seek lands at the top of the page either way, so the rail never asks
  /// for an offset — the page is the address the rail exists to address.
  final ValueChanged<int> onSeek;

  /// Whether the owner is itself moving the strip: a seek is asked for by
  /// the reader, a width change or a rotation is laid out — either way the
  /// controller is about to be told in the middle of a build, and the rail
  /// must not rebuild itself from there. When [seeking] is true the normal
  /// rule is reversed: the notification is skipped, and the build that
  /// follows the move is trusted to carry where the strip landed.
  final bool Function() seeking;

  /// How far the rail's reachable region starts below the top of the
  /// screen, and ends above the bottom of it, in points — before the
  /// safe-area padding the device adds, which the rail measures itself.
  ///
  /// These are the chrome bars the reader draws above and below the rail;
  /// the caller hands them in rather than the rail restating the bars'
  /// own geometry, which is the reader's to change without asking the rail
  /// to agree with it (the same rule as `ThumbStrip.sliderPadding`).
  final double topGap;
  final double bottomGap;

  /// How wide the rail's own column is, in points: a thumb-sized target
  /// (`minHitTarget`) around the few points of track that are painted. The
  /// track could not be that wide and still read as a line; the column can
  /// be that wide and still read as a button — this is a control, and a
  /// control never scales with the screen.
  static const double hitWidth = 44.0;

  /// The painted track, in points: the thin line the handle runs along.
  static const double trackWidth = 6.0;

  /// The handle, in points along the direction of travel — the Material
  /// slider's thumb on this theme, only painted as a capsule on the track
  /// rather than inset in one.
  static const double handleLength = 26.0;

  /// How far the page number's pill floats from the finger that is dragging
  /// the rail, in points — the nearest edge of the pill to the finger stays
  /// a thumb's width clear of it, and the pill flips to the other side of
  /// the finger near the top of the rail, where there is no room for it to
  /// clear on the near side.
  static const double _fingerClearance = 48.0;

  /// How tall the page number's pill is, to a point: the numerals are 13pt
  /// at the source serif's own line height, plus the padding either side.
  static const double _labelHeight = 13.0 * 1.4 + 6.0;

  @override
  State<PageRail> createState() => _PageRailState();
}

class _PageRailState extends State<PageRail> {
  /// How tall the rail's own reachable region is, from the last layout, in
  /// points: the distance a drag can ask for and a seek can land on. A
  /// pointer's position on the rail is a fraction of this.
  double _trackHeight = 0;

  /// A finger is on the rail. The number is drawn, the handle follows the
  /// finger, and nothing drawn here is "where the reader is" — it is where
  /// the seek would land.
  var _dragging = false;

  /// The page the seek would land on, as the number is drawn: the address
  /// under the finger.
  int _dragPage = 0;

  /// Where the finger is, the last it was known — the handle follows it
  /// while it is down.
  double _dragY = 0;

  /// The pointer with the rail, if any. A second finger landing on the rail
  /// is ignored rather than turned into a second drag: one seek at a time,
  /// which is the paged slider's own rule.
  int? _pointer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScrolled);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScrolled);
    super.dispose();
  }

  /// The strip moved under the reader — a finger on it, a fling, a pinch —
  /// and the handle has to follow. What the rail did not hear about is news;
  /// what the [widget.seeking] owner is doing is not: its move is being
  /// reported from inside a build, and the build that follows carries where
  /// it landed. Reading from outside the rail is what the rail exists for;
  /// writing to itself from inside a build is what this screen has already
  /// died on.
  void _onScrolled() {
    if (widget.seeking() || !mounted) return;
    setState(() {});
  }

  /// Where the handle sits: the fraction of the chapter whose height is
  /// above the top of the viewport, which is what an honest position is.
  ///
  /// At the top of the chapter it is `0` and at the last page's top it is
  /// that page's top over the total — the end of the last page's share of
  /// the rail, so what is below the handle is the page that is being read.
  double _fraction() {
    final geometry = widget.geometry;
    if (geometry.pages == 0 || geometry.total <= 0) return 0;
    return (widget.controller.offset / geometry.total).clamp(0.0, 1.0);
  }

  /// The chapter position under [y] on the rail, from the top of the strip.
  double _documentAt(double y) {
    if (_trackHeight <= 0) return 0;
    return (y / _trackHeight).clamp(0.0, 1.0) * widget.geometry.total;
  }

  /// The seek itself is one question asked twice: where the finger is, and
  /// what page that is.
  void _seekTo(Offset position) {
    final geometry = widget.geometry;
    if (geometry.pages == 0 || _trackHeight <= 0) return;
    final page = geometry.anchorAt(_documentAt(position.dy)).page;
    setState(() {
      _dragY = position.dy;
      _dragPage = page;
    });
    widget.onSeek(page);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _dragging = true;
    _seekTo(event.localPosition);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _seekTo(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) => _end(event.pointer);

  /// A pointer the system took back: a lift the reader did not choose, which
  /// ends the seek all the same — anything else would leave the number on
  /// the rail for a drag nobody owns.
  void _onPointerCancel(PointerCancelEvent event) => _end(event.pointer);

  /// The finger is gone, whichever way: the seek it was aiming is over, the
  /// number goes with it, and the handle goes back to drawing where the
  /// strip actually is.
  void _end(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _dragging = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The bars this rail runs between are the chrome the reader draws, and
    // both it and they measure the device's safe-area padding the same way —
    // the top bar's notch on a phone with one is the top bar's, and the rail
    // clears it wherever it ends up rather than assuming where it is.
    final safe = MediaQuery.paddingOf(context);
    return Positioned(
      top: safe.top + widget.topGap,
      bottom: safe.bottom + widget.bottomGap,
      // The right system inset too. The rail is a control the reader drags,
      // and on a device that runs a bar along the right edge of the screen —
      // a gesture nav or a sidebar, which is where some put it in portrait —
      // a rail flush against that edge is a rail under the bar, and a drag on
      // it is a drag the system sees first. Insetting by [safe.right] tucks
      // it just inside the system's own edge, the same way the top and
      // bottom bars are tucked below and above theirs.
      right: safe.right,
      width: PageRail.hitWidth,
      // Measured here, the [LayoutBuilder]'s one job: a drag is a fraction
      // of the reachable region, and the pointer handlers need the number
      // a layout hands over.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackHeight = math.max(0.0, constraints.maxHeight);
          _trackHeight = trackHeight;
          final dragging = _dragging;
          final fraction = dragging
              ? (trackHeight <= 0
                    ? 0.0
                    : (_dragY / trackHeight).clamp(0.0, 1.0))
              : _fraction();
          final handleCentre = fraction * trackHeight;
          // The number rides with the finger, a thumb's height clear of it:
          // the thumb is what the rail is dragged by, and a number drawn
          // where it is holding is a number it covers. So the pill floats
          // above the finger in the body of the rail, and below it near the
          // top, where there is no room above to clear it. Either way it
          // stays inside the reachable region.
          final labelTop = dragging
              ? (_dragY < PageRail._fingerClearance + PageRail._labelHeight
                    ? _dragY + PageRail._fingerClearance
                    : _dragY -
                          PageRail._fingerClearance -
                          PageRail._labelHeight)
                    .clamp(0.0, math.max(0.0, trackHeight - PageRail._labelHeight))
                    .toDouble()
              : 0.0;
          return Listener(
            // Opaque and not translucent, so the rail owns its pointer
            // outright: a finger on the rail is a seek, and the strip's
            // scroll and the chrome's tap are not also listening for it.
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: Stack(
              fit: StackFit.expand,
              // The handle is allowed out of its ends — at the top of the
              // chapter and on the last page it is centred on the very edge
              // of the rail and must keep its whole length visible.
              clipBehavior: Clip.none,
              children: [
                // The track: a scrim the page can hold against, which is the
                // same bargain the reader's chrome strikes with near-white
                // pages. It is black so it reads on a paper page and simply
                // disappears on the black canvas, where the handle behind it
                // is what is being looked for anyway.
                Positioned(
                  left: (PageRail.hitWidth - PageRail.trackWidth) / 2,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: PageRail.trackWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(radiusPill),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                // The handle: where the fraction of the chapter above the
                // top of the viewport puts it. Reading progress, which is
                // what patraAccent is for and what the paged directions'
                // slider thumb is already drawn in.
                Positioned(
                  top: handleCentre - PageRail.handleLength / 2,
                  child: SizedBox(
                    key: const ValueKey('pageRailHandle'),
                    width: PageRail.trackWidth,
                    height: PageRail.handleLength,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: patraAccent,
                        borderRadius: BorderRadius.circular(radiusPill),
                      ),
                    ),
                  ),
                ),
                // The number, while a finger is on the rail and not
                // otherwise: the address the seek would land on, drawn in
                // the voice of every other page numeral on the screen.
                if (dragging) ...[
                  Positioned(
                    top: labelTop,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(radiusPill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          '${_dragPage + 1}',
                          style: PatraText.pageNumeral(),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
