import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
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

KavitaClient _client(_PageAdapter adapter) {
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

    final saved = await service.download(
      client: _client(adapter),
      chapter: _chapter,
      onProgress: progress.add,
    );

    expect(adapter.requests, 3);
    expect(progress, [closeTo(1 / 3, 0.001), closeTo(2 / 3, 0.001), 1.0]);
    // 1 + 2 + 3 bytes.
    expect(saved.bytes, 6);
    expect(saved.pages, 3);

    for (var page = 0; page < 3; page++) {
      final file = await service.pageFile(42, page);
      expect(file.existsSync(), isTrue, reason: 'page $page is stored');
      expect(file.lengthSync(), page + 1);
    }
    final meta = File('${(await service.chapterDir(42)).path}/meta.json');
    expect(jsonDecode(meta.readAsStringSync())['seriesName'], 'Blame!');
  });

  test('scan returns saved chapters', () async {
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_) {},
    );

    final saved = await service.scan();

    expect(saved.keys, [42]);
    expect(saved[42]!.title, 'Chapter 1');
    expect(saved[42]!.bytes, 6);
  });

  test('a failed download leaves nothing behind', () async {
    final adapter = _PageAdapter(failOnPage: 1);

    await expectLater(
      service.download(
        client: _client(adapter),
        chapter: _chapter,
        onProgress: (_) {},
      ),
      throwsA(isA<DioException>()),
    );

    expect((await service.chapterDir(42)).existsSync(), isFalse);
    expect(await service.scan(), isEmpty);
  });

  test('scan deletes a partial download that has no metadata', () async {
    // A chapter directory with pages but no meta.json: an interrupted run.
    final dir = await service.chapterDir(99);
    dir.createSync(recursive: true);
    File('${dir.path}/${DownloadsService.pageFileName(0)}')
        .writeAsBytesSync(const [1, 2, 3]);

    expect(await service.scan(), isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  test('removing deletes the stored pages', () async {
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_) {},
    );

    await service.remove(42);

    expect((await service.chapterDir(42)).existsSync(), isFalse);
    expect(await service.scan(), isEmpty);
  });

  test('a cancelled download is cleaned up too', () async {
    final cancelToken = CancelToken();
    final adapter = _PageAdapter();

    final download = service.download(
      client: _client(adapter),
      chapter: _chapter,
      onProgress: (progress) {
        if (progress >= 1 / 3) cancelToken.cancel('user');
      },
      cancelToken: cancelToken,
    );

    await expectLater(download, throwsA(isA<DioException>()));
    expect((await service.chapterDir(42)).existsSync(), isFalse);
  });

  test('a chapter is stored under the profile that saved it', () async {
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_) {},
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
      onProgress: (_) {},
    );
    await lea.download(
      client: _client(_PageAdapter()),
      chapter: _chapter.copyWith(pagesRead: 2),
      onProgress: (_) {},
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
        onProgress: (_) {},
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
      onProgress: (_) {},
    );

    expect(await service.scan(), isEmpty);
    expect((await lea.scan()).keys, [42]);
  });

  test('the totals say what a profile holds', () async {
    final lea = DownloadsService(root: root, profileId: _lea);
    await service.download(
      client: _client(_PageAdapter()),
      chapter: _chapter,
      onProgress: (_) {},
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
        onProgress: (_) {},
      );
    }

    await lea.removeAll();

    expect((await lea.profileRoot()).existsSync(), isFalse);
    expect((await service.scan()).keys, [42]);
  });
}
