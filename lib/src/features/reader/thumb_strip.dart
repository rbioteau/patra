import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Decides *when* a thumbnail may start loading, and in which order.
///
/// A chapter strip is a few hundred pages wide; letting every mounted
/// thumbnail hit the server as soon as it is built fires a dozen requests per
/// flick of the strip. This queue holds them back for [startDelay], then feeds
/// them at most [maxConcurrent] at a time, nearest the page being read first:
/// current, previous, next, and outwards from there.
///
/// [maxConcurrent] is the whole throttle, so it sets how fast the strip fills:
/// four is a self-hosted server's worth of parallelism and still leaves plenty
/// of room under `flutter_cache_manager`'s own ten-fetch ceiling, which the
/// full-size pages share.
///
/// Once nothing on screen is left to fetch it keeps going through the rest of
/// the chapter, one page at a time — see [_backfillConcurrent]. Measured
/// against a real server, a thumbnail costs ~200 ms to fetch and ~2 ms to read
/// back from the cache, so a chapter that has been walked through once scrubs
/// instantly the next time.
class ThumbLoadQueue {
  ThumbLoadQueue({
    required this.load,
    this.startDelay = const Duration(milliseconds: 180),
    this.maxConcurrent = 4,
  });

  /// Fetches one thumbnail; completes however it ends, success or failure.
  final Future<void> Function(int page) load;
  final Duration startDelay;
  final int maxConcurrent;

  /// Called whenever a thumbnail becomes ready to show.
  VoidCallback? onChanged;

  final _done = <int>{};
  final _inFlight = <int>{};

  /// Whether a fetch for this chapter has already come back.
  ///
  /// The first one goes through the door **alone**. Kavita's
  /// `/api/Reader/thumbnail` does not render one thumbnail: on the first
  /// request for a chapter it renders *every* page's, inside that request,
  /// before answering (`ReaderService.GetThumbnail`). It decides it is the
  /// first by testing whether the chapter's output directory exists — and
  /// nothing creates that directory until the first thumbnail is written to
  /// it. So there is no lock: every request that leaves before that write
  /// lands takes the same branch, and a server handed four at once generates
  /// the whole chapter four times over, the four fighting for the same CPU,
  /// while later arrivals list a half-filled directory. One request pays for
  /// the chapter; every one after it is a directory listing.
  var _warm = false;

  /// [maxConcurrent] once the chapter is warm, one until then.
  int get _concurrency => _warm ? maxConcurrent : 1;

  /// How many fetches may be in flight for pages nobody is looking at yet.
  ///
  /// One, and only while nothing on screen is outstanding: the strip is
  /// already usable by then, and every one of these costs the server real CPU.
  /// It is a way to spend an idle scrubber, never a reason to make a visible
  /// thumbnail wait.
  static const _backfillConcurrent = 1;

  Set<int> _wanted = const {};

  /// Pages in the chapter — the range the backfill walks. Zero until the strip
  /// has reported one, so a queue nobody has opened fetches nothing.
  int _pages = 0;
  int _current = 0;
  Timer? _timer;
  var _disposed = false;

  /// A thumbnail that has had its turn: its image is in the cache, so building
  /// it now costs nothing.
  bool isReady(int page) => _done.contains(page);

  /// The pages on screen, and the page being read. Safe to call on every
  /// scroll frame.
  void update({
    required Set<int> visible,
    required int current,
    required int pages,
  }) {
    _wanted = Set.of(visible);
    _current = current;
    _pages = pages;
    // While something is in flight the queue is already draining, and it
    // re-reads this state on every completion — restarting the delay there
    // would stall the strip for as long as a finger keeps moving.
    if (_inFlight.isNotEmpty || _disposed) return;
    // The delay must run from the *first* sign of interest, never be pushed
    // back by the next one: this is called on every scroll frame, and a
    // cancel-and-reschedule here means a fling — or the 200 ms glide the strip
    // makes on every page turn — leaves the queue with nothing started until
    // the strip has come to a complete stop. What keeps a flick from flooding
    // the server is [maxConcurrent], not this delay; the delay only spares the
    // pages that whip past before anything can be fetched, and _pump reads the
    // window as it is when it fires, not as it was when it was scheduled.
    if (_timer?.isActive ?? false) return;
    _timer = Timer(startDelay, _pump);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  void _pump() {
    if (_disposed) return;
    while (true) {
      // What is on screen comes first, at full concurrency. Only once none of
      // it is outstanding does the rest of the chapter get a turn, and then
      // one at a time — which also means a single backfill in flight is the
      // most a scroll can ever have to wait behind.
      var limit = _concurrency;
      var page = _nextPage(_wanted);
      if (page == null) {
        limit = _backfillConcurrent;
        page = _nextPage(Iterable<int>.generate(_pages));
      }
      if (page == null || _inFlight.length >= limit) return;
      _start(page);
    }
  }

  void _start(int page) {
    _inFlight.add(page);
    // A thumbnail that fails must not take the queue down with it.
    load(page).catchError((Object _) {}).whenComplete(() {
      _inFlight.remove(page);
      // However it ended, the chapter has been rendered or there is no
      // server to render it: nothing is gained by holding the rest back.
      _warm = true;
      // Marked done even when it failed: a page whose thumbnail 404s must
      // not be retried forever, and the image widget shows its own fallback.
      _done.add(page);
      if (_disposed) return;
      // A backfilled page needs no repaint: it is off screen, and scrolling to
      // it rebuilds that row anyway. Repainting on each would redraw the strip
      // a couple of times a second for the length of a chapter.
      if (_wanted.contains(page)) onChanged?.call();
      _pump();
    });
  }

  /// Current page first, then the one before, then the one after, and outwards.
  int? _nextPage(Iterable<int> candidates) {
    int? best;
    var bestRank = 0;
    for (final page in candidates) {
      if (_done.contains(page) || _inFlight.contains(page)) continue;
      final delta = page - _current;
      final rank = delta.abs() * 2 + (delta > 0 ? 1 : 0);
      if (best == null || rank < bestRank) {
        best = page;
        bestRank = rank;
      }
    }
    return best;
  }
}

// --- the strip's geometry ----------------------------------------------------
//
// The handoff drew a 34x48 thumbnail. On a real device that is a stamp: this
// strip is not read, it is *aimed at*, and a page you cannot recognise is a
// page you cannot scrub to. So the thumbnails are drawn at twice the handoff's
// size on a phone and [_tabletScale] again on a tablet, while the strip's own
// margins stay where they were — the extra height goes into the pictures.
const _phoneBaseWidth = 68.0;
const _phoneBaseHeight = 96.0;
const _phoneNearWidth = 80.0;
const _phoneNearHeight = 112.0;
const _phoneCurrentWidth = 92.0;
const _phoneCurrentHeight = 128.0;
const _phoneGap = 8.0;
const _phoneHPadding = 12.0;
const _phoneVPadding = 6.0;
const _tabletScale = 1.35;

/// Every length in the strip is the phone's, taken through this: a tablet gets
/// the same strip drawn larger, so the accordion's law is untouched and only
/// the numbers change.
double _scaleFor(BuildContext context) =>
    isTabletLayout(context) ? _tabletScale : 1;

/// How far inside the strip Material sets a `Slider`'s handle at either end of
/// its track, measured against this theme rather than assumed. The strip's own
/// end centres are further in than that, so the slider is padded by the
/// difference — see [ThumbStrip.sliderPadding].
const _sliderThumbInset = 26.0;

/// The reader's page scrubber: one thumbnail per page, the current one swollen
/// and its two neighbours halfway there.
///
/// Sizes are keyed to the page being read, not to the middle of the strip, so
/// the accordion stays put while the strip is scrolled and only moves when the
/// reader turns a page.
class ThumbStrip extends StatefulWidget {
  const ThumbStrip({
    super.key,
    required this.pages,
    required this.current,
    required this.queue,
    required this.providerBuilder,
    required this.onTap,
  });

  final int pages;
  final int current;

  /// Owned by the reader, not by the strip: it outlives the chrome being
  /// hidden, so what it has already fetched is still fetched when the scrubber
  /// comes back, and its backfill keeps going while the chapter is being read.
  final ThumbLoadQueue queue;

  /// The thumbnail image for a page, or null when there is no way to load it
  /// (signed out mid-read).
  final ImageProvider? Function(int page) providerBuilder;
  final ValueChanged<int> onTap;

  /// The width of the swollen thumbnail on this screen. The reader decodes its
  /// thumbnails to it: a picture decoded at a third of the size it is drawn at
  /// is the blur this strip exists to avoid.
  static double thumbWidth(BuildContext context) =>
      _phoneCurrentWidth * _scaleFor(context);

  /// Where the first and last thumbnail centres sit, in from the strip's edge:
  /// half a swollen thumbnail past the padding.
  static double edgeInset(BuildContext context) =>
      (_phoneHPadding + _phoneCurrentWidth / 2) * _scaleFor(context);

  /// The horizontal padding the slider under the strip must be given so its
  /// handle starts and ends exactly where the bulge does.
  ///
  /// The two are the chrome's only "you are here" markers and they sit one
  /// above the other, so they must agree at the ends as well as in the middle
  /// — and the bulge's ends move whenever the thumbnails change size, which is
  /// what makes this a computation rather than a number.
  static double sliderPadding(BuildContext context) {
    final inset = edgeInset(context) - _sliderThumbInset;
    return inset < 0 ? 0 : inset;
  }

  @override
  State<ThumbStrip> createState() => _ThumbStripState();
}

class _ThumbStripState extends State<ThumbStrip> {
  static const _grow = Duration(milliseconds: 200);

  /// Read in [didChangeDependencies], not in the getters below: those are
  /// called from scroll callbacks, where an inherited-widget lookup has no
  /// business being.
  double _scale = 1;

  double get _baseWidth => _phoneBaseWidth * _scale;
  double get _baseHeight => _phoneBaseHeight * _scale;
  double get _nearWidth => _phoneNearWidth * _scale;
  double get _nearHeight => _phoneNearHeight * _scale;
  double get _currentWidth => _phoneCurrentWidth * _scale;
  double get _currentHeight => _phoneCurrentHeight * _scale;
  double get _gap => _phoneGap * _scale;
  double get _hPadding => _phoneHPadding * _scale;
  double get _vPadding => _phoneVPadding * _scale;

  /// The closest two centres may come before the current thumbnail and its
  /// neighbour lose their gap.
  double get _minStep => (_currentWidth + _nearWidth) / 2 + _gap;

  final _controller = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scale = _scaleFor(context);
  }

  @override
  void initState() {
    super.initState();
    widget.queue.onChanged = () {
      if (mounted) setState(() {});
    };
    _controller.addListener(_syncQueue);
    // The chrome usually opens mid-chapter: jump to where the reader is
    // rather than showing page one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealCurrent(animate: false);
      _syncQueue();
    });
  }

  @override
  void didUpdateWidget(ThumbStrip old) {
    super.didUpdateWidget(old);
    if (widget.current == old.current) return;
    // The extents around the current page have just changed; centre on them
    // once this frame's layout is in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealCurrent();
      _syncQueue();
    });
  }

  @override
  void dispose() {
    // The queue outlives us; only the repaint hook was ours. It goes on
    // fetching, which is the point.
    widget.queue.onChanged = null;
    _controller.dispose();
    super.dispose();
  }

  /// The pages on screen, give or take one at each end — close enough to
  /// decide what is worth fetching, and it costs no layout pass.
  void _syncQueue() {
    if (!_controller.hasClients) return;
    final step = _baseWidth + _gap;
    final offset = _controller.offset - _hPadding;
    final last = widget.pages - 1;
    final first = ((offset / step).floor() - 1).clamp(0, last);
    final end =
        (((offset + _controller.position.viewportDimension) / step).ceil())
            .clamp(0, last);
    widget.queue.update(
      visible: {for (var page = first; page <= end; page++) page},
      current: widget.current,
      pages: widget.pages,
    );
  }

  // --- accordion geometry ---------------------------------------------------

  double _width(int page) => switch ((page - widget.current).abs()) {
    0 => _currentWidth,
    1 => _nearWidth,
    _ => _baseWidth,
  };

  double _height(int page) => switch ((page - widget.current).abs()) {
    0 => _currentHeight,
    1 => _nearHeight,
    _ => _baseHeight,
  };

  /// Distance between thumbnail centres when the whole chapter fits on screen:
  /// the strip cannot scroll, so the thumbnails themselves spread out to land
  /// under the handle for their page. Null when the strip scrolls instead, or
  /// when spreading would leave the two widest thumbnails touching.
  double? _spread(double viewport) {
    if (widget.pages < 2) return null;
    final step =
        (viewport - _hPadding * 2 - _currentWidth) / (widget.pages - 1);
    return step >= _minStep ? step : null;
  }

  /// Even centres, uneven widths: what is left between two thumbnails is what
  /// the accordion is not using.
  double _gapAfter(int page, double? spread) =>
      spread == null ? _gap : spread - (_width(page) + _width(page + 1)) / 2;

  /// The first and last centres sit where the handle's travel starts and ends
  /// — half a *current* thumbnail in from each edge, whatever those pages
  /// currently measure.
  EdgeInsetsDirectional _padding(double? spread, double viewport) {
    if (widget.pages == 1) {
      final side = (viewport - _currentWidth) / 2;
      return EdgeInsetsDirectional.fromSTEB(side, _vPadding, side, _vPadding);
    }
    if (spread == null) {
      return EdgeInsetsDirectional.fromSTEB(
        _hPadding,
        _vPadding,
        _hPadding,
        _vPadding,
      );
    }
    return EdgeInsetsDirectional.fromSTEB(
      _hPadding + (_currentWidth - _width(0)) / 2,
      _vPadding,
      _hPadding + (_currentWidth - _width(widget.pages - 1)) / 2,
      _vPadding,
    );
  }

  /// Where [page] starts along the strip. Only three pages are ever wider than
  /// the base, so the sum is a correction, not a walk over the chapter.
  double _leadingEdge(int page) {
    var x = page * (_baseWidth + _gap);
    for (final swollen in [
      widget.current - 1,
      widget.current,
      widget.current + 1,
    ]) {
      if (swollen >= 0 && swollen < page) x += _width(swollen) - _baseWidth;
    }
    return x;
  }

  /// Puts the swollen thumbnail where the slider's handle is.
  ///
  /// Centring the current page instead would give the chrome two "you are
  /// here" markers pointing at different places — at page 12 of 40 the handle
  /// sits at a third of the width while the accordion sits dead centre. So the
  /// current thumbnail's centre travels across the strip on the same law as the
  /// handle travels across its track: from one inset edge to the other, linear
  /// in page / (pages - 1). It falls out exactly at both ends — offset 0 on the
  /// first page, the end of the scroll on the last.
  void _revealCurrent({bool animate = true}) {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    // Spread out, every page is already under its own handle position.
    if (_spread(viewport) != null) return;
    // Measured from the strip's own geometry rather than from
    // maxScrollExtent, which is mid-animation while the accordion opens.
    final content = _leadingEdge(widget.pages) - _gap + _hPadding * 2;
    final fraction = widget.pages > 1
        ? widget.current / (widget.pages - 1)
        : 0.0;
    final travel = viewport - _hPadding * 2 - _width(widget.current);
    final target = _leadingEdge(widget.current) - fraction * travel;
    final offset = target.clamp(0.0, (content - viewport).clamp(0.0, content));
    if (!animate) {
      _controller.jumpTo(offset);
      return;
    }
    _controller.animateTo(offset, duration: _grow, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _currentHeight + _vPadding * 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spread = _spread(constraints.maxWidth);
          return ListView.custom(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            // Spread out, the content is exactly the viewport: any scroll is
            // rounding error, and dragging it would only unstick the strip
            // from the slider.
            physics: spread == null
                ? null
                : const NeverScrollableScrollPhysics(),
            padding: _padding(spread, constraints.maxWidth),
            childrenDelegate: _StripDelegate(
              childCount: widget.pages,
              // What the whole strip measures, which the strip knows exactly.
              // A lazy list otherwise averages the children it has built and
              // applies that to the rest — and three of these are half again
              // as wide as the others, so the guess is wrong by tens of points
              // and the scroll to the last page stops short of it, leaving the
              // bulge behind the slider's handle. It is also steady while the
              // accordion animates, which the guess is not.
              extent: _leadingEdge(widget.pages) - _gap,
              builder: (context, page) {
                final selected = page == widget.current;
                final provider = widget.queue.isReady(page)
                    ? widget.providerBuilder(page)
                    : null;
                return Row(
                  children: [
                    Align(
                      // The strip is centred on its tallest thumbnail, so the
                      // accordion opens both ways.
                      alignment: Alignment.center,
                      widthFactor: 1,
                      child: GestureDetector(
                        onTap: () => widget.onTap(page),
                        child: AnimatedContainer(
                          key: ValueKey(page),
                          duration: _grow,
                          curve: Curves.easeOut,
                          width: _width(page),
                          height: _height(page),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(radiusThumb),
                            border: Border.all(
                              color: selected ? patraAccent : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              radiusThumb - 1,
                            ),
                            // Until the queue has had its turn the thumbnail is
                            // just its frame: no request, nothing to shuffle
                            // around.
                            child: provider == null
                                ? const SizedBox.shrink()
                                : Image(
                                    image: provider,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    // The gap travels with the thumbnail before it: one child
                    // per page is what lets the delegate below state the
                    // strip's extent exactly.
                    if (page < widget.pages - 1)
                      AnimatedContainer(
                        duration: _grow,
                        curve: Curves.easeOut,
                        width: _gapAfter(page, spread),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// A list delegate that knows what its children measure instead of guessing.
class _StripDelegate extends SliverChildBuilderDelegate {
  _StripDelegate({
    required NullableIndexedWidgetBuilder builder,
    required int childCount,
    required this.extent,
  }) : super(builder, childCount: childCount);

  /// The strip's whole length, padding aside.
  final double extent;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => extent;
}
