import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/book_face.dart';
import 'package:patra/src/features/reader/book_markup.dart';

/// Serves fake page bytes, and can fail on a chosen page.
class _PageAdapter implements HttpClientAdapter {
  _PageAdapter({this.failOnPage, this.gate});

  final int? failOnPage;
  final Future<void>? gate;
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
    if (gate != null) {
      final cancelled = cancelFuture == null
          ? false
          : await Future.any([
              gate!.then((_) => false),
              cancelFuture.then((_) => true),
            ]);
      if (cancelFuture == null) await gate;
      if (cancelled) {
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'cancelled',
        );
      }
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

/// What the server draws a book's chapter with: the cover the series screen
/// shows on its row.
const _cover = [4, 5, 6, 7];

/// One book, in the chapter the server hangs it on.
const _bookId = 7;

/// What the server says a page of the book is made of: words, and a picture
/// named the way the file names it. The first two pages name the same one,
/// which is the ordinary thing for a book to do.
String _bookPageHtml(int page) =>
    '<h1>Part ${page == 2 ? 'two' : 'one'}</h1>'
    '<p>The spice must flow.</p>'
    '<p><img src="OEBPS/images/${page == 2 ? 'cover' : 'worm'}.jpg"/></p>';

/// What the server says a page of the book-with-font is made of: words, a
/// picture, and a @font-face pointing at a book-resources file.
String _bookWithFontPageHtml(int page) =>
    '<style>'
    '@font-face {'
    '  font-family: "Book Face";'
    // The address Kavita writes: scheme-less, naming the host it guesses it
    // lives on, with the file it means in the query. `bookPictureUrl` keeps
    // the `file` and rebuilds the request on this session's own base URL.
    '  src: url("//host/api/Book/$_bookId/book-resources?apiKey=key&file=fonts/regular.woff2")'
    '       format("woff2");'
    '  font-weight: normal;'
    '  font-style: normal;'
    '}'
    '@font-face {'
    '  font-family: "Book Face";'
    '  src: url("//host/api/Book/$_bookId/book-resources?apiKey=key&file=fonts/italic.woff2")'
    '       format("woff2");'
    '  font-weight: normal;'
    '  font-style: italic;'
    '}'
    '</style>'
    '<h1>Part ${page == 2 ? 'two' : 'one'}</h1>'
    '<p>The spice must flow.</p>'
    '<p><img src="OEBPS/images/${page == 2 ? 'cover' : 'worm'}.jpg"/></p>';

/// A Kavita holding one book: `book-info` says how many pages it made of it,
/// `book-page` hands one over at a time, and `book-resources` serves what a
/// page named.
class _BookAdapter implements HttpClientAdapter {
  _BookAdapter({
    this.failOnPage,
    this.refusePictures = false,
    this.refuseCover = false,
    this.pages = 3,
  });

  /// A server that hands over the book but not the chapter's cover.
  final bool refuseCover;

  /// How many times the app asked for the chapter's cover.
  var coversAsked = 0;

  /// A page the server cannot produce.
  final int? failOnPage;

  /// A server that hands over the words but not the pictures.
  final bool refusePictures;
  final int pages;

  /// Every rendered page the app asked the server for, in order.
  final requestedPages = <int>[];

  /// Every picture the app asked the server for, in order.
  final requested = <String>[];

  /// Every font the app asked the server for — always empty for this adapter
  /// since its pages carry no @font-face rules.
  final requestedFonts = <String>[];

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
    if (path == '/api/Image/chapter-cover') {
      expect(options.uri.queryParameters['chapterId'], '$_bookId');
      coversAsked++;
      if (refuseCover) return ResponseBody.fromBytes(const [], 404);
      return ResponseBody.fromBytes(_cover, 200);
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

/// A Kavita holding one book that ships its own face: the page HTML carries
/// @font-face rules pointing at book-resources files, and the adapter tracks
/// font requests separately from picture requests.
class _BookWithFontAdapter implements HttpClientAdapter {
  _BookWithFontAdapter({this.refuseFonts = false, this.pages = 3});

  final bool refuseFonts;
  final int pages;

  final requestedPages = <int>[];

  /// Every picture the app asked the server for, in order.
  final requested = <String>[];

  /// Every font file the app asked the server for, in order.
  final requestedFonts = <String>[];

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
        'pages': pages,
        'seriesName': 'Dune',
        'seriesFormat': MangaFormat.epub.id,
      });
    }
    if (path == '/api/Book/$_bookId/book-page') {
      final page = int.parse('${options.uri.queryParameters['page']}');
      requestedPages.add(page);
      return ResponseBody.fromString(
        _bookWithFontPageHtml(page),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    }
    if (path == '/api/Book/$_bookId/book-resources') {
      final file = options.uri.queryParameters['file'] as String;
      // Track font requests separately from picture requests.
      if (file.startsWith('fonts/')) {
        requestedFonts.add(file);
        if (refuseFonts) return ResponseBody.fromBytes(const [], 404);
        return ResponseBody.fromBytes(
          _picture,
          200,
          headers: {
            Headers.contentTypeHeader: ['font/woff2'],
          },
        );
      }
      requested.add(file);
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

  test('a copy named after Kavita’s sentinel names nothing', () async {
    // A volume with no chapter breakdown is named after the volume now, but
    // copies already on the device were stored with the placeholder's number
    // and cannot be renamed from here: the row is what refuses to say it.
    SavedChapter named(String title) => SavedChapter(
      chapterId: _chapter.chapterId,
      seriesId: _chapter.seriesId,
      volumeId: _chapter.volumeId,
      libraryId: _chapter.libraryId,
      seriesName: _chapter.seriesName,
      title: title,
      pages: _chapter.pages,
      bytes: _chapter.bytes,
    );

    expect(named('-100000').resolvedTitle, isEmpty);
    expect(_chapter.resolvedTitle, _chapter.title);
    expect(
      named('-1000').resolvedTitle,
      '-1000',
      reason:
          'a number a reader could have typed is not Kavita’s '
          'bookkeeping, however odd a title it makes',
    );
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
    final gate = Completer<void>();
    final adapter = _PageAdapter(gate: gate.future);

    final download = service.download(
      client: _client(adapter),
      chapter: _chapter,
      onProgress: (_, _) {},
      cancelToken: cancelToken,
    );
    await Future<void>.delayed(Duration.zero);
    cancelToken.cancel('user');

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
  // rendered and the total it was made with — because with no server there is
  // nothing left to lay the words out. And a copy is a directory (#129): each
  // page as the server wrote it, beside the pictures it names, so a stored
  // page is the same page a streamed one is.
  group('saving a book', () {
    test(
      'the copy is the pages the server rendered, beside their pictures',
      () async {
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

        // Every page the server made is here, exactly as it made it: the name
        // a picture was given is what the reader finds it by.
        for (var page = 0; page < 3; page++) {
          final file = await service.pageFile(_bookId, page);
          expect(file.existsSync(), isTrue, reason: 'page $page is stored');
          expect(file.readAsStringSync(), _bookPageHtml(page));
        }

        // Each picture sits beside the pages, once, under the name the reader
        // will look for it by.
        final dir = await service.chapterDir(_bookId);
        for (final src in ['OEBPS/images/worm.jpg', 'OEBPS/images/cover.jpg']) {
          final picture = File(
            '${dir.path}/$bookPicturesDirectory/${bookFileName(src)}',
          );
          expect(
            picture.readAsBytesSync(),
            _picture,
            reason: '$src is carried',
          );
        }

        // A picture two pages name is fetched once.
        expect(
          adapter.requested,
          unorderedEquals(['OEBPS/images/worm.jpg', 'OEBPS/images/cover.jpg']),
        );

        // And the copy costs its pages and each of its pictures once — the
        // total the Downloads tab reports.
        final pages = [
          for (var page = 0; page < 3; page++) utf8.encode(_bookPageHtml(page)),
        ].fold<int>(0, (sum, page) => sum + page.length);
        expect(saved.bytes, pages + 2 * _picture.length + _cover.length);
      },
    );

    // A book's first page is words, so the row in the Downloads tab has no
    // page to draw as its thumbnail the way a chapter of pictures does: the
    // copy keeps the cover the series screen shows, and needs no server for it.
    test('the copy keeps the cover the chapter is drawn with', () async {
      final adapter = _BookAdapter();
      await service.download(
        client: _client(adapter),
        chapter: _book,
        onProgress: (_, _) {},
      );

      final dir = await service.chapterDir(_bookId);
      expect(
        File('${dir.path}/${DownloadsService.coverFileName}').readAsBytesSync(),
        _cover,
      );
      expect(adapter.coversAsked, 1);
    });

    test('a cover the server refuses costs the copy nothing else', () async {
      final saved = await service.download(
        client: _client(_BookAdapter(refuseCover: true)),
        chapter: _book,
        onProgress: (_, _) {},
      );

      expect(saved.pages, 3);
      final dir = await service.chapterDir(_bookId);
      expect(
        File('${dir.path}/${DownloadsService.coverFileName}').existsSync(),
        isFalse,
      );
      expect((await service.scan()).keys, [_bookId]);
    });

    test('a copy stored again keeps its cover', () async {
      await service.download(
        client: _client(_BookAdapter()),
        chapter: _book,
        onProgress: (_, _) {},
      );
      await service.download(
        client: _client(_BookAdapter(pages: 2)),
        chapter: _book,
        onProgress: (_, _) {},
      );

      final dir = await service.chapterDir(_bookId);
      expect(
        File('${dir.path}/${DownloadsService.coverFileName}').readAsBytesSync(),
        _cover,
      );
    });

    test('saving a book is no more requests than it was', () async {
      // A copy that is a directory is the same fetches written differently:
      // one page request per page and one per picture, never a second trip.
      final adapter = _BookAdapter();
      await service.download(
        client: _client(adapter),
        chapter: _book,
        onProgress: (_, _) {},
      );
      expect(adapter.requestedPages..sort(), [0, 1, 2]);
      expect(adapter.requested, hasLength(2));
      expect(adapter.coversAsked, 1);
    });

    test('removing a copy removes its pictures with it', () async {
      await service.download(
        client: _client(_BookAdapter()),
        chapter: _book,
        onProgress: (_, _) {},
      );
      final dir = await service.chapterDir(_bookId);
      expect(
        Directory('${dir.path}/$bookPicturesDirectory').existsSync(),
        isTrue,
      );

      await service.remove(_bookId);

      expect(dir.existsSync(), isFalse);
      expect(await service.scan(), isEmpty);
    });

    test(
      'a copy stored again keeps only the pictures its pages name now',
      () async {
        await service.download(
          client: _client(_BookAdapter()),
          chapter: _book,
          onProgress: (_, _) {},
        );
        final dir = await service.chapterDir(_bookId);
        final cover = File(
          '${dir.path}/$bookPicturesDirectory/'
          '${bookFileName('OEBPS/images/cover.jpg')}',
        );
        expect(cover.existsSync(), isTrue);

        // Recounted to two pages: the page naming the cover is gone, and a
        // picture nothing names is disk the Downloads tab cannot explain.
        final saved = await service.download(
          client: _client(_BookAdapter(pages: 2)),
          chapter: _book,
          onProgress: (_, _) {},
        );

        expect(saved.pages, 2);
        expect(cover.existsSync(), isFalse);
        expect(
          File(
            '${dir.path}/$bookPicturesDirectory/'
            '${bookFileName('OEBPS/images/worm.jpg')}',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('a retried book does not fetch a picture it already has', () async {
      await expectLater(
        service.download(
          client: _client(_BookAdapter(failOnPage: 2)),
          chapter: _book,
          onProgress: (_, _) {},
        ),
        throwsA(isA<DioException>()),
      );

      final retry = _BookAdapter();
      final saved = await service.download(
        client: _client(retry),
        chapter: _book,
        onProgress: (_, _) {},
        knownTotalPages: 3,
      );

      // The page that failed names the cover, which the first attempt never
      // reached; the worm it did fetch is already beside the pages.
      expect(retry.requested, ['OEBPS/images/cover.jpg']);
      final pages = [
        for (var page = 0; page < 3; page++) utf8.encode(_bookPageHtml(page)),
      ].fold<int>(0, (sum, page) => sum + page.length);
      expect(saved.bytes, pages + 2 * _picture.length + _cover.length);
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
      final dir = await service.chapterDir(_bookId);
      final pictures = Directory('${dir.path}/$bookPicturesDirectory');
      expect(
        pictures.existsSync() ? pictures.listSync() : const [],
        isEmpty,
        reason: 'nothing stands in for a picture the server refused',
      );
      // And it is not asked for again on the page that names it too: a book
      // whose pictures are all refused is not a book that fetches forever.
      expect(
        adapter.requested,
        unorderedEquals(['OEBPS/images/worm.jpg', 'OEBPS/images/cover.jpg']),
      );
    });

    // A copy keeps the pagination it was made with (ADR-0009), and the
    // language too — or a book read on a train is hyphenated in nothing.
    test('a copy records the language it was made with', () async {
      await service.download(
        client: _client(_BookAdapter()),
        chapter: const SavedChapter(
          chapterId: _bookId,
          seriesId: 3,
          volumeId: 4,
          libraryId: 1,
          seriesName: 'Dune',
          title: 'Book 1',
          pages: 0,
          bytes: 0,
          format: MangaFormat.epub,
          language: 'fr',
        ),
        onProgress: (_, _) {},
      );

      final saved = (await service.scan())[_bookId]!;
      expect(saved.language, 'fr');
      // And keeps it through what the device does to a copy afterwards.
      expect(saved.copyWith(pagesRead: 2).language, 'fr');
    });

    test('a copy stored before its language was recorded has none', () {
      final saved = SavedChapter.fromJson({
        'chapterId': 42,
        'pages': 3,
        'format': MangaFormat.epub.id,
      })!;

      expect(saved.language, isNull);
      expect(saved.content, ChapterContent.reflowable);
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

  group('saving a book that ships its own face', () {
    test(
      'the font is fetched once and written under the frozen name',
      () async {
        final adapter = _BookWithFontAdapter();

        final saved = await service.download(
          client: _client(adapter),
          chapter: _book,
          onProgress: (_, _) {},
        );

        expect(saved.pages, 3);
        expect(saved.content, ChapterContent.reflowable);
        expect(saved.bytes, greaterThan(0));

        // The font files were requested exactly once each, despite 3 pages.
        expect(adapter.requestedFonts, [
          'fonts/regular.woff2',
          'fonts/italic.woff2',
        ]);
        // Pictures were still fetched as before.
        expect(
          adapter.requested,
          unorderedEquals(['OEBPS/images/worm.jpg', 'OEBPS/images/cover.jpg']),
        );

        // The font files exist in the chapter directory under the frozen names.
        final dir = await service.chapterDir(_bookId);
        final romanFile = File('${dir.path}/${BookFontFile.roman}');
        final italicFile = File('${dir.path}/${BookFontFile.italic}');
        expect(
          romanFile.existsSync(),
          isTrue,
          reason: 'roman font file exists',
        );
        expect(
          italicFile.existsSync(),
          isTrue,
          reason: 'italic font file exists',
        );
        expect(romanFile.lengthSync(), _picture.length);
        expect(italicFile.lengthSync(), _picture.length);

        // Pages are stored as the server wrote them, their pictures beside.
        for (var page = 0; page < 3; page++) {
          final file = await service.pageFile(_bookId, page);
          expect(file.readAsStringSync(), _bookWithFontPageHtml(page));
        }
        expect(
          File(
            '${dir.path}/$bookPicturesDirectory/'
            '${bookFileName('OEBPS/images/worm.jpg')}',
          ).readAsBytesSync(),
          _picture,
        );
      },
    );

    test('the font survives promotion when the book is saved again with a different page count', () async {
      // First save: 3 pages.
      final firstAdapter = _BookWithFontAdapter(pages: 3);
      await service.download(
        client: _client(firstAdapter),
        chapter: _book,
        onProgress: (_, _) {},
      );

      final dir = await service.chapterDir(_bookId);
      final romanFile = File('${dir.path}/${BookFontFile.roman}');
      final italicFile = File('${dir.path}/${BookFontFile.italic}');
      expect(romanFile.existsSync(), isTrue);
      expect(italicFile.existsSync(), isTrue);
      final firstRomanBytes = romanFile.readAsBytesSync();
      final firstItalicBytes = italicFile.readAsBytesSync();

      // Second save (refresh): server now reports 4 pages, but we keep the
      // original 3. The font files should survive _promote.
      final secondAdapter = _BookWithFontAdapter(pages: 4);
      final saved = await service.download(
        client: _client(secondAdapter),
        chapter: _book,
        onProgress: (_, _) {},
        knownTotalPages: 3,
      );

      expect(saved.pages, 3, reason: 'the copy keeps its original pagination');

      // Font files still exist and have the same content.
      expect(
        romanFile.existsSync(),
        isTrue,
        reason: 'roman font survives promotion',
      );
      expect(
        italicFile.existsSync(),
        isTrue,
        reason: 'italic font survives promotion',
      );
      expect(romanFile.readAsBytesSync(), firstRomanBytes);
      expect(italicFile.readAsBytesSync(), firstItalicBytes);

      // The stale page 3 (which would have been page index 3 in a 4-page book)
      // is not present.
      final stalePage = File('${dir.path}/${DownloadsService.pageFileName(3)}');
      expect(
        stalePage.existsSync(),
        isFalse,
        reason: 'stale page 3 was removed',
      );

      // A refresh remakes the copy, so the face is fetched again — once, not
      // once per page, which is what the memoization in `carried` is for.
      expect(secondAdapter.requestedFonts, [
        'fonts/regular.woff2',
        'fonts/italic.woff2',
      ], reason: 'the face is fetched once per save, never once per page');
    });

    test(
      'a font the server refuses costs the copy its font but not the book',
      () async {
        // A server that serves the page but refuses the font files.
        final adapter = _BookWithFontAdapter(refuseFonts: true);
        final saved = await service.download(
          client: _client(adapter),
          chapter: _book,
          onProgress: (_, _) {},
        );

        expect(saved.pages, 3);
        expect(saved.content, ChapterContent.reflowable);

        // Font files were requested but the server refused.
        expect(adapter.requestedFonts, [
          'fonts/regular.woff2',
          'fonts/italic.woff2',
        ]);

        // No font files were written.
        final dir = await service.chapterDir(_bookId);
        final romanFile = File('${dir.path}/${BookFontFile.roman}');
        final italicFile = File('${dir.path}/${BookFontFile.italic}');
        expect(
          romanFile.existsSync(),
          isFalse,
          reason: 'no roman font written',
        );
        expect(
          italicFile.existsSync(),
          isFalse,
          reason: 'no italic font written',
        );

        // Pages are still stored, and their pictures beside them.
        for (var page = 0; page < 3; page++) {
          final file = await service.pageFile(_bookId, page);
          expect(file.readAsStringSync(), contains('The spice must flow.'));
        }
        expect(
          File(
            '${dir.path}/$bookPicturesDirectory/'
            '${bookFileName('OEBPS/images/worm.jpg')}',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('a book whose page asks for no font writes no font file and does not fail', () async {
      // The original _BookAdapter returns pages without @font-face rules.
      final adapter = _BookAdapter();
      final saved = await service.download(
        client: _client(adapter),
        chapter: _book,
        onProgress: (_, _) {},
      );

      expect(saved.pages, 3);
      expect(saved.content, ChapterContent.reflowable);

      // No font files were requested or written.
      expect(adapter.requestedFonts, isEmpty);

      final dir = await service.chapterDir(_bookId);
      final romanFile = File('${dir.path}/${BookFontFile.roman}');
      final italicFile = File('${dir.path}/${BookFontFile.italic}');
      expect(romanFile.existsSync(), isFalse, reason: 'no roman font written');
      expect(
        italicFile.existsSync(),
        isFalse,
        reason: 'no italic font written',
      );

      // Pages are stored normally.
      for (var page = 0; page < 3; page++) {
        final file = await service.pageFile(_bookId, page);
        expect(file.existsSync(), isTrue, reason: 'page $page is stored');
      }
    });
  });
}
