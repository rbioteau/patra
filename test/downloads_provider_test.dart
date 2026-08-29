import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verso/src/api/kavita_client.dart';
import 'package:verso/src/auth/session.dart';
import 'package:verso/src/downloads/downloads_provider.dart';
import 'package:verso/src/downloads/downloads_service.dart';

/// Mimics Kavita: `/api/Reader/image` binds `apiKey` as a non-nullable
/// parameter, so a request without it is answered 400 — the bearer token is
/// not enough.
class _KavitaLikeAdapter implements HttpClientAdapter {
  int served = 0;
  int rejected = 0;

  /// Holds every page request open, so a test can look at the state while
  /// downloads are still running.
  Future<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

void main() {
  late Directory root;
  late _KavitaLikeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    root = Directory.systemTemp.createTempSync('verso-downloads-provider');
    adapter = _KavitaLikeAdapter();
    final client = KavitaClient(
      baseUrl: 'http://kavita.test',
      token: 'token',
      refreshToken: 'refresh',
      apiKey: 'the-api-key',
    );
    client.httpClient.httpClientAdapter = adapter;
    client.refreshHttpClient.httpClientAdapter = adapter;
    container = ProviderContainer.test(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: root),
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
      refreshToken: 'refresh',
      // No API key: the server answers 400, like Kavita does.
      apiKey: '',
    );
    client.httpClient.httpClientAdapter = adapter;
    client.refreshHttpClient.httpClientAdapter = adapter;
    final failing = ProviderContainer.test(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: root),
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
    // Persisted, so the Downloads tab still knows after a restart.
    final meta = File('${root.path}/12/meta.json');
    expect(jsonDecode(meta.readAsStringSync())['pagesRead'], 2);

    // And a fresh scan reads it back.
    final rescanned = await DownloadsService(root: root).scan();
    expect(rescanned[12]?.pagesRead, 2);
    expect(rescanned[12]?.progress, closeTo(2 / 3, 0.001));
    expect(rescanned[12]?.isRead, isFalse);
  });
}
