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
import '../../catalogue/catalogue_reads.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import '../../downloads/image_cache_store.dart';
import '../../settings/cache_settings.dart';
import '../../settings/profile_preferences.dart';
import '../../settings/reading_settings.dart';
import '../../theme.dart';
import '../../widgets/chrome_pill.dart';
import '../../widgets/reader_settings_sheet.dart';
import 'book_contents.dart';
import 'book_page.dart';
import 'magnify_gesture.dart';
import 'page_loading.dart';
import 'page_rail.dart';
import 'page_shape.dart';
import 'reading_direction.dart';
import 'spread_layout.dart';
import 'strip_geometry.dart';
import 'strip_width.dart';
import 'thumb_strip.dart';

final chapterInfoProvider = FutureProvider.autoDispose.family<ChapterInfo, int>(
  retry: serverRetry,
  (ref, chapterId) async {
    final client = ref.watch(kavitaClientProvider);
    final info = await client.chapterInfo(chapterId);
    // Page dimensions reach the app nowhere else, and they arrive a chapter
    // at a time for a work that is one thing: recording what they say about
    // the *work* is what lets the detected rung of the chain answer (#57).
    // Guarded, because leaving the reader mid-fetch disposes this provider
    // while it is still waiting.
    if (ref.mounted) ref.read(pageShapesProvider.notifier).record(info);
    // A book has no image pages for `chapter-info` to count: it is the
    // server that lays its words out into pages (ADR-0008), and `book-info`
    // is where it says how many. Where the reader was is a third question,
    // and the only one with an answer a book cannot do without: a page of a
    // book can be longer than the screen, so the page number alone opens it
    // again at words already read.
    if (info.content != ChapterContent.reflowable) return info;
    final (book, progress) = await (
      client.bookInfo(chapterId),
      client.chapterProgress(chapterId),
    ).wait;
    return info.withBook(book, progress);
  },
);

/// What one page of a book is asked about: the chapter, and which page of it.
typedef BookPageKey = ({int chapterId, int page});

/// One page of a book: the HTML the server laid out, taken apart into the
/// blocks the reader draws.
///
/// A family of the page as well as the chapter so a page the reader has been
/// shown is not asked for again on the way back to it, and so a page it has
/// left behind is forgotten with the screen.
///
/// Where the device already holds a copy, the copy is what is read: a saved
/// book is the pages the server rendered (ADR-0009), and it is the only page
/// there is once there is no server to ask. A copy that does not hold this
/// one — the server has recounted the book since the copy was made (#78) —
/// falls back to asking, exactly as a stored page of pictures does.
final bookPageProvider = FutureProvider.autoDispose
    .family<BookPage, BookPageKey>(retry: serverRetry, (ref, key) async {
      final client = ref.watch(kavitaClientProvider);
      final stored = await _storedBookPage(ref, key);
      if (stored != null) return stored;
      final html = await client.bookPage(key.chapterId, key.page);
      return BookPage.fromHtml(html);
    });

/// The page of a book the stored copy already holds, or null where there is
/// no copy of this one.
Future<BookPage?> _storedBookPage(Ref ref, BookPageKey key) async {
  final saved = ref.watch(savedChapterProvider(key.chapterId));
  if (saved == null || saved.content != ChapterContent.reflowable) return null;
  final file = File(
    '${(await ref.watch(chapterDirProvider(key.chapterId).future)).path}/'
    '${DownloadsService.pageFileName(key.page)}',
  );
  if (!file.existsSync()) return null;
  return BookPage.fromHtml(file.readAsStringSync());
}

/// What a book is made of, as the server lists it: a tree of parts and their
/// children, each with the page it begins on.
///
/// Asked for a book and nothing else, and only while a book is being read —
/// a chapter of pictures is a list of pages with nothing to name them, and a
/// book nobody looks at the contents of is not asked twice. It is watched by
/// the reader rather than by the sheet it fills because whether there is a
/// list at all is what decides whether the reader offers one: a book with no
/// contents offers none, and says nothing about the absence.
final bookContentsProvider = FutureProvider.autoDispose
    .family<List<BookContentsEntry>, int>(retry: serverRetry, (
      ref,
      chapterId,
    ) async {
      return ref.watch(kavitaClientProvider).bookContents(chapterId);
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
  int _page = 0;
  bool _showChrome = false;
  bool _initialProgressSaved = false;

  /// Where in each page of a book the reader is, by page.
  ///
  /// A book's page can be longer than the screen, so where a reader is is a
  /// page and a place within it, and the place is what travels to the server
  /// with the page number. Keyed by page rather than held as one number
  /// because turning a page is arriving at its beginning while coming back
  /// to one is not; a page with no entry is a page opened at its top.
  final Map<int, BookAnchor> _anchors = {};

  /// Whether a book has been put where the reader left it. Once, and from
  /// what the server says rather than from the page the route named: a
  /// reader who has turned a page has said where they are.
  var _opened = false;

  /// Whether the copy's page total has been put to the server's own count,
  /// which is asked once and never from inside a build.
  var _pageTotalNoted = false;

  /// Serializes progress posts so a slow request for an earlier page can't
  /// overwrite a later one, and swallows failures (a lost save is resent on
  /// the next page turn).
  Future<void> _progressQueue = Future.value();

  /// The client the page and thumbnail URLs are built from, resolved off the
  /// layout path for the same reason as [_thumbCacheWidth]: [_imageProvider] is
  /// called from the strip's item builder, and a `ref.read` there is a read
  /// during layout. Null while signed out, where `kavitaClientProvider` throws
  /// and there is nothing to load anything with. The identity it carries
  /// (base URL, api key) only changes with the session, and changing the
  /// session leaves the reader.
  KavitaClient? _client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _client = ref.read(kavitaClientProvider);
    } on StateError {
      _client = null;
    }
    _thumbCacheWidth =
        (ThumbStrip.thumbWidth(context) *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(96, 320);
  }

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    // Which direction the chapter opens in is the chain's to answer and the
    // chain's alone (`reading_direction.dart`): it is a function of the
    // series, of whoever is reading and of what they have stored, so the
    // screen watches it rather than keeping a copy that a change in the cog
    // would then have to keep in step with what was written.
    //
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
    // Where in the page the reader is, for a book whose page can be longer
    // than the screen: a page number alone opens it again at the top, which
    // is words already read. A chapter of pictures has no place within a page
    // to report.
    final anchor = info.content == ChapterContent.reflowable
        ? (_anchors[page] ?? BookAnchor.top).id
        : null;
    // Written into the copy *before* it is sent, so a journey is not a hole
    // in what the server knows. The copy is the one thing on the device that
    // outlives the app being closed with a page still to post, and what it
    // is holding is sent the moment there is a server to send it to — the
    // number and the place within the page together, which is the only shape
    // in which a book's progress means anything.
    if (ref.read(savedChapterProvider(widget.chapterId)) != null) {
      ref
          .read(downloadsProvider.notifier)
          .recordProgress(
            widget.chapterId,
            pageNum,
            pending: PendingProgress(pageNum: pageNum, bookScrollId: anchor),
          );
    }
    final KavitaClient client;
    try {
      client = ref.read(kavitaClientProvider);
    } on StateError {
      return; // signed out mid-read
    }
    _progressQueue = _progressQueue
        .then((_) async {
          await client.saveProgress(
            libraryId: info.libraryId,
            seriesId: info.seriesId,
            volumeId: info.volumeId,
            chapterId: widget.chapterId,
            pageNum: pageNum,
            bookScrollId: anchor,
          );
          // Taken, so the copy has nothing left to send. Where the reader has
          // turned a page since, this is a no-op rather than a loss: the copy
          // is holding the newer one, and only that one is cleared.
          await ref
              .read(downloadsProvider.notifier)
              .clearPendingProgress(
                widget.chapterId,
                PendingProgress(pageNum: pageNum, bookScrollId: anchor),
              );
        })
        .catchError((Object _) {});
  }

  /// The view reports the first page it shows; a landscape spread has read
  /// both pages of the pair.
  ///
  /// [precacheWidth] is the width the strip draws its pages at, which is the
  /// width the next page has to be warmed at for the warm copy to be the one
  /// that is then displayed. Paged reading shows a page at whatever the file
  /// is, and asks for nothing in particular.
  void _onPageChanged(
    int page,
    ChapterInfo info, {
    int span = 1,
    int? precacheWidth,
  }) {
    if (page == _page) return;
    setState(() => _page = page);
    _saveProgress((page + span - 1).clamp(0, info.pages - 1), info);
    _precache(page + span, info, cacheWidth: precacheWidth);
    // Reading is what fills the image cache; this is where it has to be kept
    // inside its budget. The store throttles the sweeps.
    ref
        .read(imageCacheStoreProvider)
        .trimIfDue(ref.read(imageCacheLimitProvider).bytes);
  }

  void _precache(int page, ChapterInfo info, {int? cacheWidth}) {
    // A book has no page picture to warm: `/api/Reader/image` serves nothing
    // for it, and its pictures are named inside the page it has not been
    // asked for yet.
    if (info.content != ChapterContent.fixedPages) return;
    if (page < 0 || page >= info.pages) return;
    final provider = _imageProvider(page, cacheWidth: cacheWidth);
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

  /// The stored copy, mirrored out of [build]'s own `watch` rather than read
  /// where it is wanted — for the same reason as [_client] and
  /// [_thumbCacheWidth]: [_imageProvider] is called from the strip's item
  /// builder, which a lazy list runs during layout, and a provider read there
  /// is a read during layout. `build` watches it anyway, so this is the same
  /// value one frame no later.
  SavedChapter? _savedChapter;

  SavedChapter? get _saved => _savedChapter;

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
    final client = _client;
    if (client == null) return null;
    {
      final url = thumbnail
          ? client.readerThumbnailUrl(widget.chapterId, page)
          : client.readerImageUrl(widget.chapterId, page);
      final ImageProvider provider = CachedNetworkImageProvider(
        url,
        // Without a key of its own the auth key in the URL files this page
        // under the profile that fetched it, and the next person on the
        // tablet downloads the same scan again (`imageCacheKey`).
        cacheKey: imageCacheKey(url),
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
  ///
  /// Resolved in [didChangeDependencies] rather than read where it is needed,
  /// because where it is needed is inside the strip's item builder — which a
  /// lazy list runs during **layout**. Asking for the MediaQuery there makes
  /// this element one of its dependents in the middle of a layout, and what
  /// wakes those dependents is a change of screen: a rotation would then
  /// rebuild the reader mid-layout, and its Scaffold answers a body swapped
  /// under it with "Each child must be laid out exactly once".
  int _thumbCacheWidth = 96;

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

  /// Puts the copy's page total to the server's own count, once: the number
  /// [total] is what the server says the chapter is made of, and a copy was
  /// made with a number of its own.
  ///
  /// Deferred a frame because it is reached from `build`, and it writes to a
  /// provider — which is what Riverpod refuses outright while the tree is
  /// building.
  void _notePageTotal(int total) {
    if (_pageTotalNoted) return;
    _pageTotalNoted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(downloadsProvider.notifier)
          .notePageTotal(widget.chapterId, total);
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(chapterInfoProvider(widget.chapterId));
    final saved = ref.watch(savedChapterProvider(widget.chapterId));
    _savedChapter = saved;
    _serverIsPreparing = info.value?.seriesFormat == MangaFormat.pdf;

    // Offline, the stored metadata is enough to read a saved chapter — and
    // what it is made of is part of it, or a saved book would open in the
    // reader for pages that are pictures and show nothing.
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
                seriesFormat: saved.format,
              ));

    // A saved copy keeps the pagination it was made with (ADR-0009), so what
    // the server counts now is a fact about the copy: where the two disagree
    // it is named out of date and offered for a refresh, rather than being
    // refetched behind the reader's back or left to resume at the wrong page
    // in silence. Asked here because this is where the two are in one place —
    // the copy on the device, and the count only the server gives.
    if (saved != null && info.value != null) {
      _notePageTotal(info.value!.pages);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: switch ((chapter, info)) {
        (null, AsyncError()) => const _ReaderError(),
        (null, _) => const Center(
          child: CircularProgressIndicator(color: patraAccent),
        ),
        (final ChapterInfo chapter, _) => _buildReader(context, chapter),
      },
    );
  }

  Widget _buildReader(BuildContext context, ChapterInfo chapter) {
    // Nothing to read, whether the server counted no pages or could not be
    // asked: a book with no pages is a book with nothing in it.
    if (chapter.pages == 0) return const _ReaderError();
    // A book is a chapter of words, and the pages it is made of are the
    // server's: it lays them out and hands them over one at a time, so
    // reading one is a reader of its own rather than the picture reader
    // with the pictures taken out.
    if (chapter.content == ChapterContent.reflowable) {
      return _buildBookReader(context, chapter);
    }
    _saveInitialProgress(chapter);
    _resolveLocalDir();

    // The whole chain, resolved for this chapter's series and its library,
    // and for whoever is reading: the series' own choice, then the library's,
    // then the profile's, then the direction detected from the work, then the
    // device's default.
    final resolved = ref.watch(
      chapterDirectionProvider((
        seriesId: chapter.seriesId,
        libraryId: chapter.libraryId,
      )),
    );
    // What the library this chapter is shelved in is called, which is how
    // the sheet words the rows that act on its rung. Read off what the device
    // already remembers of the shelves, so opening a chapter asks for
    // nothing; an id with no name yet is worded "this library" rather than
    // left trailing off.
    final libraryName = ref.watch(libraryNameProvider(chapter.libraryId));
    final direction = resolved.direction;
    final rtl = direction.isRightToLeft;
    // Vertical scrolling is excluded rather than forgotten: there the drag
    // *is* the scroll, and a mode that took it away would leave the direction
    // with no way to advance at all.
    final magnify = ref.watch(magnifyProvider) && !direction.isVerticalScroll;
    // How wide the chapter opens, which is how wide the strip is laid out.
    // Watched rather than read once, because it is a preference and not a
    // property of the chapter in hand: what somebody chooses in the cog or
    // in Settings is theirs, and the chapter in front of them is where they
    // will look for it.
    final widthFactor = ref.watch(widthFactorProvider);

    // Read off the MediaQuery, not through an `OrientationBuilder`.
    //
    // That widget is a `LayoutBuilder` — it derives the orientation from its
    // own constraints — and this screen asks it a question it does not need
    // layout to answer: the body fills the window, so the window's own
    // orientation is the same one. What that bought is a `LayoutBuilder`
    // wrapped around the whole reader, which runs the builds of everything
    // under it *during layout*: the pages, the tap zones, the chrome, the
    // scrubber, every image arriving and every setState the Slider makes. It
    // is also the widget both of the framework assertions this screen was
    // dying on named — `debugNeedsLayout` and
    // `_debugRelayoutBoundaryAlreadyMarkedNeedsLayout`, thrown from
    // `scheduleLayoutCallback`, after which its Scaffold laid out a body it
    // had never been handed. A `MediaQuery` dependency rebuilds this screen
    // in the ordinary build phase instead, which is where a rebuild belongs.
    final orientation = MediaQuery.orientationOf(context);
    // Landscape shows a two-page spread, but only when paging — and which
    // pages actually share a screen is the layout's call, since a scan that
    // is already a double page takes one on its own.
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
            widthFactor: widthFactor,
            imageBuilder: _pageImage,
            // The rail is part of the chrome: it is built with it and hidden
            // with it, the same bargain the strip and the slider strike (#52).
            railVisible: _showChrome,
            onPageChanged: (page, decodeWidth) =>
                _onPageChanged(page, chapter, precacheWidth: decodeWidth),
          )
        else
          _PagedView(
            key: ValueKey('paged-${spread != null}-$rtl'),
            pages: chapter.pages,
            page: _page,
            reverse: rtl,
            spread: spread,
            magnify: magnify,
            aspectRatioFor: chapter.aspectRatioFor,
            imageBuilder: _pageImage,
            // The span of the page being *arrived at*, which is not the
            // one the screen has been showing.
            onPageChanged: (page) =>
                _onPageChanged(page, chapter, span: spread?.spanOf(page) ?? 1),
          ),

        // Tap zones: 30 / 40 / 30. The sides page, the middle toggles
        // chrome; which way a side reads is the direction's, so right-to-left
        // passes them the other way round.
        if (!direction.isVerticalScroll)
          _TapZones(
            onLeft: () => _step(rtl, chapter, spread),
            onRight: () => _step(!rtl, chapter, spread),
            onMiddle: () => _showChromeAndBars(!_showChrome),
          )
        else
          _TapZones(onMiddle: () => _showChromeAndBars(!_showChrome)),

        if (_showChrome) ...[
          _TopChrome(
            title: chapter.title.isNotEmpty
                ? chapter.title
                : chapter.seriesName,
            settings: _PictureSettings(
              direction: resolved,
              libraryName: libraryName,
              onOutcome: (outcome) =>
                  _onSettingsOutcome(outcome, chapter, direction),
            ),
          ),
          _BottomChrome(
            chapter: chapter,
            page: _page,
            span: span,
            rtl: rtl,
            showStrip: !direction.isVerticalScroll,
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
  }

  /// Where in [page] a book is opened, or null for a page opened at its top.
  BookAnchor? _anchorFor(int page) => _anchors[page];

  /// The reader has come to rest [at] in [page]: where that page is opened
  /// next time, and what travels to the server with its number.
  ///
  /// A page other than the one being read is not reading — the page beside
  /// it is built before it is turned to, and a scroll settled there is not a
  /// place the reader has come to.
  void _onBookScrolled(int page, BookAnchor at, ChapterInfo chapter) {
    if (page != _page) return;
    _anchors[page] = at;
    _saveProgress(page, chapter);
  }

  /// Opens a book where the reader left it, once.
  ///
  /// Asked of the server rather than taken from the route, because the two
  /// ways in do not say the same thing: the series screen names a page and a
  /// link names none, so a book opened from a link would otherwise open at
  /// its first page while the place it was left at belongs to another one.
  /// Where the server was not asked, or has nothing recorded, a book opens
  /// at the page the route named and at the top of it.
  void _openBook(ChapterInfo chapter) {
    if (_opened) return;
    _opened = true;
    final progress = chapter.progress;
    if (progress == null) return;
    // A book read to its end is remembered at the page *past* it, which is
    // not a page it has — Kavita marks a chapter read at `pagesRead >=
    // pages` — so the last page is where it opens.
    _page = progress.pageNum.clamp(0, chapter.pages - 1);
    final anchor = BookAnchor.from(progress.bookScrollId);
    if (anchor != null) _anchors[_page] = anchor;
  }

  /// A chapter of words, read a page at a time.
  ///
  /// The pages are the server's, and it is the server that turns them: one
  /// page per screen, handed over as HTML (ADR-0008). So a book is paged like
  /// an image chapter and by the same two gestures, but none of what the
  /// picture reader is built on is asked of it — there is no page to measure,
  /// so there is no direction to detect, no spread to pair, and no page
  /// pictures to fill a strip with. What the bar's cog offers instead is how
  /// the book is set: a text size and a line spacing (#75), both the reader's
  /// own and both one number for every book.
  Widget _buildBookReader(BuildContext context, ChapterInfo chapter) {
    _openBook(chapter);
    _saveInitialProgress(chapter);
    // What the book is made of, as only the server can say: it read the
    // file's own navigation, and no client can reconstruct the shape of a
    // book from the pages it was laid out into. Watched here rather than by
    // the sheet it fills, because whether there is a list at all is what
    // decides whether the reader offers one.
    final contents =
        ref.watch(bookContentsProvider(widget.chapterId)).value ??
        const <BookContentsEntry>[];
    // The pages either side of this one are asked for **now**, while they are
    // not being read. `PageView.builder` mounts a page as late as it can — the
    // neighbour the moment a drag begins — so a page asked for only when it is
    // mounted is a page fetched under the reader's finger, and what is drawn
    // while it comes is a spinner over the whole screen. Asking while the
    // reader is at rest puts the wait where nobody is watching it.
    //
    // Watching them is also what keeps them. `bookPageProvider` is
    // autoDispose, so a page the pager has unmounted is a page forgotten and
    // asked for again on the way back to it — reading back one page used to
    // re-fetch it. A provider something is watching is not disposed, so the
    // two beside this one stay in hand and the rest of the book is still
    // forgotten with the screen, which is the point of the family.
    for (var near = _page - 1; near <= _page + 1; near++) {
      if (near < 0 || near >= chapter.pages || near == _page) continue;
      ref.watch(bookPageProvider((chapterId: widget.chapterId, page: near)));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _BookView(
          chapterId: widget.chapterId,
          pages: chapter.pages,
          page: _page,
          anchorFor: _anchorFor,
          picture: _bookPicture,
          onPageChanged: (page) => _onPageChanged(page, chapter),
          onScrolled: (page, at) => _onBookScrolled(page, at, chapter),
        ),
        _TapZones(
          onLeft: () => _goTo(_page - 1, chapter),
          onRight: () => _goTo(_page + 1, chapter),
          onMiddle: () => _showChromeAndBars(!_showChrome),
        ),
        if (_showChrome) ...[
          _TopChrome(
            // What the bar names is the book: `chapter-info` says the
            // series' name, and the file's own title is on the page it is
            // reading.
            title: chapter.title,
            settings: const _BookSettings(),
          ),
          _BottomChrome(
            chapter: chapter,
            page: _page,
            span: 1,
            rtl: false,
            showStrip: false,
            thumbQueue: _thumbs,
            thumbProvider: null,
            onSeek: (page) => _goTo(page, chapter),
            // A book with no contents offers none, and says nothing about
            // the absence: no control for one, and no sheet explaining it.
            onContents: contents.isEmpty
                ? null
                : () => _showContents(chapter, contents),
          ),
        ],
      ],
    );
  }

  /// The contents of the book being read, and what choosing one of them does.
  ///
  /// Choosing an entry is a jump to the page the server named for it, and
  /// progress is reported for that page exactly as it is for one turned to by
  /// hand — a reader who has moved to a chapter has read their way to the
  /// place it begins, and the server's own record is what opens the book
  /// there next time (#72).
  ///
  /// The chrome goes when a choice is made, as it does for the cog's sheet:
  /// what the reader came to the bar for is behind them.
  Future<void> _showContents(
    ChapterInfo chapter,
    List<BookContentsEntry> contents,
  ) async {
    final page = await showBookContentsSheet(context, entries: contents);
    if (!mounted || page == null) return;
    _goTo(page, chapter);
    _showChromeAndBars(false);
  }

  /// What a picture a book's page refers to is drawn with.
  ///
  /// A page names its pictures the way the file does — a path inside the
  /// book — and the server is what turns that name into bytes. A page that
  /// already carries a whole address is left to it, **including one with no
  /// scheme in it**: Kavita writes those (`//host/api/Book/…?file=cover.jpg`)
  /// and the scheme is the server's own, so it is completed from the address
  /// this session was built with. Handing one to `book-resources` as though
  /// it were a path inside the book answers 400, and a page whose only block
  /// is that picture is then drawn as nothing at all.
  Widget _bookPicture(String src) {
    // A page that came from a stored copy carries its pictures with it: the
    // bytes are in the name itself, since there is no server left to fetch
    // one from (ADR-0009). Decoded once and kept, because `Image.memory` is
    // its own cache key: a new list on every build is a new picture for the
    // decoder, and reading a saved book rebuilds its page often.
    final carried = _carried.putIfAbsent(src, () => carriedPictureBytes(src));
    if (carried != null) {
      return Image.memory(
        carried,
        // The width of the column of words it sits in, and its own height
        // from that: a picture in a page of a book is as wide as the page's
        // text.
        width: double.infinity,
        fit: BoxFit.fitWidth,
      );
    }
    final client = _client;
    if (client == null) return const SizedBox.shrink();
    final url = client.bookPictureUrl(widget.chapterId, src);
    return Image(
      image: CachedNetworkImageProvider(
        url,
        // Without a key of its own the URL files this picture under the
        // profile that fetched it (`imageCacheKey`).
        cacheKey: imageCacheKey(url),
        headers: client.imageHeaders,
      ),
      width: double.infinity,
      fit: BoxFit.fitWidth,
    );
  }

  /// The bytes of the pictures the pages being read carry, by the name the
  /// page gave them. See [_bookPicture]. Dies with the chapter.
  final Map<String, Uint8List?> _carried = {};

  /// What the cog's sheet asked for, whichever chapter it was opened on.
  void _onSettingsOutcome(
    ReaderSettingsOutcome outcome,
    ChapterInfo chapter,
    ReadingDirection direction,
  ) {
    switch (outcome) {
      case DirectionPicked(direction: final chosen):
        // A direction picked here is this series' own from now on, and the
        // chain answers with it from the next frame — nothing is held in
        // memory that a write does not back.
        ref
            .read(seriesDirectionsProvider.notifier)
            .set(chapter.seriesId, chosen);
      case DirectionPromotedToLibrary():
        // What is in force becomes this library's, so every series shelved
        // with it opens this way — the one tap that puts a library the guess
        // gets wrong right. The series' own direction stays above it: one
        // tap, one thing.
        ref
            .read(libraryDirectionsProvider.notifier)
            .set(chapter.libraryId, direction);
      case LibraryDirectionCleared():
        ref.read(libraryDirectionsProvider.notifier).clear(chapter.libraryId);
      case SeriesDirectionCleared():
        ref.read(seriesDirectionsProvider.notifier).clear(chapter.seriesId);
    }
    _showChromeAndBars(false);
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
    // A page that keeps the picture it has: the width it is decoded at is part
    // of the picture's cache key, so a width change asks for a new one, and a
    // page that blanked while it arrived blinked through the whole gesture.
    return PageImage(
      image: provider,
      fit: fit,
      alignment: alignment,
      explain: _serverIsPreparing,
    );
  }

  /// Kavita rasterises a PDF into page images on the first request for it, so
  /// the first page of one can be slow enough that a bare spinner reads as a
  /// hang. Every later page comes from its cache.
  ///
  /// Mirrored out of [build], where the chapter info is already watched, for
  /// the same reason as [_savedChapter]: the page builder is called from a
  /// sliver's item builder, which runs *during layout*, and a provider read
  /// there is a read during layout.
  var _serverIsPreparing = false;
}

class _PagedView extends StatefulWidget {
  const _PagedView({
    super.key,
    required this.pages,
    required this.page,
    required this.reverse,
    required this.spread,
    required this.magnify,
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
  final bool magnify;

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

  int get _itemCount => widget.spread?.length ?? widget.pages;

  int _viewIndex(int page) => widget.spread?.indexOf(page) ?? page;
  int _firstPageOf(int viewIndex) =>
      widget.spread?.firstOf(viewIndex) ?? viewIndex;

  @override
  void initState() {
    super.initState();
    _reported = widget.page;
  }

  /// True while the view is being moved from here rather than by a finger.
  ///
  /// `jumpToPage` dispatches its scroll notification **synchronously**, and
  /// `PageView` turns that into `onPageChanged` — so a jump made from
  /// [didUpdateWidget], which runs inside a build, reports a page change from
  /// inside that build. Landscape is where it bites: the view reports the
  /// *first* page of the spread it landed on, which for a seek to an odd page
  /// is not the page that was asked for, so the reader took it for a real page
  /// turn and called `setState` in the middle of the build that had just
  /// delivered the seek. The error widget replaced the Scaffold's body, and
  /// the rest of that frame died on the Scaffold being handed a body it had
  /// never laid out.
  ///
  /// A page the reader asked for is not news to the reader, so it is not
  /// reported back.
  var _seeking = false;

  @override
  void didUpdateWidget(_PagedView old) {
    super.didUpdateWidget(old);
    // A seek from the slider, a tap zone or the scrubber: follow it.
    if (widget.page != _reported) {
      _reported = widget.page;
      final target = _viewIndex(widget.page);
      if (_controller.hasClients && _controller.page?.round() != target) {
        _seeking = true;
        try {
          _controller.jumpToPage(target);
        } finally {
          _seeking = false;
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The page, magnifiable — by the drag gesture when it is on, and by the
  /// usual pinch when it is not. Never both: they would be two recognisers
  /// competing for the same one-finger drag.
  Widget _zoomable(List<double> aspectRatios, Widget child) => widget.magnify
      ? _MagnifyPage(aspectRatios: aspectRatios, child: child)
      : InteractiveViewer(maxScale: 5, child: child);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      reverse: widget.reverse,
      // Magnifying owns the one-finger drag, so the swipe that turns a page
      // has to give it up — the tap zones are what turn pages in that mode.
      // Two recognisers cannot share one drag, and letting them fight would
      // make both unreliable rather than making either work.
      physics: widget.magnify ? const NeverScrollableScrollPhysics() : null,
      itemCount: _itemCount,
      onPageChanged: (index) {
        if (_seeking) return;
        _reported = _firstPageOf(index);
        widget.onPageChanged(_reported);
      },
      itemBuilder: (context, index) {
        final spread = widget.spread;
        if (spread == null) {
          final page = _firstPageOf(index);
          return _zoomable([
            widget.aspectRatioFor(page),
          ], widget.imageBuilder(page));
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

/// One magnifiable page: a one-finger drag magnifies it around the point
/// pressed, and letting go returns it to the page.
///
/// The gesture's rules are all in [MagnifyGesture], which is a pure function of
/// the viewport, where the artwork sits and where the finger is. This widget
/// only measures the first two, feeds it the third, and animates the way back.
class _MagnifyPage extends StatefulWidget {
  const _MagnifyPage({required this.aspectRatios, required this.child});

  /// The aspect ratio of each page sharing this screen, in drawing order.
  final List<double> aspectRatios;
  final Widget child;

  @override
  State<_MagnifyPage> createState() => _MagnifyPageState();
}

class _MagnifyPageState extends State<_MagnifyPage>
    with SingleTickerProviderStateMixin {
  /// Letting go returns the page rather than snapping it back: a cut from
  /// 2.5x to the whole page loses the reader their place on it.
  static const _releaseDuration = Duration(milliseconds: 180);

  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: _releaseDuration,
  )..addListener(_onReleaseTick);

  MagnifyGesture? _gesture;
  MagnifyTransform? _shown;

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
  MagnifyTransform? _from;
  MagnifyTransform? _to;

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
        _shown = MagnifyTransform.lerp(from, to, t);
      }
    });
  }

  void _onStart(DragStartDetails details, Size viewport) {
    _release.stop();
    final gesture = MagnifyGesture(
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
    _to = MagnifyTransform.rest(from.content);
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

/// Reports the page now being read, and the width the strip decodes its
/// pages at.
///
/// The width comes along because the reader warms the page after the one
/// being read, and has to ask for it at the width the strip draws it at:
/// `ResizeImage` puts that width in its cache key, and a page warmed at one
/// width and drawn at another is two images — one decoded for nothing.
typedef StripPageChanged = void Function(int page, int decodeWidth);

class _VerticalScrollView extends StatefulWidget {
  const _VerticalScrollView({
    super.key,
    required this.chapter,
    required this.page,
    required this.widthFactor,
    required this.imageBuilder,
    required this.railVisible,
    required this.onPageChanged,
  });

  final ChapterInfo chapter;
  final int page;

  /// How wide the strip is laid out, as a fraction of the width it is given.
  /// `1.0` is the whole screen.
  final double widthFactor;
  final PageImageBuilder imageBuilder;

  /// Whether the reader's chrome is up, which is when the rail is built:
  /// vertical reading's seek control, in place of the thumbnail strip and
  /// its slider (#52). Nothing the rail does exists while it is not.
  final bool railVisible;
  final StripPageChanged onPageChanged;

  @override
  State<_VerticalScrollView> createState() => _VerticalScrollViewState();
}

class _VerticalScrollViewState extends State<_VerticalScrollView> {
  final _controller = ScrollController();
  late int _reported = widget.page;
  double _pixelRatio = 1;

  /// The strip's width, and the two hands that change it: one owner for the
  /// number, the geometry every offset is derived from, and every pointer
  /// over the strip.
  ///
  /// It opens at the preference (#49). A pinch moves it for the chapter in
  /// hand and writes nothing, which is why the number it holds is not the
  /// preference's to keep.
  late final StripWidthController _width = StripWidthController(
    scroll: _controller,
    widthFactor: widget.widthFactor,
  )..addListener(_onWidthChanged);

  /// Whether the strip has been scrolled to the page it was opened at.
  var _placed = false;

  /// True while this view is moving itself rather than being scrolled.
  ///
  /// A move it asked for is not a page turn, which is the rule the paged view
  /// keeps for its own seeks: [_onScroll] would otherwise report the page the
  /// strip landed on as though the reader had read their way there.
  var _seeking = false;

  /// The width or the chapter changed under the strip: it is laid out again,
  /// and where it landed is a fact rather than a page turn.
  ///
  /// A pinch or a width change moves the strip without anybody reading their
  /// way there — the place held is the one under the fingers, or the top of
  /// the screen, so the rest of the screen is a different page than it was —
  /// and what it lands on is not progress.
  void _onWidthChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_width.pinching) _syncReported();
  }

  /// Where the strip is, as a fact and not as a page turn.
  void _syncReported() {
    if (!_controller.hasClients || _width.geometry.pages == 0) return;
    _reported = _pageAt(_controller.offset);
  }

  int _pageAt(double offset) {
    // The page occupying the upper third of the viewport is "current".
    final probe = offset + _controller.position.viewportDimension * 0.3;
    return _width.geometry.pageAt(probe);
  }

  void _onScroll() {
    // Until the strip has been placed it is sitting at offset 0, which is not
    // where the reader is: reporting from there would post page 0 back and
    // wipe the place the chapter was opened at. And while two fingers are
    // holding the width, what the strip is showing is what they are holding,
    // not a page the reader has read their way to.
    if (!_placed ||
        _seeking ||
        _width.pinching ||
        // A rotation: the strip is still sitting at the offset it had before
        // the canvas was turned, and every height around it has changed.
        // What is under the top of the screen in that window is not where
        // the reader is, and posting it would move their place for them.
        _width.resizing ||
        !_controller.hasClients ||
        _width.geometry.pages == 0) {
      return;
    }
    final page = _pageAt(_controller.offset);
    if (page != _reported) {
      _reported = page;
      widget.onPageChanged(page, _width.decodeWidth(_pixelRatio));
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

  /// Puts the strip on [page], at the top of it.
  void _jumpTo(int page) {
    if (page >= _width.geometry.pages) return;
    // Clamped by the strip's own geometry, which is where every other move of
    // this strip is clamped: `maxScrollExtent` is the last frame's extent.
    //
    // The strip is being moved from here, which is the reader's build, so the
    // notification the jump dispatches synchronously is gagged — the rail
    // listens to the same controller, and a seek asked for by the reader is
    // not news (it is covered by the build that follows), where a rebuild
    // from inside this build is what this screen has already died on (#52).
    _seeking = true;
    try {
      _width.jumpToAnchor(StripAnchor(page, 0));
    } finally {
      _seeking = false;
    }
  }

  /// A seek the rail asked for: the strip lands on the top of [page], and
  /// the reader is told the way it is told any other page change.
  ///
  /// That includes the page it is already on: a rail touch is a seek, and a
  /// seek lands at the top of the page asked for either way (#52), so a
  /// finger on the rail snaps a mid-page scroll to the page's top rather
  /// than confirming it — the reader, whose `_page` has not moved, simply
  /// hears about nothing.
  void _railSeek(int page) {
    if (page < 0 || page >= _width.geometry.pages) return;
    _reported = page;
    _jumpTo(page);
    widget.onPageChanged(page, _width.decodeWidth(_pixelRatio));
  }

  @override
  void didUpdateWidget(_VerticalScrollView old) {
    super.didUpdateWidget(old);
    final seeked = widget.page != _reported;
    if (seeked) _reported = widget.page;
    if (widget.widthFactor != old.widthFactor) {
      // A seek made in the same breath wins: the strip is put on that page
      // first, and the width that follows holds where it landed.
      if (seeked) _jumpTo(widget.page);
      _seeking = true;
      // The preference, which is the only width that is ever written: it
      // drops whatever the last pinch left, the way leaving the chapter and
      // coming back does (#50). The place is put back by the width change
      // itself, in the same turn, and not reported: a width is not the
      // reader moving.
      _width.openingWidthFactor = widget.widthFactor;
      _seeking = false;
    } else if (seeked) {
      // A seek from the slider: jump, unless this is our own report echoing.
      _jumpTo(widget.page);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _width.removeListener(_onWidthChanged);
    _width.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolved here and not where it is used, for the reason the thumbnail
    // strip's decode width is: what uses it is the strip's item builder,
    // which a lazy sliver runs *during* layout, and a `MediaQuery` read
    // there would enrol this element as its dependent in the middle of one.
    _pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measured in the layout, the only place the width is known. The
        // controller decides whether the geometry is stale, because a pinch
        // has already rebuilt it in the turn that moved it and the layout
        // that follows must not build it twice.
        _width.measure(
          screenWidth: constraints.maxWidth,
          pages: widget.chapter.pages,
          aspectRatioFor: widget.chapter.aspectRatioFor,
          identity: widget.chapter,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            StripWidthGestures(
              controller: _width,
              child: CustomScrollView(
                controller: _controller,
                slivers: <Widget>[
                  // A continuous strip: no gaps and no page turns, and every
                  // page's extent known before it is built, so the offsets it
                  // is scrolled to are the offsets it is drawn at.
                  StripExtentList(
                    geometry: _width.geometry,
                    // Nothing in here reads an inherited widget or a
                    // provider: a lazy sliver builds its children *during*
                    // layout, and this screen has already died on both. The
                    // decode width is the width the page is drawn at, so
                    // narrowing the strip does not go on decoding pages at
                    // full size — the width it settled at, which a live
                    // pinch does not move.
                    itemBuilder: (context, page) => widget.imageBuilder(
                      page,
                      fit: BoxFit.fitWidth,
                      cacheWidth: _width.decodeWidth(_pixelRatio),
                    ),
                  ),
                ],
              ),
            ),
            // The rail: the chrome's seek control along the axis the chapter
            // scrolls, which replaces the paged directions' strip and slider
            // (#52). A chapter of one page has nowhere to seek to, so none
            // is built for it — the same rule the vertical chrome keeps for
            // its silhouette.
            if (widget.railVisible && _width.geometry.pages > 1)
              PageRail(
                geometry: _width.geometry,
                controller: _controller,
                // The chrome the rail runs between: measured where the bars
                // themselves are drawn, so a change to either bar is a
                // change to the bar alone.
                topGap: _TopChrome.barHeight,
                bottomGap: _BottomChrome.barHeight,
                onSeek: _railSeek,
                // The controller's moves the rail must not rebuild itself
                // from: a seek or a width change is being reported from
                // inside the reader's build, and the build that follows
                // carries where the strip landed.
                seeking: () => _seeking,
              ),
          ],
        );
      },
    );
  }
}

// --- a book -----------------------------------------------------------------

/// A chapter of words, one page of the server's per screen.
///
/// The same pager the picture reader uses, and the same two ways of turning a
/// page — a swipe, and a tap on a side — because what changes is what a page
/// is, not what reading one feels like. Nothing else the paged view does
/// carries over: no page has a size, so there is no spread in landscape and
/// no magnification, and a page longer than the screen is scrolled by the
/// page's own view rather than by the reader.
class _BookView extends StatefulWidget {
  const _BookView({
    required this.chapterId,
    required this.pages,
    required this.page,
    required this.anchorFor,
    required this.picture,
    required this.onPageChanged,
    required this.onScrolled,
  });

  final int chapterId;
  final int pages;
  final int page;

  /// Where in [page] the reader was, or null for a page opened at its top.
  /// Asked for as a page is built rather than held here, because the place a
  /// reader is in a page changes under the view.
  final BookAnchor? Function(int page) anchorFor;

  /// What a picture a page refers to is drawn with. Passed in rather than
  /// read from a provider, because a page is built by the pager's item
  /// builder — which a lazy list runs *during layout*.
  final Widget Function(String src) picture;

  final ValueChanged<int> onPageChanged;

  /// How far into [page] the reader has come to rest.
  final void Function(int page, BookAnchor at) onScrolled;

  @override
  State<_BookView> createState() => _BookViewState();
}

class _BookViewState extends State<_BookView> {
  late final PageController _controller = PageController(
    initialPage: widget.page,
  );

  /// The page this view last told the reader about. See
  /// [_PagedViewState._reported], whose trap this is too: a `late` field
  /// would initialise at the comparison in [didUpdateWidget], where the page
  /// is already the one being tested against.
  late int _reported;

  @override
  void initState() {
    super.initState();
    _reported = widget.page;
  }

  /// True while the view is being moved from here rather than by a finger.
  ///
  /// `jumpToPage` reports the page it lands on **synchronously**, from inside
  /// the build that asked for the jump — and a page the reader asked for is
  /// not news to the reader.
  var _seeking = false;

  @override
  void didUpdateWidget(_BookView old) {
    super.didUpdateWidget(old);
    if (widget.page == _reported) return;
    _reported = widget.page;
    if (!_controller.hasClients) return;
    if (_controller.page?.round() == widget.page) return;
    _seeking = true;
    try {
      _controller.jumpToPage(widget.page);
    } finally {
      _seeking = false;
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
      itemCount: widget.pages,
      onPageChanged: (page) {
        if (_seeking) return;
        _reported = page;
        widget.onPageChanged(page);
      },
      itemBuilder: (context, page) => _BookPage(
        chapterId: widget.chapterId,
        page: page,
        picture: widget.picture,
        anchor: widget.anchorFor(page),
        onScroll: (at) => widget.onScrolled(page, at),
      ),
    );
  }
}

/// One page of a book, set the way whoever is reading chose.
///
/// A page is a family of its own rather than one document holding them all, so
/// the reader asks for the page it is on and no other: a book is as long as
/// the server says it is, and a reader asking for all of it at once is a
/// reader asking for the whole book to be laid out before a word of it is
/// read. **And the two beside it, while it is at rest on this one** — see
/// [_buildBookReader], which is where that is asked for and why.
///
/// The three settings are watched **here** rather than by the reader above,
/// so moving a slider or picking a face rebuilds the page it is changing and
/// nothing else — not the pager, not the chrome, not the bar. And it is the
/// page that carries the reader's place across the reflow, so changing the
/// face asks the server for nothing.
class _BookPage extends ConsumerWidget {
  const _BookPage({
    required this.chapterId,
    required this.page,
    required this.picture,
    required this.anchor,
    required this.onScroll,
  });

  final int chapterId;
  final int page;
  final Widget Function(String src) picture;

  /// Where in the page the reader was, or null for a page that opens at its
  /// top: a page turned to is arrived at at its beginning.
  final BookAnchor? anchor;

  /// How far down the page the reader has come to rest.
  final ValueChanged<BookAnchor> onScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(
      bookPageProvider((chapterId: chapterId, page: page)),
    );
    final textSize = ref.watch(bookTextSizeProvider);
    final lineHeight = ref.watch(bookLineHeightProvider);
    final face = ref.watch(bookReadingFaceProvider);
    return switch (content) {
      // Nothing to show, and nothing coming: a page the server could not
      // produce says so instead of being read as a page with no words in it.
      AsyncError() => const BookPageUnavailable(),
      AsyncData(:final value) => BookPageBody(
        page: value,
        picture: picture,
        textSize: textSize,
        lineHeight: lineHeight,
        face: face,
        anchor: anchor,
        onScroll: onScroll,
      ),
      _ => const Center(child: CircularProgressIndicator(color: patraAccent)),
    };
  }
}

/// The three zones a tap can land in: the sides turn the page, the middle
/// brings the chrome up and takes it away again. 30 / 40 / 30.
///
/// The two sides are named for where they are, not for what they do: which of
/// them reads on is the reading direction's business (`_step`), and a
/// right-to-left chapter mirrors them by passing the callbacks the other way
/// round rather than by mirroring them here — a second mirror would undo the
/// first.
///
/// A direction that scrolls has no sides to turn, so it passes the middle
/// alone — and then the middle is the whole screen, because a strip that
/// scrolls has to be tappable anywhere on it.
class _TapZones extends StatelessWidget {
  const _TapZones({this.onLeft, this.onRight, required this.onMiddle});

  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback onMiddle;

  Widget _zone(VoidCallback? onTap) =>
      GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    if (onLeft == null || onRight == null) {
      return Positioned.fill(child: _zone(onMiddle));
    }
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(flex: 30, child: _zone(onLeft)),
          Expanded(flex: 40, child: _zone(onMiddle)),
          Expanded(flex: 30, child: _zone(onRight)),
        ],
      ),
    );
  }
}
// --- chrome -----------------------------------------------------------------

/// What the cog in the top bar opens: the sheet for what is being read, and
/// what to do with the answer it comes back with.
///
/// There are two sheets, and which one a chapter gets is decided by what the
/// chapter is made of. A chapter of pictures has a direction to choose, a
/// library to promote it to and a width to open at; a book has the size of
/// its words and the room between its lines, and nothing else (#75) — so the
/// two are one cog and two answers rather than two cogs.
sealed class _ReaderSettings {
  const _ReaderSettings();
}

/// The sheet for a chapter of pictures: the direction in force, the library a
/// promotion would be written against, and what to do with the answer.
final class _PictureSettings extends _ReaderSettings {
  const _PictureSettings({
    required this.direction,
    required this.libraryName,
    required this.onOutcome,
  });

  final ChapterDirection direction;

  /// What the library this chapter is shelved in is called, for the sheet's
  /// rows: empty where the server's list has not reached the device yet.
  final String libraryName;

  /// What the sheet came back with, once it has closed. Not everything a
  /// chapter's sheet changes comes back this way — the width is written
  /// straight through, the way a book's two settings are.
  final ValueChanged<ReaderSettingsOutcome> onOutcome;
}

/// The sheet for a book, which offers how the book is set and nothing about
/// pictures. It has nothing to report: both of its settings are written
/// straight through to the person reading.
final class _BookSettings extends _ReaderSettings {
  const _BookSettings();
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({required this.title, this.settings});

  /// How far the bar reaches down the screen, in points — what the rail
  /// starts below (`page_rail.dart`), and the whole of the bar's geometry:
  /// `4pt` in front of a `48pt` row with `20pt` behind it. The rail never
  /// restates it; it reads it from here, which is what keeps a change of the
  /// bar a change of the bar alone.
  static const double barHeight = 4 + 48 + 20;

  final String title;

  /// What the cog opens, or null where there is nothing to offer: which sheet
  /// that is depends on what is being read — a chapter of pictures has a
  /// direction to choose, a book has the size of its words and the room
  /// between its lines (#75).
  final _ReaderSettings? settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = this.settings;
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
                if (settings != null) ...[
                  const SizedBox(width: 8),
                  _SettingsCog(
                    settings: settings,
                    tooltip: l10n.readerSettings,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one control in the top bar. What it opens depends on what is being
/// read: [showReaderSettingsSheet] for a chapter of pictures,
/// [showBookSettingsSheet] for a book — see [_ReaderSettings] for why the two
/// are one cog, and the sheet for why it is a cog rather than the direction
/// pill it replaced.
class _SettingsCog extends StatelessWidget {
  const _SettingsCog({required this.settings, required this.tooltip});

  final _ReaderSettings settings;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return ChromePill(
      tooltip: tooltip,
      // One glyph wide: the pill is a cog, and a pill is not a label.
      width: 44,
      padding: EdgeInsets.zero,
      onTap: () async {
        final outcome = await switch (settings) {
          _PictureSettings(:final direction, :final libraryName) =>
            showReaderSettingsSheet(
              context,
              direction: direction,
              libraryName: libraryName,
            ),
          // A book's sheet has nothing to report: what it changes, it
          // writes to the person reading as it is being changed.
          _BookSettings() => showBookSettingsSheet(context).then((_) => null),
        };
        // The sheet outlives the chrome it was opened from, so what it
        // reports may arrive with the cog already out of the tree.
        if (outcome == null || !context.mounted) return;
        switch (settings) {
          case _PictureSettings(:final onOutcome):
            onOutcome(outcome);
          case _BookSettings():
            return;
        }
      },
      child: const Icon(Icons.settings, size: 21, color: Colors.white),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.chapter,
    required this.page,
    required this.span,
    required this.rtl,
    required this.showStrip,
    required this.thumbQueue,
    required this.thumbProvider,
    required this.onSeek,
    this.onContents,
  });

  /// How far the chrome reaches up the screen, in points — roughly where
  /// the rail ends (`page_rail.dart`), which reads it from here rather than
  /// restating it: `28pt` of headroom, about `18pt` for the numerals' own
  /// line (13pt set at the source serif's height), `8pt` below, and a few
  /// points of air so a handle at the very end of the rail never rides the
  /// scrim. A book's chrome is the ten points taller by the contents control
  /// it may carry, and nothing measures it there: a book has no rail.
  static const double barHeight = 62.0;

  final ChapterInfo chapter;
  final int page;
  final int span;
  final bool rtl;

  /// Whether the scrubber is drawn: the thumbnail strip and the slider.
  ///
  /// Paging through pictures has one. Reading vertically has the rail
  /// instead, built against the edge of the screen the chapter scrolls along
  /// (`page_rail.dart`), and a book has no page pictures to scrub through at
  /// all — its pages are words the server laid out. Either way this chrome
  /// keeps the counter alone.
  final bool showStrip;
  final ThumbLoadQueue thumbQueue;

  /// Null where there is no strip to fill.
  final ImageProvider? Function(int page)? thumbProvider;
  final ValueChanged<int> onSeek;

  /// Opens the book's contents, or null where there are none to open: only a
  /// book is made of parts the server can name, and only a book it listed
  /// some for. Drawn beside the counter, which stays in the middle of the
  /// screen whatever the bar carries.
  final VoidCallback? onContents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Read into a local so the strip below can be told there is one to fill:
    // a field is not promoted, but a page of a book has no thumbnails to
    // give it.
    final thumbs = thumbProvider;
    // The same move for the contents: the row below wants the callback
    // rather than the promise of one.
    final contents = onContents;
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
                      // The thumbnail strip and the slider are the paged
                      // directions' seek control. Vertical reading's is the
                      // rail, built alongside this chrome against the right
                      // edge of the screen (see `page_rail.dart`), so the
                      // vertical chrome keeps the counter alone (#52), and a
                      // book's has nothing to show. A paged chapter of one
                      // page keeps the strip it has — this work leaves paged
                      // reading alone.
                      if (showStrip && thumbs != null) ...[
                        ThumbStrip(
                          pages: chapter.pages,
                          current: page,
                          queue: thumbQueue,
                          providerBuilder: thumbs,
                          onTap: onSeek,
                        ),
                        if (chapter.pages > 1)
                          Padding(
                            // The handle has to start and end where the
                            // strip's bulge does: the strip works out how
                            // far in that is.
                            padding: EdgeInsets.symmetric(
                              horizontal: ThumbStrip.sliderPadding(context),
                            ),
                            child: Slider(
                              value: page.toDouble().clamp(
                                0,
                                (chapter.pages - 1).toDouble(),
                              ),
                              max: (chapter.pages - 1).toDouble(),
                              divisions: chapter.pages - 1,
                              onChanged: (value) => onSeek(value.round()),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      // Whatever the bar carries, the counter is in the
                      // middle of the screen: the room beside it is matched
                      // on both sides, so a page number a reader looks for
                      // is where they found it last time.
                      const Spacer(),
                      Text(counter, style: PatraText.pageNumeral()),
                      Expanded(
                        child: contents == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: BookContentsButton(onTap: contents),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
