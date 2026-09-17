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
  int active = 0;
  int maxActive = 0;
  int? failOnPage;
  final requestedPages = <int>[];
  final activeChapterRequests = <int, int>{};
  int maxActiveChapters = 0;
  final startedChapters = <int>[];
  final chapterGates = <int, Future<void>>{};

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
    final chapterId = int.parse('${options.queryParameters['chapterId']}');
    final page = int.parse('${options.queryParameters['page']}');
    requestedPages.add(page);
    if (page == failOnPage) {
      return ResponseBody.fromBytes(const [], 500);
    }
    active++;
    final activeForChapter = activeChapterRequests[chapterId] ?? 0;
    if (activeForChapter == 0) startedChapters.add(chapterId);
    activeChapterRequests[chapterId] = activeForChapter + 1;
    if (activeChapterRequests.length > maxActiveChapters) {
      maxActiveChapters = activeChapterRequests.length;
    }
    if (active > maxActive) maxActive = active;
    try {
      final requestGate = chapterGates[chapterId] ?? gate;
      if (requestGate != null) {
        final cancelled = cancelFuture == null
            ? false
            : await Future.any([
                requestGate.then((_) => false),
                cancelFuture.then((_) => true),
              ]);
        if (cancelFuture == null) await requestGate;
        if (cancelled) {
          throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'cancelled',
          );
        }
      }
      served++;
      return ResponseBody.fromBytes(
        List<int>.filled(4, 9),
        200,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    } finally {
      active--;
      final remaining = activeChapterRequests[chapterId]! - 1;
      if (remaining == 0) {
        activeChapterRequests.remove(chapterId);
      } else {
        activeChapterRequests[chapterId] = remaining;
      }
    }
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

SavedChapter _chapterWithId(int chapterId) => SavedChapter(
  chapterId: chapterId,
  seriesId: 3,
  volumeId: 1,
  libraryId: 2,
  seriesName: 'Akira',
  title: 'Volume $chapterId',
  pages: 3,
  bytes: 0,
);

/// Whose store these tests are: the provider is handed a service directly
/// here, so the profile it belongs to is named rather than resolved.
const _profileId = 'https://kavita.test#1';
const _otherProfileId = 'https://kavita.test#2';

ProviderContainer _downloadsContainer(
  Directory root,
  _KavitaLikeAdapter adapter, {
  String apiKey = 'the-api-key',
  String profileId = _profileId,
}) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: apiKey,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;
  return ProviderContainer.test(
    overrides: [
      kavitaClientProvider.overrideWithValue(client),
      downloadsServiceProvider.overrideWithValue(
        DownloadsService(root: root, profileId: profileId),
      ),
    ],
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 1000; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not reached');
}

({Completer<void> gate, Future<void> saving}) _enqueueGated(
  ProviderContainer container,
  _KavitaLikeAdapter adapter,
  int chapterId,
) {
  final gate = Completer<void>();
  adapter.chapterGates[chapterId] = gate.future;
  return (
    gate: gate,
    saving: container
        .read(downloadsProvider.notifier)
        .save(_chapterWithId(chapterId)),
  );
}

void main() {
  late Directory root;
  late _KavitaLikeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    root = Directory.systemTemp.createTempSync('patra-downloads-provider');
    adapter = _KavitaLikeAdapter();
    container = _downloadsContainer(root, adapter);
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

  test('a saved chapter is still saved after a restart', () async {
    await container.read(downloadsProvider.notifier).save(_chapter);
    container.dispose();

    final restarted = _downloadsContainer(root, adapter);
    addTearDown(restarted.dispose);

    final state = await restarted.read(downloadsProvider.future);
    expect(state.saved[12]?.seriesName, 'Akira');
    expect(state.failed, isEmpty);
    expect(state.interrupted, isEmpty);
  });

  test('a tap before the first scan finishes is not dropped', () async {
    // No prior read: the notifier is still scanning when save() is called.
    await container.read(downloadsProvider.notifier).save(_chapter);

    expect(
      container.read(downloadsProvider).value!.saved.containsKey(12),
      isTrue,
    );
  });

  test('a committed copy wins the crash before queue completion', () async {
    final service = DownloadsService(root: root, profileId: _profileId);
    await service.download(
      client: container.read(kavitaClientProvider),
      chapter: _chapter,
      onProgress: (_, _) {},
    );
    await service.writeQueue({
      12: const DownloadQueueRecord(
        request: _chapter,
        status: DownloadQueueStatus.downloading,
        priority: 0,
        completedPages: 3,
        totalPages: 3,
      ),
    });
    container.dispose();

    final restarted = _downloadsContainer(root, adapter);
    addTearDown(restarted.dispose);
    final state = await restarted.read(downloadsProvider.future);

    expect(state.saved, contains(12));
    expect(state.interrupted, isEmpty);
    expect(state.failed, isEmpty);
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
    await _waitFor(() => adapter.activeChapterRequests.length == 2);

    expect(
      container.read(downloadsProvider).value!.inFlight.keys,
      containsAll([12, 13]),
    );
    expect(
      adapter.maxActiveChapters,
      2,
      reason: 'both queued chapters may run within the configured cap',
    );

    gate.complete();
    await Future.wait([first, second]);
    final state = container.read(downloadsProvider).value!;
    expect(state.saved.keys, containsAll([12, 13]));
    expect(state.inFlight, isEmpty);
  });

  test('pages of one chapter are fetched concurrently', () async {
    final gate = Completer<void>();
    adapter.gate = gate.future;

    final saving = container.read(downloadsProvider.notifier).save(_chapter);
    await _waitFor(() => adapter.maxActive > 1);

    expect(adapter.maxActive, greaterThan(1));
    gate.complete();
    await saving;
  });

  test('chapter concurrency never exceeds its configured cap', () async {
    final pending = {
      for (var id = 1; id <= maxConcurrentChapterDownloads + 2; id++)
        id: _enqueueGated(container, adapter, id),
    };

    await _waitFor(
      () =>
          adapter.activeChapterRequests.length == maxConcurrentChapterDownloads,
    );

    expect(adapter.maxActiveChapters, maxConcurrentChapterDownloads);
    for (final item in pending.values) {
      item.gate.complete();
    }
    await Future.wait([for (final item in pending.values) item.saving]);
  });

  test('latest request overtakes the queue and leaves the rest FIFO', () async {
    final nextInFifo = maxConcurrentChapterDownloads + 1;
    final latest = maxConcurrentChapterDownloads + 2;
    final pending = <int, ({Completer<void> gate, Future<void> saving})>{};
    for (var id = 1; id <= maxConcurrentChapterDownloads; id++) {
      pending[id] = _enqueueGated(container, adapter, id);
      await _waitFor(() => adapter.activeChapterRequests.length == id);
    }
    pending[nextInFifo] = _enqueueGated(container, adapter, nextInFifo);
    pending[latest] = _enqueueGated(container, adapter, latest);
    await _waitFor(
      () =>
          container.read(downloadsProvider).value!.inFlight.length ==
          maxConcurrentChapterDownloads + 2,
    );

    pending[1]!.gate.complete();
    await _waitFor(
      () => adapter.startedChapters.length > maxConcurrentChapterDownloads,
    );
    expect(adapter.startedChapters[maxConcurrentChapterDownloads], latest);

    pending[2]!.gate.complete();
    await _waitFor(
      () => adapter.startedChapters.length > maxConcurrentChapterDownloads + 1,
    );
    expect(
      adapter.startedChapters[maxConcurrentChapterDownloads + 1],
      nextInFifo,
    );

    for (final item in pending.values.where((item) => !item.gate.isCompleted)) {
      item.gate.complete();
    }
    await Future.wait([for (final item in pending.values) item.saving]);
  });

  test('the chapter being read overtakes the latest request', () async {
    final reading = maxConcurrentChapterDownloads + 1;
    final latest = maxConcurrentChapterDownloads + 2;
    final pending = <int, ({Completer<void> gate, Future<void> saving})>{};
    for (var id = 1; id <= maxConcurrentChapterDownloads; id++) {
      pending[id] = _enqueueGated(container, adapter, id);
      await _waitFor(() => adapter.activeChapterRequests.length == id);
    }
    pending[reading] = _enqueueGated(container, adapter, reading);
    pending[latest] = _enqueueGated(container, adapter, latest);
    await _waitFor(
      () =>
          container.read(downloadsProvider).value!.inFlight.length ==
          maxConcurrentChapterDownloads + 2,
    );

    container
        .read(downloadsProvider.notifier)
        .prioritizeReadingChapter(reading);
    pending[1]!.gate.complete();
    await _waitFor(
      () => adapter.startedChapters.length > maxConcurrentChapterDownloads,
    );

    expect(adapter.startedChapters[maxConcurrentChapterDownloads], reading);
    for (final item in pending.values.where((item) => !item.gate.isCompleted)) {
      item.gate.complete();
    }
    await Future.wait([for (final item in pending.values) item.saving]);
  });

  test('a failed download is reported, not silently reverted', () async {
    final failing = _downloadsContainer(root, adapter, apiKey: '');

    await failing.read(downloadsProvider.future);
    await failing.read(downloadsProvider.notifier).save(_chapter);

    final state = failing.read(downloadsProvider).value!;
    expect(adapter.rejected, greaterThan(0));
    expect(state.saved, isEmpty);
    expect(state.inFlight, isEmpty);
    expect(state.failed, contains(12), reason: 'the pill offers a retry');
  });

  test('retry fetches only pages the failed partial is missing', () async {
    adapter.failOnPage = 1;
    await container.read(downloadsProvider.notifier).save(_chapter);

    final service = DownloadsService(root: root, profileId: _profileId);
    final partial = File(
      '${(await service.chapterDir(12)).path}/'
      '${DownloadsService.stagingDirName}/'
      '${DownloadsService.pageFileName(0)}',
    );
    expect(partial.existsSync(), isTrue);
    final firstWrite = partial.lastModifiedSync();
    expect(adapter.requestedPages, [0, 1, 2]);
    container.dispose();
    final restarted = _downloadsContainer(root, adapter);
    addTearDown(restarted.dispose);
    expect(
      (await restarted.read(downloadsProvider.future)).failed,
      contains(12),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    adapter
      ..failOnPage = null
      ..requestedPages.clear();
    await restarted.read(downloadsProvider.notifier).save(_chapter);

    expect(adapter.requestedPages, [1]);
    expect((await service.pageFile(12, 0)).lastModifiedSync(), firstWrite);
    expect(restarted.read(downloadsProvider).value!.saved, contains(12));
  });

  test('a failed download is still failed after a restart', () async {
    final failing = _downloadsContainer(root, adapter, apiKey: '');
    await failing.read(downloadsProvider.future);
    await failing.read(downloadsProvider.notifier).save(_chapter);
    failing.dispose();

    final restarted = _downloadsContainer(root, adapter, apiKey: '');
    addTearDown(restarted.dispose);

    final state = await restarted.read(downloadsProvider.future);
    expect(state.failed, contains(12));
    expect(state.inFlight, isEmpty);
    final otherProfile = _downloadsContainer(
      root,
      adapter,
      apiKey: '',
      profileId: _otherProfileId,
    );
    addTearDown(otherProfile.dispose);
    final otherState = await otherProfile.read(downloadsProvider.future);
    expect(otherState.failed, isEmpty);
    expect(otherState.interrupted, isEmpty);
  });

  test('an unfinished download is interrupted after a restart', () async {
    final gate = Completer<void>();
    adapter.gate = gate.future;
    final saving = container.read(downloadsProvider.notifier).save(_chapter);
    await _waitFor(
      () =>
          container.read(downloadsProvider).value?.inFlight.containsKey(12) ??
          false,
    );
    expect(container.read(downloadsProvider).value!.inFlight, contains(12));
    container.dispose();

    final restarted = _downloadsContainer(root, adapter);
    addTearDown(restarted.dispose);

    final state = await restarted.read(downloadsProvider.future);
    expect(state.interrupted, contains(12));
    expect(state.failed, isEmpty);
    expect(state.inFlight, isEmpty);
    gate.complete();
    await saving;
  });

  test('cancelling removes the durable entry and partial files', () async {
    final gate = Completer<void>();
    adapter.gate = gate.future;
    final saving = container.read(downloadsProvider.notifier).save(_chapter);
    await pumpEventQueue();

    await container.read(downloadsProvider.notifier).cancel(12);
    await saving;

    final state = container.read(downloadsProvider).value!;
    expect(state.saved, isEmpty);
    expect(state.inFlight, isEmpty);
    expect(state.failed, isEmpty);
    expect(state.interrupted, isEmpty);
    expect(
      (await DownloadsService(root: root, profileId: _profileId).chapterDir(12))
          .existsSync(),
      isFalse,
    );

    container.dispose();
    final restarted = _downloadsContainer(root, adapter);
    addTearDown(restarted.dispose);
    final restartedState = await restarted.read(downloadsProvider.future);
    expect(restartedState.saved, isEmpty);
    expect(restartedState.failed, isEmpty);
    expect(restartedState.interrupted, isEmpty);
    gate.complete();
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
      await _waitFor(
        () => container.read(savedChapterProvider(12))?.pending == null,
      );

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
