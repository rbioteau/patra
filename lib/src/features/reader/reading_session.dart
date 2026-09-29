import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../auth/session.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import 'reader_screen.dart';

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
