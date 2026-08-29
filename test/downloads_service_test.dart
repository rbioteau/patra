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
    refreshToken: 'refresh',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;
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

void main() {
  late Directory root;
  late DownloadsService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('patra-downloads-test');
    service = DownloadsService(root: root);
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
}
