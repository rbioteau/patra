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
class ThumbLoadQueue {
  ThumbLoadQueue({
    required this.load,
    this.startDelay = const Duration(milliseconds: 180),
    this.maxConcurrent = 2,
  });

  /// Fetches one thumbnail; completes however it ends, success or failure.
  final Future<void> Function(int page) load;
  final Duration startDelay;
  final int maxConcurrent;

  /// Called whenever a thumbnail becomes ready to show.
  VoidCallback? onChanged;

  final _done = <int>{};
  final _inFlight = <int>{};
  Set<int> _wanted = const {};
  int _current = 0;
  Timer? _timer;
  var _disposed = false;

  /// A thumbnail that has had its turn: its image is in the cache, so building
  /// it now costs nothing.
  bool isReady(int page) => _done.contains(page);

  /// The pages on screen, and the page being read. Safe to call on every
  /// scroll frame.
  void update({required Set<int> visible, required int current}) {
    _wanted = Set.of(visible);
    _current = current;
    // While something is in flight the queue is already draining, and it
    // re-reads this state on every completion — restarting the delay there
    // would stall the strip for as long as a finger keeps moving.
    if (_inFlight.isNotEmpty || _disposed) return;
    _timer?.cancel();
    _timer = Timer(startDelay, _pump);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  void _pump() {
    if (_disposed) return;
    while (_inFlight.length < maxConcurrent) {
      final page = _nextPage();
      if (page == null) return;
      _inFlight.add(page);
      // A thumbnail that fails must not take the queue down with it.
      load(page).catchError((Object _) {}).whenComplete(() {
        _inFlight.remove(page);
        // Marked done even when it failed: a page whose thumbnail 404s must
        // not be retried forever, and the image widget shows its own fallback.
        _done.add(page);
        if (_disposed) return;
        onChanged?.call();
        _pump();
      });
    }
  }

  /// Current page first, then the one before, then the one after, and outwards.
  int? _nextPage() {
    int? best;
    var bestRank = 0;
    for (final page in _wanted) {
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
    required this.providerBuilder,
    required this.onTap,
  });

  final int pages;
  final int current;

  /// The thumbnail image for a page, or null when there is no way to load it
  /// (signed out mid-read).
  final ImageProvider? Function(int page) providerBuilder;
  final ValueChanged<int> onTap;

  @override
  State<ThumbStrip> createState() => _ThumbStripState();
}

class _ThumbStripState extends State<ThumbStrip> {
  // 34×48 is the handoff's thumbnail; the accordion grows from it.
  static const _baseWidth = 34.0;
  static const _baseHeight = 48.0;
  static const _nearWidth = 40.0;
  static const _nearHeight = 56.0;
  static const _currentWidth = 46.0;
  static const _currentHeight = 64.0;
  static const _gap = 6.0;
  static const _hPadding = 12.0;
  static const _grow = Duration(milliseconds: 200);

  /// The closest two centres may come before the current thumbnail and its
  /// neighbour lose their gap.
  static const _minStep = (_currentWidth + _nearWidth) / 2 + _gap;

  final _controller = ScrollController();
  late final ThumbLoadQueue _queue;

  @override
  void initState() {
    super.initState();
    _queue = ThumbLoadQueue(load: _load)
      ..onChanged = () {
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
    _queue.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load(int page) {
    final provider = widget.providerBuilder(page);
    if (provider == null || !mounted) return Future.value();
    return precacheImage(provider, context, onError: (_, _) {});
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
    _queue.update(
      visible: {for (var page = first; page <= end; page++) page},
      current: widget.current,
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
      return EdgeInsetsDirectional.fromSTEB(side, 6, side, 6);
    }
    if (spread == null) {
      return const EdgeInsetsDirectional.fromSTEB(_hPadding, 6, _hPadding, 6);
    }
    return EdgeInsetsDirectional.fromSTEB(
      _hPadding + (_currentWidth - _width(0)) / 2,
      6,
      _hPadding + (_currentWidth - _width(widget.pages - 1)) / 2,
      6,
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
      height: _currentHeight + 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spread = _spread(constraints.maxWidth);
          return ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            // Spread out, the content is exactly the viewport: any scroll is
            // rounding error, and dragging it would only unstick the strip
            // from the slider.
            physics: spread == null
                ? null
                : const NeverScrollableScrollPhysics(),
            padding: _padding(spread, constraints.maxWidth),
            itemCount: widget.pages,
            separatorBuilder: (_, page) => AnimatedContainer(
              duration: _grow,
              curve: Curves.easeOut,
              width: _gapAfter(page, spread),
            ),
            itemBuilder: (context, page) {
              final selected = page == widget.current;
              final provider = _queue.isReady(page)
                  ? widget.providerBuilder(page)
                  : null;
              return Align(
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
                        color: selected ? versoAccent : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radiusThumb - 1),
                      // Until the queue has had its turn the thumbnail is just
                      // its frame: no request, nothing to shuffle around.
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
              );
            },
          );
        },
      ),
    );
  }
}
