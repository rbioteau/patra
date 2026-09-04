import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/kavita_client.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import '../../downloads/image_cache_store.dart';
import '../../settings/cache_settings.dart';
import '../../settings/reading_settings.dart';
import '../../theme.dart';
import '../../widgets/reader_settings_sheet.dart';
import 'loupe_gesture.dart';
import 'page_loading.dart';
import 'spread_layout.dart';
import 'thumb_strip.dart';

final chapterInfoProvider = FutureProvider.autoDispose
    .family<ChapterInfo, int>(retry: serverRetry, (ref, chapterId) {
      return ref.watch(kavitaClientProvider).chapterInfo(chapterId);
    });

/// The reading surface: pure black canvas, chrome as gradient overlays, and a
/// single reading-direction setting (vertical scrolling is a direction,
/// not a mode).
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
    // The chapter opens with no chrome of ours, and none of the system's.
    _setSystemChrome(visible: false);
  }

  @override
  void dispose() {
    // The clock belongs to the rest of the app: hand it back on the way out.
    // `edgeToEdge` is what every other screen runs under — it is Flutter's
    // default on iOS and on the Android SDK level we target.
    _setSystemChrome(visible: true);
    // Leaving the chapter ends the backfill with it: nothing is left to scrub.
    _thumbs.dispose();
    super.dispose();
  }

  /// The reader's chrome and the system's come and go together.
  ///
  /// While reading there is nothing on the screen but the page — no clock, no
  /// battery, no home indicator — because a page of a book is the whole point
  /// of the screen. The tap that brings the title bar back brings the rest
  /// back with it, so the time is always one tap away rather than gone.
  ///
  /// iOS hides the status bar and the home indicator for any of the fullscreen
  /// modes. Android honours it below API 36 and ignores it above, where the
  /// system enforces edge-to-edge; that is the platform's call, not ours.
  void _setSystemChrome({required bool visible}) {
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  /// Shows or hides both at once. Every path that changes [_showChrome] goes
  /// through here, or the system bars would drift out of step with ours.
  void _showChromeAndBars(bool visible) {
    if (visible != _showChrome) setState(() => _showChrome = visible);
    _setSystemChrome(visible: visible);
  }

  // --- progress -------------------------------------------------------------

  void _saveProgress(int page, ChapterInfo info) {
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
  void _onPageChanged(int page, ChapterInfo info, {int span = 1}) {
    if (page == _page) return;
    setState(() => _page = page);
    _saveProgress((page + span - 1).clamp(0, info.pages - 1), info);
    _precache(page + span, info);
    // Reading is what fills the image cache; this is where it has to be kept
    // inside its budget. The store throttles the sweeps.
    ref
        .read(imageCacheStoreProvider)
        .trimIfDue(ref.read(imageCacheLimitProvider).bytes);
  }

  void _precache(int page, ChapterInfo info) {
    if (page < 0 || page >= info.pages) return;
    final provider = _imageProvider(page);
    if (provider != null) precacheImage(provider, context);
  }

  /// onPageChanged never fires for the initial page; without this a one-page
  /// chapter would record no progress at all.
  ///
  /// Deferred a frame because it is reached from `build`, and saving mirrors
  /// progress into the stored copy — writing to a provider while the tree is
  /// building is what Riverpod refuses outright.
  void _saveInitialProgress(ChapterInfo info) {
    if (_initialProgressSaved) return;
    _initialProgressSaved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _saveProgress(_page, info);
    });
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
    final dir = _localDir;
    if (_saved != null && dir != null && _localPages.contains(page)) {
      final file = File('${dir.path}/${DownloadsService.pageFileName(page)}');
      // Decoding a full page into a 34px thumbnail is what makes the strip
      // expensive offline, where there is no request to blame.
      return cacheWidth == null
          ? FileImage(file)
          : ResizeImage(FileImage(file), width: cacheWidth);
    }
    try {
      final client = ref.read(kavitaClientProvider);
      final ImageProvider provider = CachedNetworkImageProvider(
        thumbnail
            ? client.readerThumbnailUrl(widget.chapterId, page)
            : client.readerImageUrl(widget.chapterId, page),
        headers: client.imageHeaders,
      );
      // [cacheWidth] belongs to the *decoder*, not to the cache manager.
      // `CachedNetworkImageProvider`'s own `maxWidth` hands the job to
      // `flutter_cache_manager`, which downloads the image, decodes it, decodes
      // it a second time at the target width, re-encodes that as **PNG** on the
      // UI isolate and writes a second file — per thumbnail, for a strip that
      // asks for a few hundred of them, against an endpoint whose whole point
      // is that it already serves something small. `ResizeImage` gets the same
      // decode budget out of one decode, no re-encode and no second copy in the
      // cache we are also trying to keep under a byte cap.
      return cacheWidth == null
          ? provider
          : ResizeImage(provider, width: cacheWidth);
    } on StateError {
      return null;
    }
  }

  /// Loads the strip's thumbnails, and keeps loading the rest of the chapter's
  /// once the strip is idle. It belongs here rather than to [ThumbStrip] so
  /// that hiding the chrome neither throws away what it has fetched nor stops
  /// it: on a real server a thumbnail costs ~200 ms cold and ~2 ms warm, so a
  /// chapter walked through once scrubs instantly afterwards. It fetches
  /// nothing until the scrubber has been opened at least once — that is what
  /// tells it how long the chapter is.
  late final ThumbLoadQueue _thumbs = ThumbLoadQueue(load: _loadThumb);

  /// What a strip thumbnail is decoded at: the size it is actually drawn at,
  /// in device pixels, capped at what Kavita's thumbnail endpoint serves.
  ///
  /// The precache and the widget that shows it must ask for the *same* width:
  /// `ResizeImage` puts it in the cache key, so a mismatch quietly precaches
  /// one image and displays another. Asking for less than the strip draws is
  /// the blur the strip exists to avoid; asking for more only costs memory,
  /// since there is no more detail in the source.
  int get _thumbCacheWidth =>
      (ThumbStrip.thumbWidth(context) * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(96, 320);

  Future<void> _loadThumb(int page) {
    if (!mounted) return Future.value();
    final provider = _imageProvider(
      page,
      cacheWidth: _thumbCacheWidth,
      thumbnail: true,
    );
    if (provider == null) return Future.value();
    return precacheImage(provider, context, onError: (_, _) {});
  }

  Directory? _localDir;

  /// Which pages the stored copy actually holds, read once.
  ///
  /// This is asked for every page the reader builds, and the thumbnail strip
  /// builds a screenful of them on every scroll frame — a `existsSync` per
  /// thumbnail per frame is a syscall storm on the very thread that has to
  /// decode them. The directory cannot change under us: a chapter is written
  /// whole or deleted whole, and removing it leaves the reader.
  var _localPages = const <int>{};

  Future<void> _resolveLocalDir() async {
    if (_localDir != null || _saved == null) return;
    final dir = await ref
        .read(downloadsServiceProvider)
        .chapterDir(widget.chapterId);
    final pages = <int>{};
    try {
      await for (final entity in dir.list(followLinks: false)) {
        final page = DownloadsService.pageOfFileName(
          entity.path.split('/').last,
        );
        if (page != null) pages.add(page);
      }
    } on FileSystemException {
      // No stored copy after all; the network path below covers it.
    }
    if (!mounted) return;
    setState(() {
      _localDir = dir;
      _localPages = pages;
    });
  }

  // --- navigation -----------------------------------------------------------

  void _goTo(int page, ChapterInfo info) {
    final clamped = page.clamp(0, info.pages - 1);
    if (clamped == _page) return;
    setState(() => _page = clamped);
    _saveProgress(clamped, info);
  }

  /// A step is a screen, not a fixed number of pages: a double-page scan sits
  /// on one of its own, so stepping back from it lands on the *first* page of
  /// the pair before it rather than on the second.
  void _step(bool forward, ChapterInfo info, SpreadLayout? spread) {
    if (spread == null) {
      _goTo(_page + (forward ? 1 : -1), info);
      return;
    }
    final index = spread.indexOf(_page) + (forward ? 1 : -1);
    if (index < 0 || index >= spread.length) return;
    _goTo(spread.firstOf(index), info);
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
            : ChapterInfo(
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
          child: CircularProgressIndicator(color: patraAccent),
        ),
        (final ChapterInfo chapter, _) => _buildReader(
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
    ChapterInfo chapter,
  ) {
    // An EPUB or a PDF has no pages to fetch: `/api/Reader/image` serves
    // nothing for them, so opening one would be a reader full of broken
    // pages. The series screen already refuses these rows; this catches the
    // ways in that do not go through it — a deep link, or a resume.
    if (!chapter.seriesFormat.isImageReadable) {
      return const _UnsupportedFormat();
    }
    if (chapter.pages == 0) return const _ReaderError();
    _saveInitialProgress(chapter);
    _resolveLocalDir();

    final direction = _direction;
    final rtl = direction.isRightToLeft;
    // Vertical scrolling is excluded rather than forgotten: there the drag
    // *is* the scroll, and a mode that took it away would leave the direction
    // with no way to advance at all.
    final loupe = ref.watch(loupeProvider) && !direction.isVerticalScroll;

    return OrientationBuilder(
      builder: (context, orientation) {
        // Landscape shows a two-page spread, but only when paging — and
        // which pages actually share a screen is the layout's call, since a
        // scan that is already a double page takes one on its own.
        final spread =
            orientation == Orientation.landscape && !direction.isVerticalScroll
            ? SpreadLayout.of(chapter)
            : null;
        final span = spread?.spanOf(_page) ?? 1;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (direction.isVerticalScroll)
              _VerticalScrollView(
                key: const ValueKey('verticalScroll'),
                chapter: chapter,
                page: _page,
                imageBuilder: _pageImage,
                onPageChanged: (page) => _onPageChanged(page, chapter),
              )
            else
              _PagedView(
                key: ValueKey('paged-${spread != null}-$rtl'),
                pages: chapter.pages,
                page: _page,
                reverse: rtl,
                spread: spread,
                loupe: loupe,
                aspectRatioFor: chapter.aspectRatioFor,
                imageBuilder: _pageImage,
                // The span of the page being *arrived at*, which is not the
                // one the screen has been showing.
                onPageChanged: (page) => _onPageChanged(
                  page,
                  chapter,
                  span: spread?.spanOf(page) ?? 1,
                ),
              ),

            // Tap zones: 30 / 40 / 30. The sides page, the middle toggles
            // chrome; in right-to-left the side meanings swap with the layout.
            if (!direction.isVerticalScroll)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 30,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _step(rtl, chapter, spread),
                      ),
                    ),
                    Expanded(
                      flex: 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _showChromeAndBars(!_showChrome),
                      ),
                    ),
                    Expanded(
                      flex: 30,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _step(!rtl, chapter, spread),
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _showChromeAndBars(!_showChrome),
                ),
              ),

            if (_showChrome) ...[
              _TopChrome(
                title: chapter.title.isNotEmpty
                    ? chapter.title
                    : chapter.seriesName,
                direction: direction,
                onDirectionChanged: (next) {
                  setState(() => _direction = next);
                  _showChromeAndBars(false);
                },
              ),
              _BottomChrome(
                chapter: chapter,
                page: _page,
                span: span,
                rtl: rtl,
                thumbQueue: _thumbs,
                thumbProvider: (page) => _imageProvider(
                  page,
                  cacheWidth: _thumbCacheWidth,
                  thumbnail: true,
                ),
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
    AlignmentGeometry alignment = Alignment.center,
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
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
      frameBuilder: (context, child, frame, wasSync) =>
          frame == null ? PageLoading(explain: _serverIsPreparing) : child,
    );
  }

  /// Kavita rasterises a PDF into page images on the first request for it, so
  /// the first page of one can be slow enough that a bare spinner reads as a
  /// hang. Every later page comes from its cache.
  bool get _serverIsPreparing =>
      ref.read(chapterInfoProvider(widget.chapterId)).value?.seriesFormat ==
      MangaFormat.pdf;
}

class _PagedView extends StatefulWidget {
  const _PagedView({
    super.key,
    required this.pages,
    required this.page,
    required this.reverse,
    required this.spread,
    required this.loupe,
    required this.aspectRatioFor,
    required this.imageBuilder,
    required this.onPageChanged,
  });

  final int pages;
  final int page;
  final bool reverse;

  /// Which pages share a screen, or null when they are shown one at a time.
  final SpreadLayout? spread;

  /// Whether a one-finger drag magnifies the page instead of turning it.
  final bool loupe;

  final double Function(int page) aspectRatioFor;
  final PageImageBuilder imageBuilder;
  final ValueChanged<int> onPageChanged;

  @override
  State<_PagedView> createState() => _PagedViewState();
}

class _PagedViewState extends State<_PagedView> {
  late final PageController _controller = PageController(
    initialPage: _viewIndex(widget.page),
  );

  /// The page this view last told the reader about, and so the page it
  /// believes it is showing.
  ///
  /// Set in [initState] rather than by a `late` initialiser. A `late` field
  /// runs its initialiser at the first *read*, and the first read is the
  /// comparison in [didUpdateWidget] — by which time `widget.page` is already
  /// the new page, so it initialised to the value it was about to be tested
  /// against and the guard skipped the jump. The first tap on a side zone
  /// therefore moved the reader's page number and left the pager where it
  /// was, and the second jumped two. Nothing caught it because a swipe takes
  /// the other path entirely, through `onPageChanged`.
  late int _reported;

  @override
  void initState() {
    super.initState();
    _reported = widget.page;
  }

  int get _itemCount => widget.spread?.length ?? widget.pages;

  int _viewIndex(int page) => widget.spread?.indexOf(page) ?? page;
  int _firstPageOf(int viewIndex) =>
      widget.spread?.firstOf(viewIndex) ?? viewIndex;

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

  /// The page, magnifiable — by the loupe gesture when it is on, and by the
  /// usual pinch when it is not. Never both: they would be two recognisers
  /// competing for the same one-finger drag.
  Widget _zoomable(List<double> aspectRatios, Widget child) => widget.loupe
      ? _LoupePage(aspectRatios: aspectRatios, child: child)
      : InteractiveViewer(maxScale: 5, child: child);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      reverse: widget.reverse,
      // The loupe owns the one-finger drag, so the swipe that turns a page
      // has to give it up — the tap zones are what turn pages in that mode.
      // Two recognisers cannot share one drag, and letting them fight would
      // make both unreliable rather than making either work.
      physics: widget.loupe ? const NeverScrollableScrollPhysics() : null,
      itemCount: _itemCount,
      onPageChanged: (index) {
        _reported = _firstPageOf(index);
        widget.onPageChanged(_reported);
      },
      itemBuilder: (context, index) {
        final spread = widget.spread;
        if (spread == null) {
          final page = _firstPageOf(index);
          return _zoomable(
            [widget.aspectRatioFor(page)],
            widget.imageBuilder(page),
          );
        }
        final pages = spread.slots[index];
        // Verso left, recto right — mirrored when reading right to left, so
        // the first page of the pair always leads. A double-page scan is
        // alone on its screen and takes the whole width.
        final ordered = widget.reverse ? pages.reversed.toList() : pages;
        return _zoomable(
          [for (final page in ordered) widget.aspectRatioFor(page)],
          Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  for (final (position, page) in ordered.indexed)
                    Expanded(
                      child: widget.imageBuilder(
                        page,
                        fit: BoxFit.contain,
                        // Each page is contained in its own half of the
                        // screen, and centred there it would sit away from
                        // the spine: the pair would be joined by a gutter
                        // that widens with the screen and with how narrow
                        // the scans are. They are pushed together instead —
                        // the pair meets on the centre line, and the room
                        // left over goes to the outer edges.
                        alignment: ordered.length == 1
                            ? Alignment.center
                            : position == 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                      ),
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

/// One page under the loupe: a one-finger drag magnifies it around the point
/// pressed, and letting go returns it to the page.
///
/// The gesture's rules are all in [LoupeGesture], which is a pure function of
/// the viewport, where the artwork sits and where the finger is. This widget
/// only measures the first two, feeds it the third, and animates the way back.
class _LoupePage extends StatefulWidget {
  const _LoupePage({required this.aspectRatios, required this.child});

  /// The aspect ratio of each page sharing this screen, in drawing order.
  final List<double> aspectRatios;
  final Widget child;

  @override
  State<_LoupePage> createState() => _LoupePageState();
}

class _LoupePageState extends State<_LoupePage>
    with SingleTickerProviderStateMixin {
  /// Letting go returns the page rather than snapping it back: a cut from
  /// 2.5x to the whole page loses the reader their place on it.
  static const _releaseDuration = Duration(milliseconds: 180);

  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: _releaseDuration,
  )..addListener(_onReleaseTick);

  LoupeGesture? _gesture;
  LoupeTransform? _shown;

  /// Where the finger actually touched down.
  ///
  /// Not the same as where the pan is *recognised*, which is already a slop
  /// distance into the drag — about 18pt on a touch screen. The design says
  /// the point of contact is the reference point, and taking it from
  /// `onPanStart` would put it 18pt along the direction of travel instead:
  /// the page would be magnified around a spot slightly below where the
  /// reader put their thumb, every time, in the direction they were already
  /// pulling.
  Offset? _downAt;

  /// Where the page was when the finger left it, and where it is going back
  /// to. Held across the animation so a rebuild mid-flight cannot lose them.
  LoupeTransform? _from;
  LoupeTransform? _to;

  @override
  void dispose() {
    _release.dispose();
    super.dispose();
  }

  void _onReleaseTick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final t = Curves.easeOutCubic.transform(_release.value);
    setState(() {
      if (_release.isCompleted) {
        _shown = _from = _to = null;
      } else {
        _shown = LoupeTransform.lerp(from, to, t);
      }
    });
  }

  void _onStart(DragStartDetails details, Size viewport) {
    _release.stop();
    final gesture = LoupeGesture(
      viewport: viewport,
      content: drawnContent(viewport, widget.aspectRatios),
      anchor: _downAt ?? details.localPosition,
    );
    _gesture = gesture;
    _from = _to = null;
    setState(() => _shown = gesture.to(details.localPosition));
  }

  void _onUpdate(DragUpdateDetails details) {
    final gesture = _gesture;
    if (gesture == null) return;
    setState(() => _shown = gesture.to(details.localPosition));
  }

  void _onEnd() {
    final from = _shown;
    _gesture = null;
    _downAt = null;
    if (from == null) return;
    if (from.isRest) {
      setState(() => _shown = null);
      return;
    }
    _from = from;
    _to = LoupeTransform.rest(from.content);
    _release.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final shown = _shown;
        return GestureDetector(
          // Opaque, so the drag is caught anywhere on the canvas — including
          // the letterbox bars, which are as much a part of the page as the
          // artwork to the thumb resting on them. The tap zones sit above
          // this in the stack and still win a tap: only a drag reaches here.
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _downAt = details.localPosition,
          onPanStart: (details) => _onStart(details, viewport),
          onPanUpdate: _onUpdate,
          onPanEnd: (_) => _onEnd(),
          onPanCancel: _onEnd,
          child: shown == null
              ? widget.child
              : Transform(transform: shown.matrix, child: widget.child),
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

// --- vertical-scrolling view -----------------------------------------------------------

class _VerticalScrollView extends StatefulWidget {
  const _VerticalScrollView({
    super.key,
    required this.chapter,
    required this.page,
    required this.imageBuilder,
    required this.onPageChanged,
  });

  final ChapterInfo chapter;
  final int page;
  final PageImageBuilder imageBuilder;
  final ValueChanged<int> onPageChanged;

  @override
  State<_VerticalScrollView> createState() => _VerticalScrollViewState();
}

class _VerticalScrollViewState extends State<_VerticalScrollView> {
  final _controller = ScrollController();
  late int _reported = widget.page;
  double _width = 0;

  /// Whether the strip has been scrolled to the page it was opened at.
  var _placed = false;

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
    // Until the strip has been placed it is sitting at offset 0, which is not
    // where the reader is: reporting from there would post page 0 back and
    // wipe the place the chapter was opened at.
    if (!_placed || !_controller.hasClients || _offsets.isEmpty) return;
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
    // The strip opens where reading left off — the paged view gets this from
    // `PageController(initialPage:)`, a scroll view has to be told. Offsets
    // are only known once the width is, so the jump waits for the first
    // layout; [_placed] keeps any scroll before that from reporting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpTo(widget.page);
      _placed = true;
    });
  }

  void _jumpTo(int page) {
    if (!_controller.hasClients || page >= _offsets.length) return;
    _controller.jumpTo(
      _offsets[page].clamp(0, _controller.position.maxScrollExtent),
    );
  }

  @override
  void didUpdateWidget(_VerticalScrollView old) {
    super.didUpdateWidget(old);
    // A seek from the slider: jump, unless this is our own report echoing.
    if (widget.page != _reported) {
      _reported = widget.page;
      _jumpTo(widget.page);
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
                    style: PatraText.rowTitle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                _SettingsCog(
                  direction: direction,
                  onDirectionChanged: onDirectionChanged,
                  tooltip: l10n.readerSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one control in the reader's top bar. Everything it opens lives in
/// [showReaderSettingsSheet], which says why this is a cog rather than the
/// direction pill it replaced.
class _SettingsCog extends StatelessWidget {
  const _SettingsCog({
    required this.direction,
    required this.onDirectionChanged,
    required this.tooltip,
  });

  final ReadingDirection direction;
  final ValueChanged<ReadingDirection> onDirectionChanged;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => showReaderSettingsSheet(
          context,
          direction: direction,
          onDirectionChanged: onDirectionChanged,
        ),
        borderRadius: BorderRadius.circular(radiusPill),
        child: Container(
          height: 36,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(radiusPill),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: const Icon(Icons.tune, size: 21, color: Colors.white),
        ),
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
    required this.thumbQueue,
    required this.thumbProvider,
    required this.onSeek,
  });

  final ChapterInfo chapter;
  final int page;
  final int span;
  final bool rtl;
  final ThumbLoadQueue thumbQueue;
  final ImageProvider? Function(int page) thumbProvider;
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
                      ThumbStrip(
                        pages: chapter.pages,
                        current: page,
                        queue: thumbQueue,
                        providerBuilder: thumbProvider,
                        onTap: onSeek,
                      ),
                      if (chapter.pages > 1)
                        Padding(
                          // The handle has to start and end where the strip's
                          // bulge does: the strip works out how far in that is.
                          padding: EdgeInsets.symmetric(
                            horizontal: ThumbStrip.sliderPadding(context),
                          ),
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
                  child: Text(counter, style: PatraText.pageNumeral()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A format the page reader cannot show. Says so rather than failing page by
/// page, and names what is coming.
class _UnsupportedFormat extends StatelessWidget {
  const _UnsupportedFormat();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  color: Colors.white24,
                  size: 34,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.formatNotSupported,
                  textAlign: TextAlign.center,
                  style: PatraText.rowTitle(),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.formatNotSupportedBody,
                  textAlign: TextAlign.center,
                  style: PatraText.metadata(),
                ),
              ],
            ),
          ),
        ),
        const SafeArea(child: BackButton(color: Colors.white70)),
      ],
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
              style: PatraText.body(color: Colors.white70),
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
