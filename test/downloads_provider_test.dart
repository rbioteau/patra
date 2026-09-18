import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/launch/launch_animation.dart';
import 'package:patra/src/lifecycle.dart';

import 'test_support.dart';

/// Mimics Kavita: `/api/Reader/image` binds `apiKey` as a non-nullable
/// parameter, so a request without it is answered 400 — the bearer token is
/// not enough.
class _KavitaLikeAdapter implements HttpClientAdapter {
  int served = 0;
  int rejected = 0;

  /// Whether the server answers every page request with 400, as Kavita does
  /// for one carrying no `apiKey`. Mutable, so a test can refuse a run and
  /// then let one through — which is what a retry after a failure is.
  bool refuses = false;

  int maxActive = 0;
  int active = 0;
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

  /// Which pages [gate] holds, where a test wants a copy to stop with some of
  /// its pages already written. Null — the default — holds every one of them.
  Set<int>? holdPages;

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
    if (refuses || options.queryParameters['apiKey'] is! String) {
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
      final requestGate =
          chapterGates[chapterId] ??
          (holdPages == null || holdPages!.contains(page) ? gate : null);
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

/// The face this device holds, for the tests about leaving a profile and
/// coming back to it.
const _profile = Profile(
  baseUrl: 'https://kavita.test',
  accountId: 1,
  username: 'romain',
  apiKey: 'the-api-key',
);

/// A sign-in that answers as [_profile], so re-entering it needs no network.
SignIn _signInAs(Profile profile) =>
    ({
      required String baseUrl,
      required String username,
      required Credential credential,
      ClientIdentity identity = const ClientIdentity.unknown(),
    }) async => LoginResult(
      username: profile.username,
      token: signedToken(profile.accountId!),
      apiKey: profile.apiKey,
    );

ProviderContainer _downloadsContainer(
  Directory root,
  _KavitaLikeAdapter adapter, {
  bool refuses = false,
  String profileId = _profileId,
  Profile? session,
  bool launching = true,
}) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'the-api-key',
  );
  adapter.refuses = refuses;
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;
  return ProviderContainer.test(
    overrides: [
      kavitaClientProvider.overrideWithValue(client),
      downloadsServiceProvider.overrideWithValue(
        DownloadsService(root: root, profileId: profileId),
      ),
      // A session, for the tests about a profile being left and entered
      // again: everything a real one needs to be written down is the
      // keychain, and nothing else here reads it.
      if (session != null) ...[
        testKeychain(),
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [session], activeId: session.id),
        ),
        signInProvider.overrideWithValue(_signInAs(session)),
      ],
      if (!launching) isLaunchProvider.overrideWithValue(false),
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

  test('a page landing hands no other chapter a new state', () async {
    // What every row on the series screen and the Downloads tab asks of the
    // store. A percentage that watched the whole state rebuilt every one of
    // them on every single page, which is what made a batch stutter.
    await container.read(downloadsProvider.notifier).save(_chapter);
    final gate = Completer<void>();
    adapter.chapterGates[13] = gate.future;
    final other = container
        .read(downloadsProvider.notifier)
        .save(_otherChapter);
    await _waitFor(() => adapter.requestedPages.isNotEmpty);

    var finishedCopyUpdates = 0;
    final subscription = container.listen(
      savedChapterProvider(12),
      (_, _) => finishedCopyUpdates++,
    );
    addTearDown(subscription.close);

    var inFlightUpdates = 0;
    final otherSubscription = container.listen(
      downloadRecordProvider(13),
      (_, _) => inFlightUpdates++,
    );
    addTearDown(otherSubscription.close);

    gate.complete();
    await other;

    expect(
      finishedCopyUpdates,
      0,
      reason: 'a finished copy is the same copy however many pages land',
    );
    expect(
      inFlightUpdates,
      greaterThan(0),
      reason: 'the chapter being fetched still reports its own progress',
    );
  });

  test(
    'a batch is counted as it goes, and while one of it is waiting',
    () async {
      // All three held at their first request, so the state read below is a
      // state of the batch rather than wherever the fetches happen to be.
      final gates = {
        for (final id in [12, 13, 14]) id: Completer<void>(),
      };
      for (final entry in gates.entries) {
        adapter.chapterGates[entry.key] = entry.value.future;
      }
      unawaited(
        container.read(downloadsProvider.notifier).saveBatch([
          _chapter,
          _otherChapter,
          _chapterWithId(14),
        ]),
      );
      await _waitFor(
        () => container.read(downloadsProvider).value?.inFlight.length == 3,
      );

      // One of the three let through: it lands, and leaves the section it was
      // listed in — but not the batch it was asked for as part of.
      gates[13]!.complete();
      await _waitFor(
        () => (container.read(downloadsProvider).value?.saved.length ?? 0) == 1,
      );

      final summary = container.read(batchSummaryProvider);
      expect(summary, isNotNull);
      expect(summary!.done, 1);
      expect(summary.total, 3);
      // Nine pages between the three of them, and three of them written: a
      // batch of three is not a third done when its first chapter lands.
      expect(summary.progress, closeTo(1 / 3, 0.001));
      expect(
        container.read(downloadsProvider).value!.inFlight.keys,
        isNot(contains(13)),
      );

      for (final gate in gates.values) {
        if (!gate.isCompleted) gate.complete();
      }
    },
  );

  test(
    'a copy already on its way joins the batch it was asked for again',
    () async {
      final gate = Completer<void>();
      adapter.chapterGates[13] = gate.future;
      final saving = container
          .read(downloadsProvider.notifier)
          .save(_otherChapter);
      await _waitFor(
        () =>
            container.read(downloadsProvider).value?.inFlight.containsKey(13) ??
            false,
      );

      // Asked for again as part of a lot of two: it is not enqueued twice,
      // but it is counted, or the summary would report a batch with a chapter
      // missing from it.
      await container.read(downloadsProvider.notifier).saveBatch([
        _chapter,
        _otherChapter,
      ]);
      final summary = container.read(batchSummaryProvider);
      expect(summary, isNotNull);
      expect(summary!.total, 2);

      gate.complete();
      await saving;
    },
  );

  test('cancelling one of a batch leaves the rest of it running', () async {
    final gate = Completer<void>();
    adapter.chapterGates[12] = gate.future;
    unawaited(
      container.read(downloadsProvider.notifier).saveBatch([
        _chapter,
        _otherChapter,
      ]),
    );
    await _waitFor(
      () => container.read(downloadsProvider).value?.inFlight.length == 2,
    );

    await container.read(downloadsProvider.notifier).cancel(12);
    // Cancelled outright rather than failed: it is not listed as something to
    // come back to, and the copy beside it was never touched.
    final state = container.read(downloadsProvider).value!;
    expect(state.saved, isNot(contains(12)));
    expect(state.failed, isEmpty);
    expect(state.interrupted, isEmpty);
    expect(state.inFlight.keys, contains(13));

    gate.complete();
    await _waitFor(
      () => (container.read(downloadsProvider).value?.saved.length ?? 0) == 1,
    );
    expect(container.read(downloadsProvider).value!.saved.keys, [13]);
  });

  test('a batch that stopped short is still counted after a restart', () async {
    adapter.failOnPage = 1;
    await container.read(downloadsProvider.notifier).saveBatch([
      _chapter,
      _otherChapter,
    ]);
    await _waitFor(
      () => (container.read(downloadsProvider).value?.failed.length ?? 0) == 2,
    );
    container.dispose();

    // The app closed on a batch nothing had finished: what is on the device
    // here is the queue, and the tab has to be able to say so.
    final restarted = _downloadsContainer(root, adapter);
    addTearDown(restarted.dispose);
    final summary = (await restarted.read(downloadsProvider.future))
        .batchSummary;

    expect(summary, isNotNull);
    expect(summary!.done, 0);
    expect(summary.total, 2);

    // One of them is given another go, refetches only the page it was missing
    // and keeps the batch it belongs to.
    adapter
      ..failOnPage = null
      ..requestedPages.clear();
    await restarted.read(downloadsProvider.notifier).retry(12);

    expect(adapter.requestedPages, [1]);
    expect(restarted.read(downloadsProvider).value?.saved, contains(12));
    expect(restarted.read(batchSummaryProvider)?.done, 1);
  });

  test('a failed download is reported, not silently reverted', () async {
    final failing = _downloadsContainer(root, adapter, refuses: true);

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
    final failing = _downloadsContainer(root, adapter, refuses: true);
    await failing.read(downloadsProvider.future);
    await failing.read(downloadsProvider.notifier).save(_chapter);
    failing.dispose();

    final restarted = _downloadsContainer(root, adapter, refuses: true);
    addTearDown(restarted.dispose);

    final state = await restarted.read(downloadsProvider.future);
    expect(state.failed, contains(12));
    expect(state.inFlight, isEmpty);
    final otherProfile = _downloadsContainer(
      root,
      adapter,
      refuses: true,
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

  /// A copy left running, which the app then leaves the foreground in the
  /// middle of. What every lifecycle test below starts from.
  ///
  /// [holdPages] leaves some pages unheld, so the copy is stopped with those
  /// pages already on the device — which is what "resumes from where it
  /// stopped" has to mean.
  Future<({Completer<void> gate, Future<void> saving})> beginRunning(
    ProviderContainer reading, {
    Set<int>? holdPages,
  }) async {
    final gate = Completer<void>();
    adapter
      ..gate = gate.future
      ..holdPages = holdPages;
    final saving = reading.read(downloadsProvider.notifier).save(_chapter);
    await _waitFor(
      () =>
          reading.read(downloadsProvider).value?.inFlight.containsKey(12) ??
          false,
    );
    if (holdPages != null) {
      await _waitFor(
        () =>
            reading.read(downloadProgressProvider(12)) != null &&
            reading.read(downloadProgressProvider(12))! > 0,
      );
    }
    return (gate: gate, saving: saving);
  }

  test('leaving the foreground pauses what is running, and says so', () async {
    final running = await beginRunning(container);

    container
        .read(appLifecycleProvider.notifier)
        .report(AppLifecycleState.paused);
    await _waitFor(
      () =>
          container.read(downloadsProvider).value?.paused.contains(12) ?? false,
    );

    final state = container.read(downloadsProvider).value!;
    expect(state.inFlight, isEmpty);
    expect(state.failed, isEmpty);
    expect(state.interrupted, isEmpty, reason: 'a pause is not a failure');
    // The pause is written down rather than held in memory: the app that
    // comes up next has to be able to tell it from work that died.
    container.dispose();
    await pumpEventQueue();
    final restarted = _downloadsContainer(root, adapter);
    addTearDown(restarted.dispose);
    final read = await restarted.read(downloadsProvider.future);
    expect(read.paused, contains(12));
    expect(read.interrupted, isEmpty);

    running.gate.complete();
    await running.saving;
  });

  test('coming back to the foreground resumes it without asking', () async {
    final mine = _downloadsContainer(root, adapter, session: _profile);
    addTearDown(mine.dispose);
    // Page 0 lands before the app leaves; the copy stops with it written.
    final running = await beginRunning(mine, holdPages: {1, 2});
    mine.read(appLifecycleProvider.notifier).report(AppLifecycleState.paused);
    await _waitFor(
      () => mine.read(downloadsProvider).value?.paused.contains(12) ?? false,
    );
    running.gate.complete();
    await running.saving;

    adapter
      ..gate = null
      ..holdPages = null
      ..requestedPages.clear();
    mine.read(appLifecycleProvider.notifier).report(AppLifecycleState.resumed);
    await _waitFor(
      () => mine.read(downloadsProvider).value?.saved.containsKey(12) ?? false,
    );

    // Nothing was asked, and nothing already on the device was fetched
    // twice: the copy goes on from the page it stopped at, and no question
    // stands between the reader and their batch.
    expect(adapter.requestedPages, [1, 2]);
    expect(mine.read(downloadsProvider).value!.awaitingResume, isEmpty);
  });

  test('a cold start waits for the reader, and fires nothing first', () async {
    final running = await beginRunning(container, holdPages: {1, 2});
    container
        .read(appLifecycleProvider.notifier)
        .report(AppLifecycleState.paused);
    await _waitFor(
      () =>
          container.read(downloadsProvider).value?.paused.contains(12) ?? false,
    );
    running.gate.complete();
    await running.saving;
    container.dispose();
    await pumpEventQueue();

    adapter.requestedPages.clear();
    final launched = _downloadsContainer(root, adapter);
    addTearDown(launched.dispose);
    final state = await launched.read(downloadsProvider.future);

    expect(state.awaitingResume, contains(12));
    expect(state.paused, contains(12));
    expect(state.saved, isEmpty);
    // Not one page, however long the app sits there: the question is the
    // whole of what stands between a launch and a batch on somebody's data
    // plan.
    await pumpEventQueue();
    expect(adapter.requestedPages, isEmpty);

    await launched.read(downloadsProvider.notifier).resumeStopped();
    expect(launched.read(downloadsProvider).value!.awaitingResume, isEmpty);
    await _waitFor(
      () =>
          launched.read(downloadsProvider).value?.saved.containsKey(12) ??
          false,
    );
    // The page the previous run had already written is not fetched again.
    expect(adapter.requestedPages, [1, 2]);
  });

  test('the reader’s “not now” leaves the copies stopped', () async {
    final running = await beginRunning(container);
    container
        .read(appLifecycleProvider.notifier)
        .report(AppLifecycleState.paused);
    await _waitFor(
      () =>
          container.read(downloadsProvider).value?.paused.contains(12) ?? false,
    );
    running.gate.complete();
    await running.saving;
    container.dispose();
    await pumpEventQueue();

    adapter.requestedPages.clear();
    final launched = _downloadsContainer(root, adapter);
    addTearDown(launched.dispose);
    await launched.read(downloadsProvider.future);

    await launched.read(downloadsProvider.notifier).leaveStopped();
    final state = launched.read(downloadsProvider).value!;
    expect(state.awaitingResume, isEmpty, reason: 'the question was answered');
    expect(state.paused, isEmpty);
    expect(state.interrupted, contains(12));

    // And it stays stopped through the next trip out of the foreground:
    // "not now" is a decision, not a postponement of the same question.
    launched
        .read(appLifecycleProvider.notifier)
        .report(AppLifecycleState.paused);
    launched
        .read(appLifecycleProvider.notifier)
        .report(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(adapter.requestedPages, isEmpty);
    expect(launched.read(downloadsProvider).value!.interrupted, contains(12));
  });

  test(
    'leaving a profile pauses its queue, and returning resumes it',
    () async {
      final mine = _downloadsContainer(root, adapter, session: _profile);
      addTearDown(mine.dispose);
      final gate = Completer<void>();
      adapter.gate = gate.future;
      final saving = mine.read(downloadsProvider.notifier).save(_chapter);
      await _waitFor(
        () =>
            mine.read(downloadsProvider).value?.inFlight.containsKey(12) ??
            false,
      );

      // The face on the Home bar: the reader goes back to the picker, which is
      // the moment their batch has to stop being in flight — the container it
      // lives in is thrown away as soon as somebody else enters.
      await mine.read(authProvider.notifier).switchProfile();
      await _waitFor(
        () => mine.read(downloadsProvider).value?.paused.contains(12) ?? false,
      );
      gate.complete();
      await saving;
      expect(mine.read(downloadsProvider).value!.interrupted, isEmpty);

      // The app going away and coming back while the picker is up is not the
      // reader coming back: nobody is reading, and a batch fired then would
      // be the coin toss this rule exists to avoid.
      adapter.requestedPages.clear();
      mine.read(appLifecycleProvider.notifier).report(AppLifecycleState.paused);
      mine
          .read(appLifecycleProvider.notifier)
          .report(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(adapter.requestedPages, isEmpty);
      expect(mine.read(downloadsProvider).value!.paused, contains(12));

      // Their own queue only: the storage paths are per profile, so leaving
      // this one pauses nothing of anybody else's.
      final theirs = _downloadsContainer(
        root,
        adapter,
        profileId: _otherProfileId,
      );
      addTearDown(theirs.dispose);
      final other = await theirs.read(downloadsProvider.future);
      expect(other.records, isEmpty);
      expect(other.paused, isEmpty);
      expect(other.awaitingResume, isEmpty);

      // And tapping their own face again is the reader coming back to work they
      // asked for: it goes on where it left off, with nothing to answer.
      adapter
        ..gate = null
        ..requestedPages.clear();
      await mine.read(authProvider.notifier).resume(_profile);
      await _waitFor(
        () =>
            mine.read(downloadsProvider).value?.saved.containsKey(12) ?? false,
      );
      expect(adapter.requestedPages, [0, 1, 2]);
    },
  );

  test('a question the reader has been shown is not asked again', () async {
    // The reader is on the tab that lists the copies, which is where the
    // answer to the question is written down.
    await DownloadsService(root: root, profileId: _profileId).writeQueue({
      12: const DownloadQueueRecord(
        request: _chapter,
        status: DownloadQueueStatus.paused,
        priority: 0,
      ),
    });
    final mine = _downloadsContainer(root, adapter, session: _profile);
    addTearDown(mine.dispose);
    final opened = await mine.read(downloadsProvider.future);
    expect(opened.awaitingResume, contains(12));

    mine.read(downloadsProvider.notifier).seenStopped();
    await pumpEventQueue();
    final seen = mine.read(downloadsProvider).value!;
    expect(seen.awaitingResume, isEmpty, reason: 'the strip stops being drawn');
    // And nothing else changed: the copy is still paused, the app is still
    // holding it, and no page has been asked for.
    expect(seen.paused, contains(12));
    expect(seen.interrupted, isEmpty);
    expect(adapter.requestedPages, isEmpty);

    // Nor does it start on its own when the app comes back to the foreground:
    // what ended was the question, not the hold.
    mine.read(appLifecycleProvider.notifier).report(AppLifecycleState.paused);
    mine.read(appLifecycleProvider.notifier).report(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(adapter.requestedPages, isEmpty);
    expect(mine.read(downloadsProvider).value!.paused, contains(12));
  });

  test('a profile entered again finds its queue going on', () async {
    // What the container thrown away with a batch running left behind.
    await DownloadsService(root: root, profileId: _profileId).writeQueue({
      12: const DownloadQueueRecord(
        request: _chapter,
        status: DownloadQueueStatus.paused,
        priority: 0,
      ),
    });

    final returning = _downloadsContainer(
      root,
      adapter,
      session: _profile,
      launching: false,
    );
    addTearDown(returning.dispose);

    await _waitFor(
      () =>
          returning.read(downloadsProvider).value?.saved.containsKey(12) ??
          false,
    );

    // Nothing to answer and nothing to tap: entering the profile *is* the
    // reader coming back to the batch, and only a launch asks.
    expect(returning.read(downloadsProvider).value!.awaitingResume, isEmpty);
    expect(adapter.requestedPages, [0, 1, 2]);
  });
}

/// What a stored copy says about itself, which is what has to carry a journey
/// across a closed app: a provider holding the same thing is not.
Future<Map<String, dynamic>> _savedMeta(Directory root, int chapterId) async {
  final service = DownloadsService(root: root, profileId: _profileId);
  final dir = await service.chapterDir(chapterId);
  return jsonDecode(File('${dir.path}/meta.json').readAsStringSync())
      as Map<String, dynamic>;
}
