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
  });

  /// Chapters fully stored on the device, keyed by chapter id.
  final Map<int, SavedChapter> saved;

  /// Downloads queued or running, chapter id → 0..1.
  final Map<int, double> inFlight;

  /// Chapters whose download failed, so the pill can offer a retry instead
  /// of silently going back to "Save". A cancel is not a failure.
  final Set<int> failed;

  /// Work the process left unfinished. It waits for an explicit retry rather
  /// than silently restarting requests during launch.
  final Set<int> interrupted;

  int get totalBytes =>
      saved.values.fold(0, (total, chapter) => total + chapter.bytes);

  factory DownloadsState.fromQueue(
    Map<int, DownloadQueueRecord> records,
  ) => DownloadsState(
    saved: {for (final entry in records.entries) entry.key: ?entry.value.saved},
    inFlight: {
      for (final entry in records.entries)
        if (entry.value.isInFlight) entry.key: entry.value.progress,
    },
    failed: {
      for (final entry in records.entries)
        if (entry.value.status == DownloadQueueStatus.failed) entry.key,
    },
    interrupted: {
      for (final entry in records.entries)
        if (entry.value.status == DownloadQueueStatus.interrupted) entry.key,
    },
  );
}

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

/// Where a chapter's pages live, for building local image paths.
final chapterDirProvider = FutureProvider.family<Directory, int>(
  (ref, chapterId) => ref.watch(downloadsServiceProvider).chapterDir(chapterId),
);
