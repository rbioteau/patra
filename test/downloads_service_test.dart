import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/downloads/downloads_service.dart';

/// Serves fake page bytes, and can fail on a chosen page.
class _PageAdapter implements HttpClientAdapter {
  _PageAdapter({this.failOnPage});

  final int? failOnPage;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    final page = int.parse('${options.queryParameters['page']}');
    if (page == failOnPage) {
      return ResponseBody.fromBytes(const [], 500);
    }
    // Page n is n+1 bytes long, so sizes are distinguishable.
    return ResponseBody.fromBytes(
      List<int>.filled(page + 1, 7),
      200,
      headers: {
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

KavitaClient _client(HttpClientAdapter adapter) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;
  return client;
}

const _chapter = SavedChapter(
  chapterId: 42,
  seriesId: 7,
  volumeId: 3,
  libraryId: 1,
  seriesName: 'Blame!',
  title: 'Chapter 1',
  pages: 3,
  bytes: 0,
);

/// Two people on one server: the same chapter ids, and nothing else in
/// common.
const _romain = 'https://kavita.example#1';
const _lea = 'https://kavita.example#2';

/// The bytes of every picture a page of the book names: three of them, which
/// is not a picture any decoder would take and is all a stored page needs.
const _picture = [7, 8, 9];

/// One book, in the chapter the server hangs it on.
const _bookId = 7;

/// What the server says a page of the book is made of: words, and a picture
/// named the way the file names it. The first two pages name the same one,
/// which is the ordinary thing for a book to do.
String _bookPageHtml(int page) =>
    '<h1>Part ${page == 2 ? 'two' : 'one'}</h1>'
    '<p>The spice must flow.</p>'
    '<p><img src="OEBPS/images/${page == 2 ? 'cover' : 'worm'}.jpg"/></p>';

/// A Kavita holding one book: `book-info` says how many pages it made of it,
/// `book-page` hands one over at a time, and `book-resources` serves what a
/// page named.
class _BookAdapter implements HttpClientAdapter {
  _BookAdapter({this.failOnPage, this.refusePictures = false, this.pages = 3});

  /// A page the server cannot produce.
  final int? failOnPage;

  /// A server that hands over the words but not the pictures.
  final bool refusePictures;
  final int pages;

  /// Every rendered page the app asked the server for, in order.
  final requestedPages = <int>[];

  /// Every picture the app asked the server for, in order.
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path == '/api/Book/$_bookId/book-info') {
      return _json({
        'bookTitle': 'Dune Messiah',
        'seriesId': 3,
        'volumeId': 4,
        'libraryId': 1,
        // How long a book is is the book's to say: `chapter-info` counts
        // image pages, and a book has none.
        'pages': pages,
        'seriesName': 'Dune',
        'seriesFormat': MangaFormat.epub.id,
      });
    }
    if (path == '/api/Book/$_bookId/book-page') {
      final page = int.parse('${options.uri.queryParameters['page']}');
      requestedPages.add(page);
      if (page == failOnPage) return ResponseBody.fromBytes(const [], 500);
      return ResponseBody.fromString(
        _bookPageHtml(page),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    }
    if (path == '/api/Book/$_bookId/book-resources') {
      final file = options.uri.queryParameters['file'] as String;
      requested.add(file);
      if (refusePictures) return ResponseBody.fromBytes(const [], 404);
      return ResponseBody.fromBytes(
        _picture,
        200,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    }
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.unknown,
      error: 'nothing here answers $path',
    );
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// A book as a row knows it: the chapter the server hangs the file on, whose
/// own page count is of image pages and so is none at all.
const _book = SavedChapter(
  chapterId: _bookId,
  seriesId: 3,
  volumeId: 4,
  libraryId: 1,
  seriesName: 'Dune',
  title: 'Book 1',
  pages: 0,
  bytes: 0,
  format: MangaFormat.epub,
);

void main() {
  late Directory root;
  late DownloadsService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('patra-downloads-test');
    service = DownloadsService(root: root, profileId: _romain);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('downloading stores every page plus metadata', () async {
    final adapter = _PageAdapter();
    final progress = <double>[];
    final dir = await service.chapterDir(42);
    final meta = File('${dir.path}/meta.json');

    final saved = await service.download(
      client: _client(adapter),
      chapter: _chapter,
      onProgress: (completed, total) {
        expect(
          meta.existsSync(),
          isFalse,
          reason: 'metadata is absent until every page is committed',
        );
        progress.add(completed / total);
      },
    );

    expect(adapter.requests, 3);
    expect(progress, [closeTo(1 / 3, 0.001), closeTo(2 / 3, 0.001), 1.0]);
    expect(meta.existsSync(), isTrue);
    // 1 + 2 + 3 bytes.
    expect(saved.bytes, 6);
    expect(saved.pages, 3);

    for (var page = 0; page < 3; page++) {
      final file = await service.pageFile(42, page);
      expect(file.existsSync(), isTrue, reason: 'page $page is stored');
      expect(file.lengthSync(), page + 1);
    }
    expect(jsonDecode(meta.readAsStringSync())['seriesName'], 'Blame!');
  });

  test('scan returns saved chapters', () async {
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_, _) {},
    );

    final saved = await service.scan();

    expect(saved.keys, [42]);
    expect(saved[42]!.title, 'Chapter 1');
    expect(saved[42]!.bytes, 6);
  });

  test('an unqueued failed download is swept on the next scan', () async {
    final adapter = _PageAdapter(failOnPage: 1);

    await expectLater(
      service.download(
        client: _client(adapter),
        chapter: _chapter,
        onProgress: (_, _) {},
      ),
      throwsA(isA<DioException>()),
    );

    final dir = await service.chapterDir(42);
    expect(dir.existsSync(), isTrue, reason: 'the partial can be retried');
    expect(await service.scan(), isEmpty);
    expect(dir.existsSync(), isFalse, reason: 'nothing queued owns it');
  });

  test(
    'a copy stored again keeps the pages it had while the new ones fail',
    () async {
      // Storing a chapter *again* is a refresh of one the reader chose to keep:
      // the copy is theirs and not the download's to spend, so a run that fails
      // has to leave exactly what it found — pages, metadata and all.
      await service.download(
        client: _client(_PageAdapter()),
        chapter: _chapter,
        onProgress: (_, _) {},
      );
      final before = File('${(await service.chapterDir(42)).path}/meta.json')
          .readAsStringSync();

      await expectLater(
        service.download(
          client: _client(_PageAdapter(failOnPage: 1)),
          chapter: _chapter,
          onProgress: (_, _) {},
        ),
        throwsA(isA<DioException>()),
      );

      for (var page = 0; page < 3; page++) {
        expect(
          (await service.pageFile(42, page)).existsSync(),
          isTrue,
          reason: 'page $page is still the one that was stored',
        );
      }
      final dir = await service.chapterDir(42);
      expect(
        File('${dir.path}/meta.json').readAsStringSync(),
        before,
        reason: 'the copy is the copy it was',
      );
      // The failed refresh remains staged for a retry without touching the
      // saved copy the reader can still open.
      expect(
        Directory('${dir.path}/${DownloadsService.stagingDirName}')
            .existsSync(),
        isTrue,
      );
      expect((await service.scan()).keys, [42]);
      expect(
        Directory('${dir.path}/${DownloadsService.stagingDirName}')
            .existsSync(),
        isFalse,
        reason: 'no queue entry owns the failed refresh',
      );
    },
  );

  test('scan deletes a partial download that has no metadata', () async {
    // A chapter directory with pages but no meta.json: an interrupted run.
    final dir = await service.chapterDir(99);
    dir.createSync(recursive: true);
    File('${dir.path}/${DownloadsService.pageFileName(0)}')
        .writeAsBytesSync(const [1, 2, 3]);

    expect(await service.scan(), isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  test('scan keeps only partial downloads named by the queue', () async {
    final dir = await service.chapterDir(42);
    final staging = Directory('${dir.path}/${DownloadsService.stagingDirName}')
      ..createSync(recursive: true);
    final page = File('${staging.path}/${DownloadsService.pageFileName(0)}')
      ..writeAsBytesSync(const [1, 2, 3]);
    await service.writeQueue({
      42: const DownloadQueueRecord(
        request: _chapter,
        status: DownloadQueueStatus.failed,
        priority: 0,
        completedPages: 1,
        totalPages: 3,
      ),
    });

    expect(await service.scan(), isEmpty);
    expect(page.existsSync(), isTrue, reason: 'the failed entry can retry');

    await service.writeQueue({});
    expect(await service.scan(), isEmpty);
    expect(dir.existsSync(), isFalse, reason: 'an unqueued partial is garbage');
  });

  test('scan keeps partials when queue ownership is unreadable', () async {
    final dir = await service.chapterDir(42);
    final staging = Directory('${dir.path}/${DownloadsService.stagingDirName}')
      ..createSync(recursive: true);
    final page = File('${staging.path}/${DownloadsService.pageFileName(0)}')
      ..writeAsBytesSync(const [1, 2, 3]);
    final profile = await service.profileRoot();
    File('${profile.path}/queue.json').writeAsStringSync('{not json');

    expect(await service.scan(), isEmpty);
    expect(page.existsSync(), isTrue, reason: 'ambiguity keeps reader data');

    await service.writeQueue({});
    final restarted = DownloadsService(root: root, profileId: _romain);
    expect(await restarted.scan(), isEmpty);
    expect(
      page.existsSync(),
      isTrue,
      reason: 'a later queue write must preserve ambiguous ownership',
    );
  });

  test('scan treats a missing queue record list as ambiguous', () async {
    final dir = await service.chapterDir(42);
    final staging = Directory('${dir.path}/${DownloadsService.stagingDirName}')
      ..createSync(recursive: true);
    final page = File('${staging.path}/${DownloadsService.pageFileName(0)}')
      ..writeAsBytesSync(const [1, 2, 3]);
    final profile = await service.profileRoot();
    File('${profile.path}/queue.json').writeAsStringSync('{"version":1}');

    expect(await service.scan(), isEmpty);
    expect(
      page.existsSync(),
      isTrue,
      reason: 'an incomplete queue proves nothing',
    );
  });

  test('download resumes pages committed before metadata', () async {
    final dir = await service.chapterDir(42);
    dir.createSync(recursive: true);
    final first = File('${dir.path}/${DownloadsService.pageFileName(0)}')
      ..writeAsBytesSync(const [7]);
    final firstWrite = first.lastModifiedSync();
    final adapter = _PageAdapter();

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.download(
      client: _client(adapter),
      chapter: _chapter,
      onProgress: (_, _) {},
    );

    expect(adapter.requests, 2);
    expect(first.lastModifiedSync(), firstWrite);
  });

  test('removing deletes the stored pages', () async {
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_, _) {},
    );

    await service.remove(42);

    expect((await service.chapterDir(42)).existsSync(), isFalse);
    expect(await service.scan(), isEmpty);
  });

  test('discarding a cancelled download removes its resumable bytes', () async {
    final cancelToken = CancelToken();
    final adapter = _PageAdapter();

    final download = service.download(
      client: _client(adapter),
      chapter: _chapter,
      onProgress: (completed, _) {
        if (completed >= 1) cancelToken.cancel('user');
      },
      cancelToken: cancelToken,
    );

    await expectLater(download, throwsA(isA<DioException>()));
    expect((await service.chapterDir(42)).existsSync(), isTrue);
    await service.discardPartial(42);
    expect((await service.chapterDir(42)).existsSync(), isFalse);
  });

  test('a chapter is stored under the profile that saved it', () async {
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_, _) {},
    );

    final dir = await service.chapterDir(42);
    expect(dir.parent.path, (await service.profileRoot()).path);
    expect(dir.parent.parent.path, root.path);
  });

  test('two profiles save one chapter without meeting', () async {
    final lea = DownloadsService(root: root, profileId: _lea);

    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_, _) {},
    );
    await lea.download(
      client: _client(_PageAdapter()),
      chapter: _chapter.copyWith(pagesRead: 2),
      onProgress: (_, _) {},
    );

    // Each reads their own copy back, with their own progress.
    expect((await service.scan())[42]!.pagesRead, 0);
    expect((await lea.scan())[42]!.pagesRead, 2);

    // And a page turn on one side stays on that side.
    await lea.writeMeta((await lea.scan())[42]!.copyWith(pagesRead: 3));
    expect((await service.scan())[42]!.pagesRead, 0);
    expect((await lea.scan())[42]!.pagesRead, 3);
  });

  test('one profile removing a chapter leaves the other copy', () async {
    final lea = DownloadsService(root: root, profileId: _lea);
    for (final each in [service, lea]) {
      await each.download(
        client: _client(_PageAdapter()),
        chapter: _chapter,
        onProgress: (_, _) {},
      );
    }

    await service.remove(42);

    expect(await service.scan(), isEmpty);
    expect((await lea.scan()).keys, [42]);
  });

  test('scan deletes a chapter left by the flat layout', () async {
    // What the previous layout wrote: a chapter directory sitting directly
    // in the downloads root, meta.json and all. There is no migration, so
    // the sweep that already removes an incomplete download removes this.
    final stale = Directory('${root.path}/42')..createSync(recursive: true);
    File('${stale.path}/meta.json')
        .writeAsStringSync(jsonEncode(_chapter.toJson()));

    expect(await service.scan(), isEmpty);
    expect(stale.existsSync(), isFalse);
  });

  test('scan leaves another profile alone', () async {
    final lea = DownloadsService(root: root, profileId: _lea);
    await lea.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_, _) {},
    );

    expect(await service.scan(), isEmpty);
    expect((await lea.scan()).keys, [42]);
  });

  test('the totals say what a profile holds', () async {
    final lea = DownloadsService(root: root, profileId: _lea);
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_, _) {},
    );

    final mine = await service.savedTotals();
    expect(mine.chapters, 1);
    // 1 + 2 + 3 bytes of pages, the same total the Downloads tab adds up.
    expect(mine.bytes, 6);

    final hers = await lea.savedTotals();
    expect(hers.chapters, 0);
    expect(hers.bytes, 0);
  });

  test('removing a profile takes its chapters and nobody else\'s', () async {
    final lea = DownloadsService(root: root, profileId: _lea);
    for (final each in [service, lea]) {
      await each.download(
        client: _client(_PageAdapter()),
        chapter: _chapter,
        onProgress: (_, _) {},
      );
    }

    await lea.removeAll();

    expect((await lea.profileRoot()).existsSync(), isFalse);
    expect((await service.scan()).keys, [42]);
  });

  // A book is stored the way ADR-0009 says it must be: the pages the server
  // rendered, each carrying its own pictures, and the total it was made with
  // — because with no server there is nothing left to lay the words out or
  // to fetch a picture from.
  group('saving a book', () {
    test('the copy is the pages the server rendered, self-contained', () async {
      final adapter = _BookAdapter();

      final saved = await service.download(
        client: _client(adapter),
        chapter: _book,
        onProgress: (_, _) {},
      );

      // How long the book is is the book's to say, not the chapter's: the
      // chapter counts image pages, and a book has none.
      expect(saved.pages, 3);
      expect(saved.content, ChapterContent.reflowable);
      expect(saved.bytes, greaterThan(0));

      // Every page the server made is here, and each carries the picture it
      // named rather than the name it named it by.
      for (var page = 0; page < 3; page++) {
        final file = await service.pageFile(_bookId, page);
        expect(file.existsSync(), isTrue, reason: 'page $page is stored');
        final html = file.readAsStringSync();
        expect(html, contains('The spice must flow.'));
        expect(
          html,
          contains(base64Encode(_picture)),
          reason: 'page $page carries its picture',
        );
        expect(html, isNot(contains('OEBPS/')), reason: 'and no name to fetch');
      }

      // A picture two pages name is fetched once.
      expect(adapter.requested, [
        'OEBPS/images/worm.jpg',
        'OEBPS/images/cover.jpg',
      ]);
    });

    test('a copy read back knows it is a book', () async {
      await service.download(
        client: _client(_BookAdapter()),
        chapter: _book,
        onProgress: (_, _) {},
      );

      final saved = (await service.scan())[_bookId]!;
      expect(saved.content, ChapterContent.reflowable);
      expect(saved.format, MangaFormat.epub);
      expect(saved.pages, 3);
    });

    test('an unqueued failed book is swept on the next scan', () async {
      await expectLater(
        service.download(
          client: _client(_BookAdapter(failOnPage: 2)),
          chapter: _book,
          onProgress: (_, _) {},
        ),
        throwsA(isA<DioException>()),
      );
      final dir = await service.chapterDir(_bookId);
      expect(dir.existsSync(), isTrue, reason: 'the partial can be retried');
      expect(await service.scan(), isEmpty);
      expect(dir.existsSync(), isFalse, reason: 'nothing queued owns it');
    });

    test('a retried book keeps its first attempt pagination', () async {
      final first = _BookAdapter(failOnPage: 2);
      final firstProgress = <(int, int)>[];
      await expectLater(
        service.download(
          client: _client(first),
          chapter: _book,
          onProgress: (completed, total) {
            firstProgress.add((completed, total));
          },
        ),
        throwsA(isA<DioException>()),
      );
      expect(first.requestedPages, [0, 1, 2]);
      expect(firstProgress.first, (
        0,
        3,
      ), reason: 'pagination is durable before the first page is written');

      final changedServer = _BookAdapter(pages: 4);
      final saved = await service.download(
        client: _client(changedServer),
        chapter: _book,
        onProgress: (_, _) {},
        knownTotalPages: 3,
      );

      expect(changedServer.requestedPages, [2]);
      expect(saved.pages, 3, reason: 'the copy keeps its original pagination');
    });

    test('a picture the server refuses costs the page its picture', () async {
      // Half of an illustrated book is not a reason to have no book: the
      // words are the point, and a page that keeps the name it cannot fetch
      // is one the server can still answer for when there is a server.
      final adapter = _BookAdapter(refusePictures: true);
      final saved = await service.download(
        client: _client(adapter),
        chapter: _book,
        onProgress: (_, _) {},
      );

      expect(saved.pages, 3);
      final html = (await service.pageFile(_bookId, 0)).readAsStringSync();
      expect(html, contains('The spice must flow.'));
      expect(html, contains('OEBPS/images/worm.jpg'));
      expect(html, isNot(contains('data:')));
      // And it is not asked for again on the page that names it too: a book
      // whose pictures are all refused is not a book that fetches forever.
      expect(adapter.requested, [
        'OEBPS/images/worm.jpg',
        'OEBPS/images/cover.jpg',
      ]);
    });

    test('a copy stored before a book could be saved reads as pictures', () {
      // What `meta.json` held until now: no `format`, and every copy there
      // was a copy of pages that were pictures.
      final saved = SavedChapter.fromJson({
        'chapterId': 42,
        'pages': 3,
        'bytes': 6,
        'pagesRead': 1,
      })!;

      expect(saved.content, ChapterContent.fixedPages);
      expect(saved.format, MangaFormat.unknown);
    });
  });
}
