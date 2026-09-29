import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/features/reader/reading_session.dart';

/// The reading session, asked through its own interface: which chapter the
/// reader reads, where it opens, what reaching a page reports to the server
/// and to the copy, and what a step is — with no screen pumped.

const _chapterId = 7;

ChapterInfo _info({
  int pages = 10,
  MangaFormat format = MangaFormat.archive,
  ChapterProgress? progress,
}) => ChapterInfo(
  seriesId: 3,
  volumeId: 5,
  libraryId: 1,
  pages: pages,
  seriesName: 'Dune',
  title: 'Book one',
  seriesFormat: format,
  progress: progress,
);

SavedChapter _copy({
  MangaFormat format = MangaFormat.archive,
  PendingProgress? place,
  PendingProgress? pending,
}) => SavedChapter(
  chapterId: _chapterId,
  seriesId: 3,
  volumeId: 5,
  libraryId: 1,
  seriesName: 'Dune',
  title: 'Book one',
  pages: 10,
  bytes: 10,
  format: format,
  place: place,
  pending: pending,
);

/// A container where the server's answer about the chapter and the copy on
/// the device are what the test says, and nothing else is asked.
ProviderContainer _chapterContainer({
  required Future<ChapterInfo> Function() server,
  SavedChapter? copy,
  bool offline = false,
}) {
  final container = ProviderContainer.test(
    overrides: [
      chapterInfoProvider(_chapterId).overrideWith((ref) => server()),
      savedChapterProvider(_chapterId).overrideWithValue(copy),
    ],
  );
  if (offline) container.read(offlineProvider.notifier).set(true);
  return container;
}

/// Reads the provider until the server's answer, if any, has landed.
Future<AsyncValue<ReaderChapter>> _settled(ProviderContainer container) async {
  final sub = container.listen(readerChapterProvider(_chapterId), (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return sub.read();
}

void main() {
  group('the chapter the reader reads', () {
    test('is the server\'s answer where there is one', () async {
      final container = _chapterContainer(
        server: () async => _info(),
        copy: _copy(),
      );
      final chapter = (await _settled(container)).value!;
      expect(chapter.source, ChapterSource.server);
      expect(chapter.info.title, 'Book one');
    });

    test('is the copy where the server refuses', () async {
      final container = _chapterContainer(
        server: () async => throw Exception('refused'),
        copy: _copy(place: const PendingProgress(pageNum: 4)),
      );
      final chapter = (await _settled(container)).value!;
      expect(chapter.source, ChapterSource.copy);
      expect(chapter.info.pages, 10);
      // Where the copy was left is what the server would have said.
      expect(chapter.info.progress?.pageNum, 4);
    });

    test('a saved book waits for the server rather than spending the '
        'opening on the copy', () async {
      // A book opens once, where the server says (#72): opening it off the
      // copy first would post the copy's page back over the server's.
      final container = _chapterContainer(
        server: () => Completer<ChapterInfo>().future,
        copy: _copy(format: MangaFormat.epub),
      );
      expect((await _settled(container)).isLoading, isTrue);
    });

    test('offline, a saved book opens off the copy at once', () async {
      final container = _chapterContainer(
        server: () => Completer<ChapterInfo>().future,
        copy: _copy(format: MangaFormat.epub),
        offline: true,
      );
      final chapter = (await _settled(container)).value!;
      expect(chapter.source, ChapterSource.copy);
      expect(chapter.info.content, ChapterContent.reflowable);
    });

    test('a saved chapter of pictures does not wait for the server', () async {
      final container = _chapterContainer(
        server: () => Completer<ChapterInfo>().future,
        copy: _copy(),
      );
      expect((await _settled(container)).value?.source, ChapterSource.copy);
    });

    test('nothing to read is the server\'s error', () async {
      final container = _chapterContainer(
        server: () async => throw Exception('refused'),
      );
      final sub = container.listen(
        readerChapterProvider(_chapterId),
        (_, _) {},
      );
      addTearDown(sub.close);
      // The server's answer is retried twice inside ~600ms (`serverRetry`)
      // before it is one: loading until then, like the screen shows it.
      for (var i = 0; i < 100 && !sub.read().hasError; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(sub.read().hasError, isTrue);
    });
  });
}
