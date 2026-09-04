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
// Every length here is a **share of the screen's shortest side**, not a size in
// points. The shortest side, so that a phone gets the same thumbnail in either
// orientation — a page is the same thing to recognise whichever way the device
// is held — and a share, because that is what the strip actually trades away:
// the swollen thumbnail's width comes out of the slider's track (see
// [ThumbStrip.sliderPadding]) and out of how many pages fit either side of it,
// so a size only means something against the screen it is drawn on. The point
// values in the comments are what each share comes to on the 390pt phone the
// handoff was drawn for.
//
// The handoff drew a 34x48 thumbnail. On a real device that is a stamp: this
// strip is not read, it is *aimed at*, and a page you cannot recognise is a
// page you cannot scrub to. So the base is twice that, and **the swollen one is
// a third of the screen** — which is as wide as it can be drawn before the
// slider under it stops reading as a slider: its track is the screen less the
// swollen thumbnail, and at half the screen the two markers are a short bar
// floating between two wide margins. That third leaves about four pages on
// screen and a track at 61% of the width.
//
// Only widths are shares. Heights follow from [_pageAspect], so a thumbnail is
// never drawn out of shape, and the accordion's law — neighbours halfway
// between the swollen one and the base — is arithmetic on the shares rather
// than three numbers that can drift apart.
const _baseShare = 0.174; // 68pt
const _currentShare = 0.33; // 129pt, a third of the screen
const _nearShare = (_baseShare + _currentShare) / 2; // 98pt, halfway
const _gapShare = 0.021; // 8pt
const _hPaddingShare = 0.031; // 12pt
const _vPaddingShare = 0.015; // 6pt

/// A page is taller than it is wide by this much: the handoff's 34x48
/// thumbnail, which is about every manga and comic page's proportion.
const _pageAspect = 48 / 34;

/// What a tablet takes of the shares above — of its own shortest side, which
/// is twice a phone's.
///
/// A tablet is not a big phone. A third of an iPad's 820pt would be a 270pt
/// thumbnail with the same four pages beside it that a phone shows, which is
/// the mistake the rest of this app avoids by taking another column rather than
/// drawing a bigger card. Two thirds of the share puts the thumbnail one step
/// up from the phone's — 173pt, the same step the strip used to take at 1.35 —
/// and spends the width it did not take on pages.
const _tabletShareFactor = 0.64;

/// What the chrome is besides the strip: 28pt of padding above it, the slider,
/// the page numeral, and 8pt under that — see `_ReaderChrome`. In points, not
/// shares, because a slider and a line of type are the same size on every
/// screen. The strip cares about it because of [_heightBudget].
const _chromeAroundStrip = 104.0;

/// Room left between the chrome and the middle of the screen: a finger's
/// worth, and enough to cover the home indicator under the chrome, which the
/// strip cannot read from where it sits — a `SafeArea` takes what it consumes
/// out of `viewPadding` as well as out of `padding`.
const _chromeClearance = 24.0;

/// The tallest the strip may be drawn, thumbnails and margins together.
///
/// The reader's middle third toggles the chrome, so **the chrome has to stop
/// short of the middle of the screen**: where it reaches past it, the tap that
/// would dismiss it lands on the scrubber instead and seeks to whatever page is
/// under the finger, which is worse than nothing happening. That is a limit in
/// points rather than a share, because what sits below the strip is.
///
/// It leaves every phone and tablet in portrait the shares whole, and an iPad
/// on its side too. What it catches is a phone on its side — which is where a
/// spread is read, so the scrubber has to open there — and a short widget-test
/// surface.
double _heightBudget(BuildContext context) =>
    MediaQuery.sizeOf(context).height / 2 -
    _chromeAroundStrip -
    _chromeClearance;

/// The share of the screen the whole strip stands on: the swollen thumbnail
/// plus the margins above and below it.
const _stripHeightShare = _currentShare * _pageAspect + _vPaddingShare * 2;

/// The smallest fraction of the shares the strip is ever drawn at, which is
/// where the swollen thumbnail comes back to the 92pt it was before it was
/// given a third of the screen — the size a phone on its side has always shown.
///
/// No size worth drawing keeps the chrome clear of the middle of a screen that
/// short: that was already lost at the old sizes, whose chrome took 63% of a
/// landscape phone. So the strip there keeps what it had rather than shrinking
/// to the stamp [_heightBudget] would allow.
const _shortScreenFloor = 0.71;

/// What one full share of the screen comes to in points.
///
/// Every length in the strip is a share taken through this, so the accordion's
/// law is untouched and only the numbers change: a tablet draws the same strip
/// one step larger, and a screen with no room for the result brings every
/// length down together.
double _unitFor(BuildContext context) {
  final short = MediaQuery.sizeOf(context).shortestSide;
  final unit = isTabletLayout(context) ? short * _tabletShareFactor : short;
  final fits = _heightBudget(context) / (_stripHeightShare * unit);
  return unit * fits.clamp(_shortScreenFloor, 1.0);
}

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
      _currentShare * _unitFor(context);

  /// Where the first and last thumbnail centres sit, in from the strip's edge:
  /// half a swollen thumbnail past the padding.
  static double edgeInset(BuildContext context) =>
      (_hPaddingShare + _currentShare / 2) * _unitFor(context);

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

class _ThumbStripState extends State<ThumbStrip> with TickerProviderStateMixin {
  static const _grow = Duration(milliseconds: 200);

  /// Read in [didChangeDependencies], not in the getters below: some of them
  /// are called from animation ticks, where an inherited-widget lookup has no
  /// business being.
  double _unit = 0;

  double get _baseWidth => _baseShare * _unit;
  double get _nearWidth => _nearShare * _unit;
  double get _currentWidth => _currentShare * _unit;
  double get _currentHeight => _currentWidth * _pageAspect;
  double get _gap => _gapShare * _unit;
  double get _hPadding => _hPaddingShare * _unit;
  double get _vPadding => _vPaddingShare * _unit;

  /// The closest two centres may come before the current thumbnail and its
  /// neighbour lose their gap.
  double get _minStep => (_currentWidth + _nearWidth) / 2 + _gap;

  /// The accordion, as one clock.
  ///
  /// Everything the strip draws is a function of this animation and the two
  /// pages it runs between — the widths, the heights, and **where the strip is
  /// scrolled to**. The sizes and the offset used to be animated apart, and
  /// measured on a phone that left the swollen thumbnail 123pt from the
  /// slider's handle, a third of the screen, for the length of every page turn.
  late final AnimationController _accordion = AnimationController(
    duration: _grow,
    vsync: this,
    value: 1,
  );
  late final Animation<double> _turn = CurvedAnimation(
    parent: _accordion,
    curve: Curves.easeOut,
  );

  /// The two pages the accordion is between: the one it is leaving and the one
  /// it is arriving at. Equal to each other, and to [ThumbStrip.current],
  /// whenever the strip is at rest.
  late int _from = widget.current;
  late int _to = widget.current;

  double _lerp(double from, double to) => from + (to - from) * _turn.value;

  /// Where the strip is scrolled to when a finger has put it somewhere, rather
  /// than the page being read. Null while it follows the reader, which is what
  /// it goes back to the moment the page changes.
  double? _dragged;

  /// A flick's momentum, run through an unbounded controller so the offset it
  /// produces is read the same way as everything else here: in [build].
  late final AnimationController _fling = AnimationController.unbounded(
    vsync: this,
  );

  /// The last viewport the strip was built at, so a drag has something to clamp
  /// against outside of layout. Zero until the first build.
  double _viewport = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unit = _unitFor(context);
  }

  @override
  void initState() {
    super.initState();
    widget.queue.onChanged = () {
      if (mounted) setState(() {});
    };
    _fling.addListener(_onFling);
  }

  @override
  void didUpdateWidget(ThumbStrip old) {
    super.didUpdateWidget(old);
    if (widget.current == old.current) return;
    // Straight into the build that delivered it. There is nothing here to
    // schedule or defer any more: the offset is not a scroll position being
    // commanded, it is a number this widget draws with, so moving the
    // accordion is an ordinary rebuild in whatever phase the page arrived.
    final glide = !_accordion.isAnimating && (widget.current - _to).abs() == 1;
    _from = glide ? _to : widget.current;
    _to = widget.current;
    // The reader has moved: the strip goes back to following it, and any flick
    // still running is over.
    _dragged = null;
    _fling.stop();
    if (glide) {
      _accordion.forward(from: 0);
    } else {
      _accordion.value = 1;
    }
  }

  @override
  void dispose() {
    // The queue outlives us; only the repaint hook was ours. It goes on
    // fetching, which is the point.
    widget.queue.onChanged = null;
    _accordion.dispose();
    _fling.dispose();
    super.dispose();
  }

  // --- accordion geometry ---------------------------------------------------

  /// The pages the accordion is drawing wider than the base: the three around
  /// the page being read, and the three around the one it is leaving while the
  /// two are being interpolated.
  Iterable<int> get _swollen => {
    for (final centre in {_from, _to})
      for (var page = centre - 1; page <= centre + 1; page++)
        if (page >= 0 && page < widget.pages) page,
  };

  /// What the accordion adds to the strip's length, over the base thumbnails
  /// the swollen ones stand in for.
  double get _swell =>
      _swollen.fold(0.0, (sum, page) => sum + _width(page) - _baseWidth);

  double _widthAt(int page, int current) => switch ((page - current).abs()) {
    0 => _currentWidth,
    1 => _nearWidth,
    _ => _baseWidth,
  };

  double _width(int page) => _lerp(_widthAt(page, _from), _widthAt(page, _to));

  double _height(int page) => _width(page) * _pageAspect;

  /// Where [page] starts along the strip's whole length. Only the pages the
  /// accordion is touching are wider than the base, so the sum is a
  /// correction, not a walk over the chapter.
  double _leadingEdge(int page) {
    var x = page * (_baseWidth + _gap);
    for (final swollen in _swollen) {
      if (swollen < page) x += _width(swollen) - _baseWidth;
    }
    return x;
  }

  /// The strip's whole length, the padding at both ends included.
  double _content() => _leadingEdge(widget.pages) - _gap + _hPadding * 2;

  /// How far the strip can be scrolled at this width.
  double _maxOffset(double viewport) {
    final max = _content() - viewport;
    return max < 0 ? 0 : max;
  }

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

  /// Where the strip sits: under the finger if one has moved it, otherwise
  /// wherever puts the swollen thumbnail under the slider's handle.
  ///
  /// Centring the current page instead would give the chrome two "you are
  /// here" markers pointing at different places — at page 12 of 40 the handle
  /// sits at a third of the width while the accordion sits dead centre. So the
  /// current thumbnail's centre travels across the strip on the same law as the
  /// handle travels across its track: from one inset edge to the other, linear
  /// in page / (pages - 1). It falls out exactly at both ends — offset 0 on the
  /// first page, the end of the strip on the last.
  ///
  /// It is computed from the widths being drawn in the same breath, which is
  /// what keeps the bulge under the handle at every frame of the accordion
  /// rather than only once it has settled.
  double _offset(double viewport) {
    final dragged = _dragged;
    if (dragged != null) return dragged.clamp(0.0, _maxOffset(viewport));
    final last = widget.pages - 1;
    if (last <= 0) return 0;
    final fraction = _lerp(_from / last, _to / last);
    final travel = viewport - _hPadding * 2 - _currentWidth;
    final target =
        _leadingEdge(_to) +
        (_width(_to) - _currentWidth) / 2 -
        fraction * travel;
    return target.clamp(0.0, _maxOffset(viewport));
  }

  /// Where [page]'s centre sits across the strip.
  double _centre(int page, double viewport, double? spread, double offset) {
    if (widget.pages == 1) return viewport / 2;
    // Spread out, every page is put under its own handle position directly —
    // the same law the offset above follows when the strip scrolls instead.
    if (spread != null) {
      final inset = _hPadding + _currentWidth / 2;
      return inset + (viewport - inset * 2) * page / (widget.pages - 1);
    }
    return _hPadding + _leadingEdge(page) + _width(page) / 2 - offset;
  }

  /// The pages inside the viewport, one either side for luck.
  ///
  /// Exact rather than estimated, which is what the strip drawing itself makes
  /// possible: it is also the window handed to the loader, so nothing is
  /// fetched for a page nobody can see.
  (int, int) _window(double offset, double viewport) {
    final last = widget.pages - 1;
    if (last <= 0) return (0, 0);
    final step = _baseWidth + _gap;
    // A page sits at least this far along, so the walk below starts at or
    // before the first one on screen and takes a handful of steps at most.
    var first = (((offset - _swell) / step).floor() - 1).clamp(0, last);
    while (first < last && _leadingEdge(first + 1) + _hPadding < offset) {
      first++;
    }
    var end = first;
    while (end < last &&
        _leadingEdge(end + 1) + _hPadding <= offset + viewport) {
      end++;
    }
    return (first, end);
  }

  // --- dragging -------------------------------------------------------------

  void _onDragStart(DragStartDetails _) {
    _fling.stop();
    _dragged = _offset(_viewport);
  }

  void _onDragUpdate(DragUpdateDetails details, double sign) {
    setState(() {
      _dragged = ((_dragged ?? _offset(_viewport)) - details.delta.dx * sign)
          .clamp(0.0, _maxOffset(_viewport));
    });
  }

  void _onDragEnd(DragEndDetails details, double sign) {
    final velocity = -details.velocity.pixelsPerSecond.dx * sign;
    final from = _dragged ?? _offset(_viewport);
    if (velocity.abs() < 50) return;
    _fling
      ..value = from
      ..animateWith(
        ClampingScrollSimulation(position: from, velocity: velocity),
      );
  }

  void _onFling() {
    final max = _maxOffset(_viewport);
    final offset = _fling.value.clamp(0.0, max);
    if (offset != _fling.value) _fling.stop();
    setState(() => _dragged = offset);
  }

  // --- loading --------------------------------------------------------------

  /// Tells the loader what is on screen. Called from [build], because that is
  /// where the strip works out what it is drawing; the queue only writes down
  /// what it is given and arms a timer, so there is nothing here that a build
  /// may not do.
  void _report(int first, int end) {
    widget.queue.update(
      visible: {for (var page = first; page <= end; page++) page},
      current: widget.current,
      pages: widget.pages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // A drag mirrors with the strip; the geometry above is all measured from
    // the leading edge, whichever edge that is.
    final sign = rtl ? -1.0 : 1.0;
    final height = _currentHeight + _vPadding * 2;
    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.maxWidth;
            _viewport = viewport;
            final spread = _spread(viewport);
            final offset = spread == null ? _offset(viewport) : 0.0;
            final (first, end) = spread == null
                ? _window(offset, viewport)
                : (0, widget.pages - 1);
            _report(first, end);
            return GestureDetector(
              // A chapter that fits cannot be scrolled: every page is already
              // under its own handle position, and dragging would only unstick
              // the strip from the slider.
              onHorizontalDragStart: spread == null ? _onDragStart : null,
              onHorizontalDragUpdate: spread == null
                  ? (details) => _onDragUpdate(details, sign)
                  : null,
              onHorizontalDragEnd: spread == null
                  ? (details) => _onDragEnd(details, sign)
                  : null,
              child: ClipRect(
                child: Stack(
                  children: [
                    for (var page = first; page <= end; page++)
                      PositionedDirectional(
                        start:
                            _centre(page, viewport, spread, offset) -
                            _width(page) / 2,
                        // The strip is centred on its tallest thumbnail, so the
                        // accordion opens both ways.
                        top: (height - _height(page)) / 2,
                        width: _width(page),
                        height: _height(page),
                        child: _Thumb(
                          key: ValueKey(page),
                          selected: page == _to,
                          provider: widget.queue.isReady(page)
                              ? widget.providerBuilder(page)
                              : null,
                          onTap: () => widget.onTap(page),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One page of the strip: its frame, and its picture once the loader has had
/// its turn.
class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.selected,
    required this.provider,
    required this.onTap,
  });

  final bool selected;
  final ImageProvider? provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(radiusThumb),
          border: Border.all(
            color: selected ? patraAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radiusThumb - 1),
          // Until the queue has had its turn the thumbnail is just its frame:
          // no request, nothing to shuffle around.
          child: provider == null
              ? const SizedBox.shrink()
              : Image(
                  image: provider!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}
