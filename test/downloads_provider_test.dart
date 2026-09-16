import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';

/// Mimics Kavita: `/api/Reader/image` binds `apiKey` as a non-nullable
/// parameter, so a request without it is answered 400 — the bearer token is
/// not enough.
class _KavitaLikeAdapter implements HttpClientAdapter {
  int served = 0;
  int rejected = 0;

  /// Every progress post the device has sent: the chapter, the page and — for
  /// a book — the place within it.
  final posted = <({int chapterId, int pageNum, String? bookScrollId})>[];

  /// Whether the server can be reached at all. A train is not a refusal: what
  /// this turns off is the connection, not the answer.
  bool unreachable = false;

  /// Holds every page request open, so a test can look at the state while
  /// downloads are still running.
  Future<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (unreachable) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route to host',
      );
    }
    if (options.path == '/api/Reader/progress') {
      final body = options.data as Map<String, dynamic>;
      posted.add((
        chapterId: body['chapterId'] as int,
        pageNum: body['pageNum'] as int,
        bookScrollId: body['bookScrollId'] as String?,
      ));
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.queryParameters['apiKey'] is! String ||
        (options.queryParameters['apiKey'] as String).isEmpty) {
      rejected++;
      return ResponseBody.fromBytes(const [], 400);
    }
    if (gate != null) await gate;
    served++;
    return ResponseBody.fromBytes(
      List<int>.filled(4, 9),
      200,
      headers: {
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _chapter = SavedChapter(
  chapterId: 12,
  seriesId: 3,
  volumeId: 1,
  libraryId: 2,
  seriesName: 'Akira',
  title: 'Volume 1',
  pages: 3,
  bytes: 0,
);

const _otherChapter = SavedChapter(
  chapterId: 13,
  seriesId: 3,
  volumeId: 1,
  libraryId: 2,
  seriesName: 'Akira',
  title: 'Volume 2',
  pages: 3,
  bytes: 0,
);

/// Whose store these tests are: the provider is handed a service directly
/// here, so the profile it belongs to is named rather than resolved.
const _profileId = 'https://kavita.test#1';

void main() {
  late Directory root;
  late _KavitaLikeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    root = Directory.systemTemp.createTempSync('patra-downloads-provider');
    adapter = _KavitaLikeAdapter();
    final client = KavitaClient(
      baseUrl: 'http://kavita.test',
      token: 'token',
      username: 'romain',
      apiKey: 'the-api-key',
    );
    client.httpClient.httpClientAdapter = adapter;
    client.bareHttpClient.httpClientAdapter = adapter;
    container = ProviderContainer.test(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: root, profileId: _profileId),
        ),
      ],
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('saving a chapter stores it and reports it as saved', () async {
    await container.read(downloadsProvider.future);

    await container.read(downloadsProvider.notifier).save(_chapter);

    final state = container.read(downloadsProvider).value!;
    expect(
      adapter.rejected,
      0,
      reason: 'every page request carries the apiKey',
    );
    expect(adapter.served, 3);
    expect(state.saved[12]?.seriesName, 'Akira');
    expect(state.saved[12]?.bytes, 12);
    expect(state.inFlight, isEmpty);
    expect(state.failed, isEmpty);
    expect(container.read(savedChapterProvider(12)), isNotNull);
  });

  test('a tap before the first scan finishes is not dropped', () async {
    // No prior read: the notifier is still scanning when save() is called.
    await container.read(downloadsProvider.notifier).save(_chapter);

    expect(
      container.read(downloadsProvider).value!.saved.containsKey(12),
      isTrue,
    );
  });

  test('two taps before the first scan do not forget each other', () async {
    // Both calls wait on the same scan; the second resumes into a state the
    // first has already written to. Building on what the scan returned would
    // drop the first chapter, leaving a download nothing tracks any more.
    final gate = Completer<void>();
    adapter.gate = gate.future;

    final first = container.read(downloadsProvider.notifier).save(_chapter);
    final second = container
        .read(downloadsProvider.notifier)
        .save(_otherChapter);
    await pumpEventQueue();

    expect(
      container.read(downloadsProvider).value!.inFlight.keys,
      containsAll([12, 13]),
    );

    gate.complete();
    await Future.wait([first, second]);
    final state = container.read(downloadsProvider).value!;
    expect(state.saved.keys, containsAll([12, 13]));
    expect(state.inFlight, isEmpty);
  });

  test('a failed download is reported, not silently reverted', () async {
    final client = KavitaClient(
      baseUrl: 'http://kavita.test',
      token: 'token',
      username: 'romain',
      // No API key: the server answers 400, like Kavita does.
      apiKey: '',
    );
    client.httpClient.httpClientAdapter = adapter;
    client.bareHttpClient.httpClientAdapter = adapter;
    final failing = ProviderContainer.test(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: root, profileId: _profileId),
        ),
      ],
    );

    await failing.read(downloadsProvider.future);
    await failing.read(downloadsProvider.notifier).save(_chapter);

    final state = failing.read(downloadsProvider).value!;
    expect(adapter.rejected, greaterThan(0));
    expect(state.saved, isEmpty);
    expect(state.inFlight, isEmpty);
    expect(state.failed, contains(12), reason: 'the pill offers a retry');
  });

  test('removing a saved chapter clears it', () async {
    await container.read(downloadsProvider.future);
    await container.read(downloadsProvider.notifier).save(_chapter);

    await container.read(downloadsProvider.notifier).remove(12);

    expect(container.read(downloadsProvider).value!.saved, isEmpty);
    expect(container.read(savedChapterProvider(12)), isNull);
  });

  test('reading progress is mirrored into the stored copy', () async {
    await container.read(downloadsProvider.future);
    await container.read(downloadsProvider.notifier).save(_chapter);

    await container.read(downloadsProvider.notifier).recordProgress(12, 2);

    expect(container.read(savedChapterProvider(12))?.pagesRead, 2);
    // Persisted under this profile's own root, so the Downloads tab still
    // knows after a restart — and the profile beside it does not.
    final service = DownloadsService(root: root, profileId: _profileId);
    final meta = File('${(await service.chapterDir(12)).path}/meta.json');
    expect(jsonDecode(meta.readAsStringSync())['pagesRead'], 2);

    // And a fresh scan reads it back.
    final rescanned = await service.scan();
    expect(rescanned[12]?.pagesRead, 2);
    expect(rescanned[12]?.progress, closeTo(2 / 3, 0.001));
    expect(rescanned[12]?.isRead, isFalse);
  });

  test('progress the server was not told waits in the copy', () async {
    await container.read(downloadsProvider.future);
    await container.read(downloadsProvider.notifier).save(_chapter);
    adapter.unreachable = true;

    await container
        .read(downloadsProvider.notifier)
        .recordProgress(
          12,
          2,
          pending: const PendingProgress(pageNum: 2, bookScrollId: '0.5000'),
        );
    await container.read(downloadsProvider.notifier).syncPendingProgress();

    // Nothing answered, so the copy is still holding both halves of it: the
    // page the reader is on, and the place within that page.
    expect(adapter.posted, isEmpty);
    expect((await _savedMeta(root, 12))['pending'], {
      'pageNum': 2,
      'bookScrollId': '0.5000',
    });

    // A server that answers was the whole of what was being waited for.
    adapter.unreachable = false;
    await container.read(downloadsProvider.notifier).syncPendingProgress();

    expect(adapter.posted, [
      (chapterId: 12, pageNum: 2, bookScrollId: '0.5000'),
    ]);
    expect(container.read(savedChapterProvider(12))?.pending, isNull);
    expect((await _savedMeta(root, 12))['pending'], isNull);
  });

  test(
    'a server coming back is what sends what the copies are holding',
    () async {
      // The reader is gone and no screen is watching: what is left to notice
      // that the server answers again is the store, which listened for it.
      await container.read(downloadsProvider.future);
      await container.read(downloadsProvider.notifier).save(_chapter);
      adapter.unreachable = true;
      await container
          .read(downloadsProvider.notifier)
          .recordProgress(
            12,
            2,
            pending: const PendingProgress(pageNum: 2, bookScrollId: '0.5000'),
          );

      adapter.unreachable = false;
      container.read(offlineProvider.notifier).set(true);
      container.read(offlineProvider.notifier).set(false);
      await pumpEventQueue();

      expect(adapter.posted, [
        (chapterId: 12, pageNum: 2, bookScrollId: '0.5000'),
      ]);
      expect(container.read(savedChapterProvider(12))?.pending, isNull);
    },
  );

  test(
    'storing a copy again keeps what the server has not been told',
    () async {
      await container.read(downloadsProvider.future);
      await container.read(downloadsProvider.notifier).save(_chapter);
      await container
          .read(downloadsProvider.notifier)
          .recordProgress(
            12,
            2,
            pending: const PendingProgress(pageNum: 2, bookScrollId: '0.5000'),
          );

      await container
          .read(downloadsProvider.notifier)
          .refresh(container.read(savedChapterProvider(12))!);

      // A refresh is the answer to a copy being out of step, not a licence to
      // empty its outbox: the page, and the place within it, are still owed.
      expect(container.read(savedChapterProvider(12))?.pending?.pageNum, 2);
      expect((await _savedMeta(root, 12))['pending'], {
        'pageNum': 2,
        'bookScrollId': '0.5000',
      });
    },
  );
}

/// What a stored copy says about itself, which is what has to carry a journey
/// across a closed app: a provider holding the same thing is not.
Future<Map<String, dynamic>> _savedMeta(Directory root, int chapterId) async {
  final service = DownloadsService(root: root, profileId: _profileId);
  final dir = await service.chapterDir(chapterId);
  return jsonDecode(File('${dir.path}/meta.json').readAsStringSync())
      as Map<String, dynamic>;
}
