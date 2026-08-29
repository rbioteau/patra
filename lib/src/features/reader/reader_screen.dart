import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/kavita_client.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import '../../settings/reading_settings.dart';
import '../../theme.dart';
import '../../widgets/direction_icon.dart';

final chapterInfoProvider = FutureProvider.autoDispose
    .family<ChapterInfoDto, int>((ref, chapterId) {
      return ref.watch(kavitaClientProvider).chapterInfo(chapterId);
    });

/// The reading surface: pure black canvas, chrome as gradient overlays, and a
/// single reading-direction setting (webtoon is a direction, not a mode).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.chapterId,
    this.initialPage = 0,
  });

  final int chapterId;
  final int initialPage;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late ReadingDirection _direction;
  int _page = 0;
  bool _showChrome = false;
  bool _initialProgressSaved = false;

  /// Serializes progress posts so a slow request for an earlier page can't
  /// overwrite a later one, and swallows failures (a lost save is resent on
  /// the next page turn).
  Future<void> _progressQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    // Starts from the saved preference; changing it here is per-chapter.
    _direction = ref.read(defaultReadingDirectionProvider);
  }

  // --- progress -------------------------------------------------------------

  void _saveProgress(int page, ChapterInfoDto info) {
    if (info.pages == 0) return;
    // Kavita counts pagesRead from the saved pageNum, so reaching the last
    // page must report the total for the chapter to be marked read — the
    // official web reader does the same.
    final pageNum = page >= info.pages - 1 ? info.pages : page;
    // Keep the stored copy's progress in step; it is what the Downloads tab
    // reads, and it must survive being offline.
    if (ref.read(savedChapterProvider(widget.chapterId)) != null) {
      ref
          .read(downloadsProvider.notifier)
          .recordProgress(widget.chapterId, pageNum);
    }
    final KavitaClient client;
    try {
      client = ref.read(kavitaClientProvider);
    } on StateError {
      return; // signed out mid-read
    }
    _progressQueue = _progressQueue
        .then(
          (_) => client.saveProgress(
            libraryId: info.libraryId,
            seriesId: info.seriesId,
            volumeId: info.volumeId,
            chapterId: widget.chapterId,
            pageNum: pageNum,
          ),
        )
        .catchError((Object _) {});
  }

  /// The view reports the first page it shows; a landscape spread has read
  /// both pages of the pair.
  void _onPageChanged(int page, ChapterInfoDto info, {int span = 1}) {
    if (page == _page) return;
    setState(() => _page = page);
    _saveProgress((page + span - 1).clamp(0, info.pages - 1), info);
    _precache(page + span, info);
  }

  void _precache(int page, ChapterInfoDto info) {
    if (page < 0 || page >= info.pages) return;
    final provider = _imageProvider(page);
    if (provider != null) precacheImage(provider, context);
  }

  /// onPageChanged never fires for the initial page; without this a one-page
  /// chapter would record no progress at all.
  void _saveInitialProgress(ChapterInfoDto info) {
    if (_initialProgressSaved) return;
    _initialProgressSaved = true;
    _saveProgress(_page, info);
  }

  // --- images ---------------------------------------------------------------

  SavedChapter? get _saved => ref.read(savedChapterProvider(widget.chapterId));

  /// Prefers the stored copy, so a saved chapter reads with no server at all.
  /// [thumbnail] switches to Kavita's page-thumbnail endpoint, which is far
  /// lighter than pulling every full-size page for the strip.
  ImageProvider? _imageProvider(
    int page, {
    int? cacheWidth,
    bool thumbnail = false,
  }) {
    final saved = _saved;
    if (saved != null) {
      final file = File(
        '${_localDir?.path ?? ''}/${DownloadsService.pageFileName(page)}',
      );
      if (_localDir != null && file.existsSync()) return FileImage(file);
    }
    try {
      final client = ref.read(kavitaClientProvider);
      return CachedNetworkImageProvider(
        thumbnail
            ? client.readerThumbnailUrl(widget.chapterId, page)
            : client.readerImageUrl(widget.chapterId, page),
        headers: client.imageHeaders,
        maxWidth: cacheWidth,
      );
    } on StateError {
      return null;
    }
  }

  Directory? _localDir;

  Future<void> _resolveLocalDir() async {
    if (_localDir != null || _saved == null) return;
    final dir = await ref
        .read(downloadsServiceProvider)
        .chapterDir(widget.chapterId);
    if (mounted) setState(() => _localDir = dir);
  }

  // --- navigation -----------------------------------------------------------

  void _goTo(int page, ChapterInfoDto info) {
    final clamped = page.clamp(0, info.pages - 1);
    if (clamped == _page) return;
    setState(() => _page = clamped);
    _saveProgress(clamped, info);
  }

  void _step(bool forward, ChapterInfoDto info, int span) {
    _goTo(_page + (forward ? span : -span), info);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = ref.watch(chapterInfoProvider(widget.chapterId));
    final saved = ref.watch(savedChapterProvider(widget.chapterId));

    // Offline, the stored metadata is enough to read a saved chapter.
    final chapter =
        info.value ??
        (saved == null
            ? null
            : ChapterInfoDto(
                seriesId: saved.seriesId,
                volumeId: saved.volumeId,
                libraryId: saved.libraryId,
                pages: saved.pages,
                seriesName: saved.seriesName,
                title: saved.title,
              ));

    return Scaffold(
      backgroundColor: Colors.black,
      body: switch ((chapter, info)) {
        (null, AsyncError()) => const _ReaderError(),
        (null, _) => const Center(
          child: CircularProgressIndicator(color: versoAccent),
        ),
        (final ChapterInfoDto chapter, _) => _buildReader(
          context,
          l10n,
          chapter,
        ),
      },
    );
  }

  Widget _buildReader(
    BuildContext context,
    AppLocalizations l10n,
    ChapterInfoDto chapter,
  ) {
    if (chapter.pages == 0) return const _ReaderError();
    _saveInitialProgress(chapter);
    _resolveLocalDir();

    final direction = _direction;
    final rtl = direction.isRightToLeft;

    return OrientationBuilder(
      builder: (context, orientation) {
        // Landscape shows a two-page spread, but only when paging.
        final spread =
            orientation == Orientation.landscape && !direction.isWebtoon;
        final span = spread ? 2 : 1;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (direction.isWebtoon)
              _WebtoonView(
                key: const ValueKey('webtoon'),
                chapter: chapter,
                page: _page,
                imageBuilder: _pageImage,
                onPageChanged: (page) => _onPageChanged(page, chapter),
              )
            else
              _PagedView(
                key: ValueKey('paged-$spread-$rtl'),
                pages: chapter.pages,
                page: _page,
                reverse: rtl,
                spread: spread,
                imageBuilder: _pageImage,
                onPageChanged: (page) =>
                    _onPageChanged(page, chapter, span: span),
              ),

            // Tap zones: 30 / 40 / 30. The sides page, the middle toggles
            // chrome; in right-to-left the side meanings swap with the layout.
            if (!direction.isWebtoon)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 30,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _step(rtl, chapter, span),
                      ),
                    ),
                    Expanded(
                      flex: 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => setState(() => _showChrome = !_showChrome),
                      ),
                    ),
                    Expanded(
                      flex: 30,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _step(!rtl, chapter, span),
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showChrome = !_showChrome),
                ),
              ),

            if (_showChrome) ...[
              _TopChrome(
                title: chapter.title.isNotEmpty
                    ? chapter.title
                    : chapter.seriesName,
                direction: direction,
                onDirectionChanged: (next) => setState(() {
                  _direction = next;
                  _showChrome = false;
                }),
              ),
              _BottomChrome(
                chapter: chapter,
                page: _page,
                span: spread ? 2 : 1,
                rtl: rtl,
                imageBuilder: (page) =>
                    _pageImage(page, cacheWidth: 96, thumbnail: true),
                onSeek: (page) => _goTo(page, chapter),
              ),
            ],
          ],
        );
      },
    );
  }

  /// One page, zoomable, on the black canvas.
  Widget _pageImage(
    int page, {
    int? cacheWidth,
    BoxFit fit = BoxFit.contain,
    bool thumbnail = false,
  }) {
    final provider = _imageProvider(
      page,
      cacheWidth: cacheWidth,
      thumbnail: thumbnail,
    );
    if (provider == null) return const SizedBox.shrink();
    return Image(
      image: provider,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
      frameBuilder: (context, child, frame, wasSync) => frame == null
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white24,
                ),
              ),
            )
          : child,
    );
  }
}

typedef PageImageBuilder = Widget Function(
  int page, {
  int? cacheWidth,
  BoxFit fit,
  bool thumbnail,
});

// --- paged view -------------------------------------------------------------

class _PagedView extends StatefulWidget {
  const _PagedView({
    super.key,
    required this.pages,
    required this.page,
    required this.reverse,
    required this.spread,
    required this.imageBuilder,
    required this.onPageChanged,
  });

  final int pages;
  final int page;
  final bool reverse;
  final bool spread;
  final PageImageBuilder imageBuilder;
  final ValueChanged<int> onPageChanged;

  @override
  State<_PagedView> createState() => _PagedViewState();
}

class _PagedViewState extends State<_PagedView> {
  late final PageController _controller = PageController(
    initialPage: _viewIndex(widget.page),
  );
  late int _reported = widget.page;

  int get _itemCount => widget.spread ? (widget.pages + 1) ~/ 2 : widget.pages;

  int _viewIndex(int page) => widget.spread ? page ~/ 2 : page;
  int _firstPageOf(int viewIndex) => widget.spread ? viewIndex * 2 : viewIndex;

  @override
  void didUpdateWidget(_PagedView old) {
    super.didUpdateWidget(old);
    // A seek from the slider or a tap zone: follow it.
    if (widget.page != _reported) {
      _reported = widget.page;
      final target = _viewIndex(widget.page);
      if (_controller.hasClients && _controller.page?.round() != target) {
        _controller.jumpToPage(target);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      reverse: widget.reverse,
      itemCount: _itemCount,
      onPageChanged: (index) {
        _reported = _firstPageOf(index);
        widget.onPageChanged(_reported);
      },
      itemBuilder: (context, index) {
        final first = _firstPageOf(index);
        if (!widget.spread) {
          return InteractiveViewer(
            maxScale: 5,
            child: widget.imageBuilder(first),
          );
        }
        final second = first + 1;
        final pages = [if (second < widget.pages) second];
        // verso left, recto right — mirrored when reading right to left, so
        // the first page of the pair always leads.
        final ordered = widget.reverse ? [...pages, first] : [first, ...pages];
        return InteractiveViewer(
          maxScale: 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  for (final page in ordered)
                    Expanded(
                      child: widget.imageBuilder(page, fit: BoxFit.contain),
                    ),
                ],
              ),
              if (ordered.length == 2) const _SpineShadow(),
            ],
          ),
        );
      },
    );
  }
}

/// The gutter between two pages of a spread.
class _SpineShadow extends StatelessWidget {
  const _SpineShadow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 26,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: .55),
                Colors.transparent,
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

// --- webtoon view -----------------------------------------------------------

class _WebtoonView extends StatefulWidget {
  const _WebtoonView({
    super.key,
    required this.chapter,
    required this.page,
    required this.imageBuilder,
    required this.onPageChanged,
  });

  final ChapterInfoDto chapter;
  final int page;
  final PageImageBuilder imageBuilder;
  final ValueChanged<int> onPageChanged;

  @override
  State<_WebtoonView> createState() => _WebtoonViewState();
}

class _WebtoonViewState extends State<_WebtoonView> {
  final _controller = ScrollController();
  late int _reported = widget.page;
  double _width = 0;

  /// Page heights for the current width, from the server's page dimensions,
  /// so scroll offsets are exact before any image has loaded.
  List<double> _heights = const [];
  List<double> _offsets = const [];

  void _measure(double width) {
    if (width == _width && _heights.length == widget.chapter.pages) return;
    _width = width;
    final heights = <double>[];
    final offsets = <double>[];
    var total = 0.0;
    for (var page = 0; page < widget.chapter.pages; page++) {
      offsets.add(total);
      final height = width / widget.chapter.aspectRatioFor(page);
      heights.add(height);
      total += height;
    }
    _heights = heights;
    _offsets = offsets;
  }

  int _pageAt(double offset) {
    // The page occupying the upper third of the viewport is "current".
    final probe = offset + _controller.position.viewportDimension * 0.3;
    var page = 0;
    for (var i = 0; i < _offsets.length; i++) {
      if (_offsets[i] <= probe) page = i;
    }
    return page;
  }

  void _onScroll() {
    if (!_controller.hasClients || _offsets.isEmpty) return;
    final page = _pageAt(_controller.offset);
    if (page != _reported) {
      _reported = page;
      widget.onPageChanged(page);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_WebtoonView old) {
    super.didUpdateWidget(old);
    // A seek from the slider: jump, unless this is our own report echoing.
    if (widget.page != _reported) {
      _reported = widget.page;
      if (_controller.hasClients && widget.page < _offsets.length) {
        _controller.jumpTo(
          _offsets[widget.page].clamp(0, _controller.position.maxScrollExtent),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints.maxWidth);
        return ListView.builder(
          controller: _controller,
          // A continuous strip: no gaps, no page turns.
          padding: EdgeInsets.zero,
          itemCount: widget.chapter.pages,
          itemBuilder: (context, page) => SizedBox(
            height: _heights.length > page ? _heights[page] : null,
            width: double.infinity,
            child: widget.imageBuilder(page, fit: BoxFit.fitWidth),
          ),
        );
      },
    );
  }
}

// --- chrome -----------------------------------------------------------------

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.title,
    required this.direction,
    required this.onDirectionChanged,
  });

  final String title;
  final ReadingDirection direction;
  final ValueChanged<ReadingDirection> onDirectionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: .85), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VersoText.rowTitle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                _DirectionPill(
                  direction: direction,
                  onChanged: onDirectionChanged,
                  tooltip: l10n.readingDirection,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The single control for how pages advance. Icon-only and language-free; the
/// wording lives in the menu rows.
class _DirectionPill extends StatelessWidget {
  const _DirectionPill({
    required this.direction,
    required this.onChanged,
    required this.tooltip,
  });

  final ReadingDirection direction;
  final ValueChanged<ReadingDirection> onChanged;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<ReadingDirection>(
      tooltip: tooltip,
      color: versoSurface,
      initialValue: direction,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in ReadingDirection.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                DirectionIcon(
                  option,
                  color: option == direction ? versoAccent : versoText,
                ),
                const SizedBox(width: 12),
                Text(
                  option.label(l10n),
                  style: VersoText.body(
                    color: option == direction ? versoAccent : versoText,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 36,
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: DirectionIcon(direction, size: 21),
      ),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.chapter,
    required this.page,
    required this.span,
    required this.rtl,
    required this.imageBuilder,
    required this.onSeek,
  });

  final ChapterInfoDto chapter;
  final int page;
  final int span;
  final bool rtl;
  final Widget Function(int page) imageBuilder;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = (page + span - 1).clamp(0, chapter.pages - 1);
    final counter = span > 1 && last > page
        ? l10n.pageSpreadCounter(page + 1, last + 1, chapter.pages)
        : l10n.pageCounter(page + 1, chapter.pages);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        // Pages are often near-white, so the controls need a real scrim under
        // them: solid black where they sit, fading out only above them.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0, .72, 1],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thumbnails and slider mirror together with the reading
                // direction; the numerals never do.
                Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThumbStrip(
                        pages: chapter.pages,
                        current: page,
                        imageBuilder: imageBuilder,
                        onTap: onSeek,
                      ),
                      if (chapter.pages > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Slider(
                            value: page.toDouble().clamp(
                              0,
                              (chapter.pages - 1).toDouble(),
                            ),
                            max: (chapter.pages - 1).toDouble(),
                            divisions: chapter.pages > 1
                                ? chapter.pages - 1
                                : null,
                            onChanged: (value) => onSeek(value.round()),
                          ),
                        ),
                    ],
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(counter, style: VersoText.pageNumeral()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbStrip extends StatefulWidget {
  const _ThumbStrip({
    required this.pages,
    required this.current,
    required this.imageBuilder,
    required this.onTap,
  });

  final int pages;
  final int current;
  final Widget Function(int page) imageBuilder;
  final ValueChanged<int> onTap;

  @override
  State<_ThumbStrip> createState() => _ThumbStripState();
}

class _ThumbStripState extends State<_ThumbStrip> {
  static const _thumbWidth = 34.0;
  static const _thumbHeight = 48.0;
  static const _gap = 6.0;

  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // The chrome usually opens mid-chapter: jump to where the reader is
    // rather than showing page one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealCurrent(animate: false);
    });
  }

  @override
  void didUpdateWidget(_ThumbStrip old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current) _revealCurrent();
  }

  void _revealCurrent({bool animate = true}) {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    final target =
        widget.current * (_thumbWidth + _gap) - viewport / 2 + _thumbWidth / 2;
    final offset = target.clamp(0.0, _controller.position.maxScrollExtent);
    if (!animate) {
      _controller.jumpTo(offset);
      return;
    }
    _controller.animateTo(
      offset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _thumbHeight + 12,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: widget.pages,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, page) {
          final selected = page == widget.current;
          return GestureDetector(
            onTap: () => widget.onTap(page),
            child: Container(
              width: _thumbWidth,
              height: _thumbHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radiusThumb),
                border: Border.all(
                  color: selected ? versoAccent : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radiusThumb - 1),
                child: widget.imageBuilder(page),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Nothing readable: no chapter info and no stored copy.
class _ReaderError extends StatelessWidget {
  const _ReaderError();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(gutter),
            child: Text(
              l10n.serverUnreachable,
              textAlign: TextAlign.center,
              style: VersoText.body(color: Colors.white70),
            ),
          ),
        ),
        SafeArea(
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
