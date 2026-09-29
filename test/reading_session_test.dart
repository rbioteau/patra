import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/book_page.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/features/reader/reading_session.dart';
import 'package:patra/src/features/reader/spread_layout.dart';

import 'test_support.dart';

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

  group('the reading session', () {
    late Directory root;
    late _Server server;

    setUp(() {
      root = Directory.systemTemp.createTempSync('patra-reading-session');
      server = _Server();
    });
    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<ProviderContainer> open(
      ChapterInfo info, {
      int initialPage = 0,
      MangaFormat? saved,
    }) async {
      if (saved != null) {
        await saveChapterFixture(
          root,
          _profileId,
          chapterId: _chapterId,
          seriesId: 3,
          volumeId: 5,
          pages: 10,
          format: saved,
        );
      }
      final container = _sessionContainer(root, server, info);
      addTearDown(container.dispose);
      await container.read(downloadsProvider.future);
      final key = (chapterId: _chapterId, initialPage: initialPage);
      final sub = container.listen(readingSessionProvider(key), (_, _) {});
      addTearDown(sub.close);
      await _turns();
      return container;
    }

    ReadingSession session(
      ProviderContainer container, {
      int initialPage = 0,
    }) => container.read(
      readingSessionProvider((chapterId: _chapterId, initialPage: initialPage))
          .notifier,
    );
    int page(ProviderContainer container, {int initialPage = 0}) =>
        container.read(
          readingSessionProvider((
            chapterId: _chapterId,
            initialPage: initialPage,
          )),
        );

    test(
      'a chapter of pictures opens at the route\'s page, and says so',
      () async {
        final container = await open(_info(), initialPage: 3);
        expect(page(container, initialPage: 3), 3);
        // Once: a pager reports no page for the one it opens on, so a chapter
        // read on one page would otherwise record nothing at all.
        expect(server.posted, [(pageNum: 3, bookScrollId: null)]);
      },
    );

    test(
      'a chapter of pictures ignores a place the server remembers',
      () async {
        final container = await open(
          _info(progress: const ChapterProgress(pageNum: 6)),
          initialPage: 2,
        );
        expect(page(container, initialPage: 2), 2);
      },
    );

    test(
      'a book opens where the server says, not where the route does',
      () async {
        const place = BookAnchor.inBlock(4, .5);
        final container = await open(
          _info(
            format: MangaFormat.epub,
            progress: ChapterProgress(pageNum: 6, bookScrollId: place.id),
          ),
          initialPage: 0,
        );
        expect(page(container), 6);
        expect(session(container).anchorFor(6), place);
        // The place goes back with the page it was opened at.
        expect(server.posted, [(pageNum: 6, bookScrollId: place.id)]);
      },
    );

    test('a book read to its end opens on its last page', () async {
      // Kavita remembers a finished book at the page past it, which is not a
      // page it has.
      final container = await open(
        _info(
          format: MangaFormat.epub,
          progress: const ChapterProgress(pageNum: 10),
        ),
      );
      expect(page(container), 9);
      // And the last page reports the whole book: `pagesRead >= pages` is how
      // the server marks a chapter read.
      expect(server.posted.single.pageNum, 10);
    });

    test('arriving reports the last page on screen, and once', () async {
      final container = await open(_info());
      final reading = session(container);
      reading.arrived(4, span: 2);
      reading.arrived(4, span: 2);
      await _turns();
      expect(page(container), 4);
      expect(server.posted.map((p) => p.pageNum), [0, 5]);
    });

    test(
      'a jump is held to the chapter, and the last page is the total',
      () async {
        final container = await open(_info());
        session(container).goTo(40);
        await _turns();
        expect(page(container), 9);
        expect(server.posted.last.pageNum, 10);
      },
    );

    test('a step is a screen: a spread steps a pair at a time', () async {
      final info = _info();
      final container = await open(info);
      final spread = SpreadLayout.of(info);
      final reading = session(container);
      reading.step(forward: true, spread: spread);
      expect(page(container), 2);
      reading.step(forward: true, spread: null);
      expect(page(container), 3);
      reading.step(forward: false, spread: spread);
      expect(page(container), 0);
      // Nothing before the first screen.
      reading.step(forward: false, spread: spread);
      expect(page(container), 0);
    });

    test(
      'a book at rest is a place in its page, and only on the page read',
      () async {
        final container = await open(_info(format: MangaFormat.epub));
        final reading = session(container);
        const there = BookAnchor.inBlock(2, .25);
        // The page beside it is built before it is turned to: a scroll settled
        // there is not a place the reader has come to.
        reading.settled(1, there);
        await _turns();
        expect(reading.anchorFor(1), isNull);
        expect(server.posted, hasLength(1));

        reading.settled(0, there);
        await _turns();
        expect(reading.anchorFor(0), there);
        expect(server.posted.last, (pageNum: 0, bookScrollId: there.id));
      },
    );

    test('a copy holds a page before the server has it, and only what was '
        'sent is cleared', () async {
      final container = await open(_info(), saved: MangaFormat.archive);
      SavedChapter copy() => container.read(savedChapterProvider(_chapterId))!;
      await _turns();
      server.gates = [Completer<void>(), Completer<void>()];

      final reading = session(container);
      reading.arrived(4);
      await _turns();
      // Written into the copy before it is sent: a journey is not a hole in
      // what the server knows.
      expect(copy().pending?.pageNum, 4);

      reading.arrived(5);
      await _turns();
      expect(copy().pending?.pageNum, 5);

      // The first answer lands: the copy is holding the newer page, and that
      // one is not the one to clear.
      server.gates![0].complete();
      await _turns();
      expect(copy().pending?.pageNum, 5);

      server.gates![1].complete();
      await _turns();
      expect(copy().pending, isNull);
    });

    test('the server\'s count is put to the copy\'s, once', () async {
      final container = await open(
        _info(pages: 12),
        saved: MangaFormat.archive,
      );
      await _turns();
      expect(container.read(savedChapterProvider(_chapterId))!.serverPages, 12);
    });

    test(
      'a session born before the server answers opens when it does',
      () async {
        final answer = Completer<ChapterInfo>();
        final container = _sessionContainer(root, server, null, answer.future);
        addTearDown(container.dispose);
        const key = (chapterId: _chapterId, initialPage: 1);
        final sub = container.listen(readingSessionProvider(key), (_, _) {});
        addTearDown(sub.close);
        await _turns();
        expect(sub.read(), 1);
        expect(server.posted, isEmpty, reason: 'nothing is known to report');

        const place = BookAnchor.inBlock(2, .5);
        answer.complete(
          _info(
            format: MangaFormat.epub,
            progress: ChapterProgress(pageNum: 7, bookScrollId: place.id),
          ),
        );
        await _turns();
        expect(sub.read(), 7);
        expect(server.posted, [(pageNum: 7, bookScrollId: place.id)]);
      },
    );

    test(
      'a refused post is not an error, and the copy keeps the page',
      () async {
        server.refuses = true;
        final container = await open(_info(), saved: MangaFormat.archive);
        session(container).arrived(3);
        await _turns();
        expect(
          container.read(savedChapterProvider(_chapterId))!.pending?.pageNum,
          3,
        );
      },
    );
  });
}

const _profileId = 'https://kavita.test#1';

/// Lets queued writes and posts run.
Future<void> _turns() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// A Kavita that takes progress posts and nothing else, and remembers them.
class _Server implements HttpClientAdapter {
  final posted = <({int pageNum, String? bookScrollId})>[];

  /// Holds each post from now on open until its gate is completed, in
  /// order.
  List<Completer<void>>? get gates => _gates;
  set gates(List<Completer<void>>? gates) {
    _gates = gates;
    _answered = 0;
  }

  List<Completer<void>>? _gates;
  var _answered = 0;
  var refuses = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    if (options.path == '/api/Reader/progress') {
      final body = options.data as Map<String, dynamic>;
      posted.add((
        pageNum: body['pageNum'] as int,
        bookScrollId: body['bookScrollId'] as String?,
      ));
      final gates = _gates;
      final gate = gates != null && _answered < gates.length
          ? gates[_answered]
          : null;
      _answered++;
      if (gate != null) await gate.future;
      if (refuses) return ResponseBody.fromString('', 500);
      return ResponseBody.fromString(
        jsonEncode(const <String, dynamic>{}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromBytes(const [], 404);
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _sessionContainer(
  Directory root,
  _Server server,
  ChapterInfo? info, [
  Future<ChapterInfo>? answer,
]) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = server;
  client.bareHttpClient.httpClientAdapter = server;
  return ProviderContainer.test(
    overrides: [
      kavitaClientProvider.overrideWithValue(client),
      downloadsServiceProvider.overrideWithValue(
        DownloadsService(root: root, profileId: _profileId),
      ),
      chapterInfoProvider(_chapterId)
          .overrideWith((ref) => answer ?? Future.value(info)),
    ],
  );
}
