import 'dart:async';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/kavita_client.dart';

import '../auth/session.dart';
import 'downloads_service.dart';

/// Chapters the queue may download at once. This starting value is bounded
/// deliberately; it has not yet been tuned against a real Kavita server.
const maxConcurrentChapterDownloads = 3;

class DownloadsState {
  const DownloadsState({
    this.saved = const {},
    this.inFlight = const {},
    this.failed = const {},
    this.interrupted = const {},
    this.records = const {},
    this.batchSummary,
  });

  /// Chapters fully stored on the device, keyed by chapter id.
  final Map<int, SavedChapter> saved;

  /// Downloads queued or running, chapter id → 0..1.
  final Map<int, double> inFlight;

  /// Chapters whose download failed, so a control can offer a retry instead
  /// of silently going back to "Save". A cancel is not a failure.
  final Set<int> failed;

  /// Work the process left unfinished. It waits for an explicit retry rather
  /// than silently restarting requests during launch.
  final Set<int> interrupted;

  /// The durable record behind every projected state above.
  ///
  /// Record instances are retained for chapters that did not change, which
  /// is what lets a per-chapter provider ignore another chapter's pages.
  final Map<int, DownloadQueueRecord> records;

  /// The latest batch that still has work or a failure to account for.
  final DownloadBatchSummary? batchSummary;

  int get totalBytes =>
      saved.values.fold(0, (total, chapter) => total + chapter.bytes);

  factory DownloadsState.fromQueue(Map<int, DownloadQueueRecord> records) {
    final snapshot = Map<int, DownloadQueueRecord>.unmodifiable(records);
    final batches = <int, List<DownloadQueueRecord>>{};
    for (final record in snapshot.values) {
      final batchId = record.batchId;
      if (batchId != null) (batches[batchId] ??= []).add(record);
    }
    // A batch that is entirely on the device is over: a line counting zero of
    // what is left would be a report about nothing.
    final unfinished = batches.entries
        .where(
          (entry) => entry.value.any(
            (record) => record.status != DownloadQueueStatus.saved,
          ),
        )
        .map((entry) => entry.key);
    final latest = unfinished.isEmpty
        ? null
        : unfinished.reduce((a, b) => a > b ? a : b);

    return DownloadsState(
      records: snapshot,
      saved: {
        for (final entry in snapshot.entries) entry.key: ?entry.value.saved,
      },
      inFlight: {
        for (final entry in snapshot.entries)
          if (entry.value.isInFlight) entry.key: entry.value.progress,
      },
      failed: {
        for (final entry in snapshot.entries)
          if (entry.value.status == DownloadQueueStatus.failed) entry.key,
      },
      interrupted: {
        for (final entry in snapshot.entries)
          if (entry.value.status == DownloadQueueStatus.interrupted) entry.key,
      },
      batchSummary: latest == null
          ? null
          : DownloadBatchSummary.fromRecords(latest, batches[latest]!),
    );
  }
}

/// Where one batch stands, in the two halves a reader asks about: how many of
/// its copies are on the device, and how far through the pages of the whole
/// lot the work has got.
///
/// Counted in pages rather than copies, because a batch of four chapters is
/// not a quarter done when its shortest chapter lands.
class DownloadBatchSummary {
  const DownloadBatchSummary({
    required this.id,
    required this.done,
    required this.total,
    required this.progress,
  });

  factory DownloadBatchSummary.fromRecords(
    int id,
    List<DownloadQueueRecord> records,
  ) {
    var completedPages = 0;
    var totalPages = 0;
    var done = 0;
    for (final record in records) {
      final pages = record.totalPages > 0
          ? record.totalPages
          : record.request.pages;
      totalPages += pages;
      if (record.status == DownloadQueueStatus.saved) {
        done++;
        completedPages += pages;
      } else {
        completedPages += record.completedPages.clamp(0, pages);
      }
    }
    return DownloadBatchSummary(
      id: id,
      done: done,
      total: records.length,
      progress: totalPages == 0 ? 0 : completedPages / totalPages,
    );
  }

  final int id;
  final int done;
  final int total;
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is DownloadBatchSummary &&
      other.id == id &&
      other.done == done &&
      other.total == total &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(id, done, total, progress);
}

/// Which chapters are on the device, which are on their way, and which are
/// waiting to be given another go — and nothing about how far any of them has
/// got.
///
/// Compared **by content**: a page landing anywhere leaves a row that only
/// asked this question alone. That is the whole reason it exists, and it is
/// why the ids are the value rather than the records behind them: a set of
/// records is compared by identity, so it would answer "changed" on every
/// single page.
class DownloadMembership {
  DownloadMembership({
    required Set<int> saved,
    required Set<int> inFlight,
    required Set<int> pending,
  }) : saved = Set.unmodifiable(saved),
       inFlight = Set.unmodifiable(inFlight),
       pending = Set.unmodifiable(pending);

  final Set<int> saved;
  final Set<int> inFlight;

  /// Copies that stopped short — failed, or left unfinished by the app. They
  /// stay listed until they are retried or removed.
  final Set<int> pending;

  @override
  bool operator ==(Object other) =>
      other is DownloadMembership &&
      _sameIds(saved, other.saved) &&
      _sameIds(inFlight, other.inFlight) &&
      _sameIds(pending, other.pending);

  @override
  int get hashCode => Object.hashAll([
    ...saved.toList()..sort(),
    -1,
    ...inFlight.toList()..sort(),
    -2,
    ...pending.toList()..sort(),
  ]);
}

bool _sameIds(Set<int> a, Set<int> b) =>
    a.length == b.length && a.every(b.contains);

/// Where every profile's saved chapters live, which the **device** owns —
/// null meaning the documents directory, as the service resolves it itself.
///
/// Overridable so a test can hand the store a temp directory while still
/// letting the real provider below do the profile scoping, which is the part
/// worth exercising.
final downloadsRootProvider = Provider<Directory?>((ref) => null);

/// The service this container built, kept for the same reason
/// [kavitaClientProvider] keeps its client: Riverpod flushes a dirty provider
/// that has listeners at the end of the frame, so a session going null
/// recomputes the service while the shell is still on screen and still
/// reading through it. Per container, so it cannot outlive the profile it was
/// built for.
class _ServiceHolder {
  DownloadsService? service;
}

final _serviceHolderProvider = Provider<_ServiceHolder>(
  (ref) => _ServiceHolder(),
);

/// The store of any profile this device remembers, by [Profile.id].
///
/// Settings needs one for a profile nobody is signed in as — removing a face
/// takes its saved chapters with it, and that has to work for an account
/// deleted on the server, which nothing could ever enter again.
final profileDownloadsProvider = Provider.family<DownloadsService, String>(
  (ref, profileId) => DownloadsService(
    root: ref.watch(downloadsRootProvider),
    profileId: profileId,
  ),
);

/// The active profile's store, and what every screen but Settings reads.
///
/// Scoped to the session rather than to the device, because two people on one
/// server share every chapter id there is: filed by chapter alone, a chapter
/// one of them saved was listed in the other's Downloads tab, readable there,
/// and writing its progress back over theirs. Entering somebody else builds
/// the whole container again (`SessionScope`), so this is resolved once per
/// profile and never swapped under a screen.
final downloadsServiceProvider = Provider<DownloadsService>(
  // The no-session StateError is control flow, not a transient failure.
  retry: (retryCount, error) => null,
  (ref) {
    final profileId = ref.watch(sessionProvider.select((s) => s?.id));
    final holder = ref.read(_serviceHolderProvider);
    if (profileId == null) {
      final previous = holder.service;
      if (previous != null) return previous;
      throw StateError('No active session');
    }
    final service = ref.watch(profileDownloadsProvider(profileId));
    holder.service = service;
    return service;
  },
);

class DownloadsNotifier extends AsyncNotifier<DownloadsState> {
  final _cancelTokens = <int, CancelToken>{};
  final _records = <int, DownloadQueueRecord>{};
  final _waiters = <int, Completer<void>>{};
  final _userCancelled = <int>{};
  late DownloadsService _service;
  var _nextPriority = 0;
  int? _lastRequestedChapterId;
  var _nextBatchId = 0;
  int? _readingChapterId;
  var _disposed = false;

  @override
  Future<DownloadsState> build() async {
    ref.onDispose(() {
      _disposed = true;
      for (final token in _cancelTokens.values) {
        token.cancel('downloads disposed');
      }
    });
    _service = ref.watch(downloadsServiceProvider);
    _records
      ..clear()
      ..addAll(await _service.loadQueue());
    _nextPriority = _records.values.fold<int>(
      0,
      (next, record) => record.priority >= next ? record.priority + 1 : next,
    );
    // A batch id is a counter over this profile's queue, so a batch asked for
    // now outranks every batch the device has already written down.
    _nextBatchId = _records.values.fold<int>(
      0,
      (next, record) => record.batchId != null && record.batchId! >= next
          ? record.batchId! + 1
          : next,
    );
    // Progress the server has not been told waits in each copy, and a server
    // that answers is the moment to send it. Listened to rather than watched:
    // being offline must not put the store back to its loading state.
    ref.listen(offlineProvider, (_, offline) {
      if (!offline) unawaited(syncPendingProgress());
    });
    final next = DownloadsState.fromQueue(_records);
    unawaited(syncPendingProgress(next.saved.values));
    return next;
  }

  /// Enqueues [chapter] after its queue record is safely on disk. The future
  /// completes when this chapter finishes, fails or is cancelled. The latest
  /// request moves ahead without disturbing the FIFO order of everything
  /// already queued.
  Future<void> save(SavedChapter chapter) async {
    if (!await _ready()) return;
    final existing = _records[chapter.chapterId];
    if (existing?.isInFlight ?? false) {
      await _waiters[chapter.chapterId]?.future;
      return;
    }
    if (existing?.saved != null &&
        existing?.status == DownloadQueueStatus.saved) {
      return;
    }
    await _enqueue(chapter, saved: existing?.saved, resume: existing);
  }

  /// Starts a copy that stopped short again, from the pages it kept.
  ///
  /// Nothing is discarded first: the whole point of a durable partial is that
  /// a retry costs one page and not a chapter, and the rest of the batch is
  /// left running.
  Future<void> retry(int chapterId) async {
    final record = _records[chapterId];
    if (record == null) return;
    if (record.isInFlight || record.status == DownloadQueueStatus.saved) return;
    await _enqueue(record.request, saved: record.saved, resume: record);
  }

  /// Enqueues [chapters] as a batch. Chapters that already have a saved copy
  /// or are already in flight are skipped. Returns a map of chapter id to
  /// future that completes when that chapter finishes, fails or is cancelled.
  ///
  /// A batch carries an id of its own, which its records keep even once they
  /// are finished: the Downloads tab reports how much of *this* request is
  /// done, and a copy that lands leaves the section while the line goes on
  /// counting it.
  Future<Map<int, Future<void>>> saveBatch(List<SavedChapter> chapters) async {
    if (!await _ready()) return {};
    if (chapters.isEmpty) return {};
    final batchId = _nextBatchId++;
    var adopted = false;
    final futures = <int, Future<void>>{};
    for (final chapter in chapters) {
      final existing = _records[chapter.chapterId];
      if (existing?.isInFlight ?? false) {
        // Already coming, and asked for again as part of this lot: it joins
        // the batch rather than being left out of the count, or the summary
        // would report a batch with a chapter missing from it.
        _records[chapter.chapterId] = existing!.copyWith(batchId: batchId);
        futures[chapter.chapterId] = _waiters[chapter.chapterId]!.future;
        adopted = true;
        continue;
      }
      if (existing?.saved != null &&
          existing?.status == DownloadQueueStatus.saved) {
        // Already on the device, so there is nothing here to do: the batch
        // counts the work it was asked to do, not the shelf it stands on.
        continue;
      }
      final completer = Completer<void>();
      _waiters[chapter.chapterId] = completer;
      futures[chapter.chapterId] = completer.future;
      unawaited(
        _enqueue(
          chapter,
          saved: existing?.saved,
          resume: existing,
          batchId: batchId,
        ),
      );
    }
    // A copy already on its way joined the batch without being enqueued
    // again, so that adoption is what is written down here.
    if (adopted) {
      await _persist();
      _writeState();
    }
    return futures;
  }

  /// Stores [chapter] again over its existing copy. A failed or cancelled
  /// refresh leaves that copy intact.
  Future<void> refresh(SavedChapter chapter) async {
    if (!await _ready()) return;
    final existing = _records[chapter.chapterId];
    if (existing?.isInFlight ?? false) return;
    final saved = existing?.saved ?? state.value?.saved[chapter.chapterId];
    if (saved == null) return;
    await _enqueue(
      chapter.copyWith(pages: chapter.serverPages ?? chapter.pages),
      saved: saved,
      resume: existing,
    );
  }

  Future<void> _enqueue(
    SavedChapter chapter, {
    required SavedChapter? saved,
    DownloadQueueRecord? resume,
    int? batchId,
  }) async {
    final id = chapter.chapterId;
    final waiter = Completer<void>();
    _waiters[id] = waiter;
    _lastRequestedChapterId = id;
    _records[id] = DownloadQueueRecord(
      request: chapter,
      saved: saved,
      status: DownloadQueueStatus.queued,
      priority: _nextPriority++,
      completedPages: resume?.status == DownloadQueueStatus.saved
          ? 0
          : resume?.completedPages ?? 0,
      totalPages: resume?.status == DownloadQueueStatus.saved
          ? 0
          : resume?.totalPages ?? 0,
      // A retry keeps the batch it was asked for as part of: dropping it
      // would leave the summary counting a copy it cannot see any more.
      batchId: batchId ?? resume?.batchId,
    );
    await _persist();
    _writeState();
    _drain();
    await waiter.future;
  }

  void _drain() {
    if (_disposed) return;
    final available = maxConcurrentChapterDownloads - _cancelTokens.length;
    if (available <= 0) return;
    final queued =
        _records.values
            .where((record) => record.status == DownloadQueueStatus.queued)
            .toList()
          ..sort(_compareQueued);
    for (final record in queued.take(available)) {
      unawaited(_run(record));
    }
  }

  int _compareQueued(DownloadQueueRecord a, DownloadQueueRecord b) {
    final rank = _queueRank(a).compareTo(_queueRank(b));
    return rank != 0 ? rank : a.priority.compareTo(b.priority);
  }

  int _queueRank(DownloadQueueRecord record) {
    final id = record.request.chapterId;
    if (id == _readingChapterId) return 0;
    if (id == _lastRequestedChapterId) return 1;
    return 2;
  }

  /// Pulls a queued chapter ahead while it is the reader's current chapter.
  void prioritizeReadingChapter(int chapterId) {
    _readingChapterId = chapterId;
    _drain();
  }

  /// Clears the reader priority only if it still belongs to this chapter.
  void clearReadingChapterPriority(int chapterId) {
    if (_readingChapterId == chapterId) _readingChapterId = null;
  }

  Future<void> _run(DownloadQueueRecord queued) async {
    final id = queued.request.chapterId;
    final cancelToken = CancelToken();
    final client = ref.read(kavitaClientProvider);
    _cancelTokens[id] = cancelToken;
    _records[id] = queued.copyWith(status: DownloadQueueStatus.downloading);
    await _persist();
    _writeState();

    try {
      final saved = await _service.download(
        client: client,
        chapter: queued.request,
        onProgress: (completedPages, totalPages) async {
          final current = _records[id];
          if (current == null || !current.isInFlight) return;
          _records[id] = current.copyWith(
            completedPages: completedPages,
            totalPages: totalPages,
          );
          await _persistProgress();
          _writeState();
        },
        knownTotalPages: queued.totalPages > 0 ? queued.totalPages : null,
        cancelToken: cancelToken,
      );
      _records[id] = DownloadQueueRecord.completed(
        saved,
        priority: queued.priority,
        batchId: queued.batchId,
      );
      await _persist();
      _writeState();
    } on Object catch (error) {
      final current = _records[id] ?? queued;
      final cancelled =
          error is DioException && error.type == DioExceptionType.cancel;
      if (cancelled && _userCancelled.contains(id)) {
        await _service.discardPartial(id);
        if (current.saved case final saved?) {
          _records[id] = DownloadQueueRecord.completed(
            saved,
            priority: current.priority,
            batchId: current.batchId,
          );
        } else {
          _records.remove(id);
        }
      } else {
        _records[id] = current.copyWith(
          status: cancelled
              ? DownloadQueueStatus.interrupted
              : DownloadQueueStatus.failed,
        );
      }
      await _persist();
      _writeState();
    } finally {
      _cancelTokens.remove(id);
      _userCancelled.remove(id);
      _complete(id);
      _drain();
    }
  }

  /// Mirrors reading progress into both durable records: the copy's metadata
  /// and the queue entry every screen rebuilds its state from.
  Future<void> recordProgress(
    int chapterId,
    int pagesRead, {
    PendingProgress? pending,
  }) async {
    final record = _records[chapterId];
    final saved = record?.saved;
    if (record == null || saved == null) return;
    if (saved.pagesRead == pagesRead && saved.pending == pending) return;
    final updated = saved.copyWith(pagesRead: pagesRead, pending: pending);
    await _writeSavedCopy(record, updated);
  }

  /// The server has taken [sent]; do not clear a newer page written meanwhile.
  Future<void> clearPendingProgress(int chapterId, PendingProgress sent) async {
    final record = _records[chapterId];
    final saved = record?.saved;
    if (record == null || saved == null || saved.pending != sent) return;
    final updated = saved.copyWith(clearPending: true);
    await _writeSavedCopy(record, updated);
  }

  Future<void> _writeSavedCopy(
    DownloadQueueRecord record,
    SavedChapter updated,
  ) async {
    _records[updated.chapterId] = record.copyWith(
      request: record.status == DownloadQueueStatus.saved
          ? updated
          : record.request,
      saved: updated,
    );
    _writeState();
    await _service.writeMeta(updated);
    await _persist();
  }

  /// Sends progress the server has not been told out of every saved copy.
  Future<void> syncPendingProgress([Iterable<SavedChapter>? copies]) async {
    final KavitaClient client;
    try {
      client = ref.read(kavitaClientProvider);
    } on StateError {
      return;
    }
    final holding =
        copies ?? state.value?.saved.values ?? const <SavedChapter>[];
    for (final chapter in holding) {
      final sending = chapter.pending;
      if (sending == null) continue;
      try {
        await client.saveProgress(
          libraryId: chapter.libraryId,
          seriesId: chapter.seriesId,
          volumeId: chapter.volumeId,
          chapterId: chapter.chapterId,
          pageNum: sending.pageNum,
          bookScrollId: sending.bookScrollId,
        );
        await clearPendingProgress(chapter.chapterId, sending);
      } on DioException catch (error) {
        if (KavitaClient.isUnreachable(error)) return;
      }
    }
  }

  /// Records a server page count without silently refreshing the copy.
  Future<void> notePageTotal(int chapterId, int total) async {
    final record = _records[chapterId];
    final saved = record?.saved;
    if (record == null || saved == null) return;
    final agree = saved.pages == total;
    if (agree ? !saved.outOfDate : saved.serverPages == total) return;
    final updated = agree
        ? saved.copyWith(clearServerPages: true)
        : saved.copyWith(serverPages: total);
    await _writeSavedCopy(record, updated);
  }

  Future<void> cancel(int chapterId) async {
    if (!await _ready()) return;
    final record = _records[chapterId];
    if (record == null || !record.isInFlight) return;
    _userCancelled.add(chapterId);
    final token = _cancelTokens[chapterId];
    if (token != null) {
      token.cancel('cancelled by user');
      await _waiters[chapterId]?.future;
      return;
    }
    await _service.discardPartial(chapterId);
    _restoreOrRemove(record);
    await _persist();
    _writeState();
    _userCancelled.remove(chapterId);
    _complete(chapterId);
  }

  Future<void> remove(int chapterId) async {
    final record = _records[chapterId];
    if (record?.isInFlight ?? false) await cancel(chapterId);
    await _service.remove(chapterId);
    _records.remove(chapterId);
    await _persist();
    _writeState();
  }

  void _restoreOrRemove(DownloadQueueRecord record) {
    final id = record.request.chapterId;
    if (record.saved case final saved?) {
      _records[id] = DownloadQueueRecord.completed(
        saved,
        priority: record.priority,
        batchId: record.batchId,
      );
    } else {
      _records.remove(id);
    }
  }

  Future<bool> _ready() async {
    if (state.value != null) return true;
    try {
      await future;
      return !_disposed;
    } on Object {
      return false;
    }
  }

  Future<void> _persist() => _service.writeQueue(_records);
  Future<void> _persistProgress() =>
      _service.writeQueueAsynchronously(_records);

  void _writeState() {
    if (!_disposed) state = AsyncData(DownloadsState.fromQueue(_records));
  }

  void _complete(int chapterId) {
    final waiter = _waiters.remove(chapterId);
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }
}

final downloadsProvider =
    AsyncNotifierProvider<DownloadsNotifier, DownloadsState>(
      DownloadsNotifier.new,
    );

/// The stored copy of a chapter, if any — the reader prefers it over network.
final savedChapterProvider = Provider.family<SavedChapter?, int>(
  (ref, chapterId) => ref.watch(downloadsProvider).value?.saved[chapterId],
);

/// The durable record of one chapter's download, including its page progress.
///
/// The record of a chapter that did not change is the same instance after
/// every queue write, so a row watching this is left alone while another
/// chapter's pages land — which is what stops one page from rebuilding every
/// visible row.
final downloadRecordProvider = Provider.family<DownloadQueueRecord?, int>(
  (ref, chapterId) => ref.watch(downloadsProvider).value?.records[chapterId],
);

/// Which chapters are on the device, which are on their way and which are
/// waiting to be given another go — and nothing about how far any of them has
/// got.
///
/// A row or a section that only has to answer "is this one saved?", "is it
/// still coming?", or "is there anything here to retry?" asks this rather
/// than watching the whole state, so a page landing anywhere leaves it alone.
final downloadMembershipProvider = Provider<DownloadMembership>((ref) {
  final state = ref.watch(downloadsProvider).value;
  return DownloadMembership(
    saved: state?.saved.keys.toSet() ?? const {},
    inFlight: state?.inFlight.keys.toSet() ?? const {},
    pending: {...?state?.failed, ...?state?.interrupted},
  );
});

/// How far through one chapter's pages the fetch has got, and nothing else —
/// null where the chapter is not being fetched at all.
///
/// The one number a pill or a row repaints as pages land, so the rest of it
/// can be resubscribed to something that does not move.
final downloadProgressProvider = Provider.family<double?, int>(
  (ref, chapterId) => ref.watch(
    downloadRecordProvider(
      chapterId,
    ).select((record) => record?.isInFlight ?? false ? record?.progress : null),
  ),
);

/// The copies on the device, as ids in the order the tab lists them.
///
/// A list of ids rather than a map of copies, because what a row is *for* is
/// one copy: it reads that copy itself, so a page landing on another chapter
/// leaves the whole list alone rather than rebuilding every row in it.
final savedChapterIdsProvider = Provider<List<int>>(
  (ref) => ref.watch(
    downloadsProvider.select(
      (state) =>
          (state.value?.records.values
                  .map((record) => record.saved)
                  .whereType<SavedChapter>()
                  .toList()
                ?..sort(_bySeriesThenTitle))
              ?.map((chapter) => chapter.chapterId)
              .toList() ??
          const <int>[],
    ),
  ),
);

/// Where the batch a reader asked for stands, in one line.
///
/// Null where there is nothing left to report: a finished batch is not a
/// thing the tab should go on counting.
final batchSummaryProvider = Provider<DownloadBatchSummary?>(
  (ref) => ref.watch(downloadsProvider).value?.batchSummary,
);

int _bySeriesThenTitle(SavedChapter a, SavedChapter b) {
  final bySeries = a.seriesName.compareTo(b.seriesName);
  return bySeries != 0 ? bySeries : a.title.compareTo(b.title);
}

/// Where a chapter's pages live, for building local image paths.
final chapterDirProvider = FutureProvider.family<Directory, int>(
  (ref, chapterId) => ref.watch(downloadsServiceProvider).chapterDir(chapterId),
);
