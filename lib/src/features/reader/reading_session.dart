import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/kavita_client.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import 'book_page.dart';
import 'reader_screen.dart';
import 'spread_layout.dart';

/// Where the chapter the reader reads was learnt from.
enum ChapterSource {
  /// `chapter-info` answered — with `book-info` and `get-progress` for a
  /// book.
  server,

  /// The server could not be asked, and the saved copy is what says what the
  /// chapter is and where it was left.
  copy,
}

/// The chapter the reader reads, and where that was learnt.
typedef ReaderChapter = ({ChapterInfo info, ChapterSource source});

/// The chapter the reader reads: the server's answer where there is one, and
/// the saved copy's word where the server cannot give one.
///
/// Loading while there is neither, and the server's error where it refused
/// and nothing is saved — which is a chapter the reader cannot open.
///
/// **A saved book waits for the server** unless the device already knows it
/// cannot answer: a book opens where the server says (#72), once, so opening
/// it off the copy first would spend that once on the copy and post the
/// copy's page back over the server's — the reader's own place, wiped by
/// reading on another device. Offline the first failure settles it — a retry
/// keeps the error it follows — and the copy's place is what opens (#128). A
/// chapter of pictures has no place within a page to lose, so its copy opens
/// at once.
final readerChapterProvider = Provider.autoDispose
    .family<AsyncValue<ReaderChapter>, int>((ref, chapterId) {
      final info = ref.watch(chapterInfoProvider(chapterId));
      if (info.value case final answered?) {
        return AsyncData((info: answered, source: ChapterSource.server));
      }
      final saved = ref.watch(savedChapterProvider(chapterId));
      final askingServer =
          info.isLoading &&
          !info.hasError &&
          saved?.content == ChapterContent.reflowable &&
          !ref.watch(offlineProvider);
      if (saved != null && !askingServer) {
        return AsyncData((info: _fromCopy(saved), source: ChapterSource.copy));
      }
      return switch (info) {
        AsyncError(:final error, :final stackTrace) => AsyncError(
          error,
          stackTrace,
        ),
        _ => const AsyncLoading(),
      };
    });

/// What the copy says of its chapter: enough to read it with no server at
/// all — and what it is made of is part of it, or a saved book would open in
/// the reader for pages that are pictures and show nothing.
ChapterInfo _fromCopy(SavedChapter saved) => ChapterInfo(
  seriesId: saved.seriesId,
  volumeId: saved.volumeId,
  libraryId: saved.libraryId,
  pages: saved.pages,
  seriesName: saved.seriesName,
  title: saved.title,
  seriesFormat: saved.format,
  language: saved.language,
  // Where the copy was left, which is what the server would have said: a
  // book opened on a train opens on the words it was closed at, as a
  // streamed one does (#128).
  progress: switch (saved.place ?? saved.pending) {
    final place? => ChapterProgress(
      pageNum: place.pageNum,
      bookScrollId: place.bookScrollId,
    ),
    null => null,
  },
);

/// Which reading session: the chapter, and the page the route opened it at —
/// which a book then sets aside for the place the server remembers.
typedef ReadingSessionKey = ({int chapterId, int initialPage});

/// A chapter as it is being read: where the reader is, and what the server
/// and the saved copy have been told of it.
///
/// Its state is the page on screen — the first of a spread — which is all the
/// reader draws from it. Everything that page is worth to anyone else happens
/// here, out of any widget's build:
///
/// - **It opens once.** A chapter of pictures at the page the route named; a
///   book where the server says (#72), with the place within that page, and
///   on its last page where the server remembers the page *past* it — which
///   is how Kavita keeps a book read to its end.
/// - **Reaching a page reports it**, the page itself on opening too, since a
///   pager reports none for the page it opens on. The last page is reported
///   as the chapter's total: Kavita marks a chapter read at `pagesRead >=
///   pages`, as its own web reader does.
/// - **The copy hears first** (#78): what is about to be posted is written
///   into the saved copy before it is sent, and cleared only where the answer
///   is for exactly what the copy holds, so a page turned while a post was in
///   flight is not lost by its answer. Posts go one at a time, so a slow one
///   cannot land after a later page's; a refused one is dropped, the copy
///   keeping it for `syncPendingProgress`.
/// - **A saved copy is put to the server's count once** (ADR-0009), where
///   the server answered and a copy is on the device.
/// - **While it lasts, its chapter goes first in the download queue**, and
///   stops going first when it ends.
class ReadingSession extends Notifier<int> {
  ReadingSession(this._key);

  final ReadingSessionKey _key;
  int get _chapterId => _key.chapterId;

  /// The chapter as last learnt — the server's answer replacing the copy's
  /// word when it comes — or null until there is one to read.
  ChapterInfo? _chapter;

  /// Where in each page of a book the reader is, by page: a page with no
  /// entry opens at its top, which is what turning to a page is.
  final _anchors = <int, BookAnchor>{};

  Future<void> _posts = Future.value();
  var _totalNoted = false;
  DownloadsNotifier? _downloads;

  @override
  int build() {
    ref.listen(readerChapterProvider(_chapterId), (_, next) {
      _learn(next.value);
    });
    ref.listen(savedChapterProvider(_chapterId), (_, _) => _later(_noteTotal));
    ref.onDispose(() => _downloads?.clearReadingChapterPriority(_chapterId));

    // Where the chapter is already known the session is born open, so the
    // reader's first frame is drawn at the right page rather than jumping to
    // it; what that is worth to anybody else waits until the build is over,
    // a provider being built being no place to change another.
    final known = ref.read(readerChapterProvider(_chapterId)).value;
    final page = known == null ? _key.initialPage : _open(known.info);
    _later(() {
      final downloads = ref.read(downloadsProvider.notifier);
      _downloads = downloads;
      downloads.prioritizeReadingChapter(_chapterId);
      if (known == null) return;
      _report(page);
      if (known.source == ChapterSource.server) _noteTotal();
    });
    return page;
  }

  /// Where in [page] a book is opened, or null for a page opened at its top.
  BookAnchor? anchorFor(int page) => _anchors[page];

  /// The pager has come to [page] by a gesture, with [span] pages on screen
  /// from it: what is reported is the last of them.
  void arrived(int page, {int span = 1}) {
    final chapter = _chapter;
    if (chapter == null || page == state) return;
    state = page;
    _report((page + span - 1).clamp(0, chapter.pages - 1));
  }

  /// A seek, or an entry of a book's contents: the page asked for, held to
  /// the chapter.
  void goTo(int page) {
    final chapter = _chapter;
    if (chapter == null) return;
    final clamped = page.clamp(0, chapter.pages - 1);
    if (clamped == state) return;
    state = clamped;
    _report(clamped);
  }

  /// A step is a screen, not a fixed number of pages: a double-page scan sits
  /// on one of its own, so stepping back from it lands on the *first* page of
  /// the pair before it rather than on the second.
  void step({required bool forward, required SpreadLayout? spread}) {
    if (spread == null) {
      goTo(state + (forward ? 1 : -1));
      return;
    }
    final index = spread.indexOf(state) + (forward ? 1 : -1);
    if (index < 0 || index >= spread.length) return;
    goTo(spread.firstOf(index));
  }

  /// A book's page has come to rest [at] a place: where it is opened next
  /// time, and what travels to the server with its number. A page other than
  /// the one being read is not reading — the page beside it is built before
  /// it is turned to, and a scroll settled there is not a place the reader
  /// has come to.
  void settled(int page, BookAnchor at) {
    if (page != state || _chapter == null) return;
    _anchors[page] = at;
    _report(page);
  }

  /// Takes in what the chapter now is; on the first answer, opens at it.
  ///
  /// The page moves at once, since the reader draws it next; what the move
  /// is worth to the server and the copy is sent once the notification is
  /// over — a listener runs while providers are being rebuilt, which is no
  /// place to read them, let alone to write one.
  void _learn(ReaderChapter? known) {
    if (known == null) return;
    if (_chapter == null) {
      final opened = _open(known.info);
      state = opened;
      _later(() => _report(opened));
    } else {
      _chapter = known.info;
    }
    if (known.source == ChapterSource.server) _later(_noteTotal);
  }

  /// Runs [effect] once the current notification or build is over, and not
  /// at all if the session has ended by then.
  void _later(void Function() effect) => Future.microtask(() {
    if (ref.mounted) effect();
  });

  /// Takes the chapter in and answers the page it opens at.
  int _open(ChapterInfo chapter) {
    _chapter = chapter;
    final progress = chapter.progress;
    if (chapter.content != ChapterContent.reflowable ||
        progress == null ||
        chapter.pages == 0) {
      return _key.initialPage;
    }
    final page = progress.pageNum.clamp(0, chapter.pages - 1);
    final anchor = BookAnchor.from(progress.bookScrollId);
    if (anchor != null) _anchors[page] = anchor;
    return page;
  }

  /// Puts the copy's page total to the server's own count, once.
  void _noteTotal() {
    if (_totalNoted) return;
    final known = ref.read(readerChapterProvider(_chapterId)).value;
    if (known == null || known.source != ChapterSource.server) return;
    if (ref.read(savedChapterProvider(_chapterId)) == null) return;
    _totalNoted = true;
    ref
        .read(downloadsProvider.notifier)
        .notePageTotal(_chapterId, known.info.pages);
  }

  void _report(int page) {
    final chapter = _chapter;
    if (chapter == null || chapter.pages == 0) return;
    final pageNum = page >= chapter.pages - 1 ? chapter.pages : page;
    // Where in the page the reader is, for a book whose page can be longer
    // than the screen: a page number alone opens it again at the top, which
    // is words already read. A chapter of pictures has no place within a
    // page to report.
    final anchor = chapter.content == ChapterContent.reflowable
        ? (_anchors[page] ?? BookAnchor.top).id
        : null;
    final pending = PendingProgress(pageNum: pageNum, bookScrollId: anchor);
    final downloads = ref.read(downloadsProvider.notifier);
    if (ref.read(savedChapterProvider(_chapterId)) != null) {
      downloads.recordProgress(_chapterId, pageNum, pending: pending);
    }
    final KavitaClient client;
    try {
      client = ref.read(kavitaClientProvider);
    } on StateError {
      return; // signed out mid-read
    }
    _posts = _posts
        .then((_) async {
          await client.saveProgress(
            libraryId: chapter.libraryId,
            seriesId: chapter.seriesId,
            volumeId: chapter.volumeId,
            chapterId: _chapterId,
            pageNum: pageNum,
            bookScrollId: anchor,
          );
          // Taken, so the copy has nothing left to send. Where the reader has
          // turned a page since, this is a no-op rather than a loss: the copy
          // is holding the newer one, and only that one is cleared.
          await downloads.clearPendingProgress(_chapterId, pending);
        })
        .catchError((Object _) {});
  }
}

final readingSessionProvider = NotifierProvider.autoDispose
    .family<ReadingSession, int, ReadingSessionKey>(ReadingSession.new);
