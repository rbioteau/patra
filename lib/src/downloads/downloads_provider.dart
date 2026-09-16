import 'dart:async';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/kavita_client.dart';

import '../auth/session.dart';
import 'downloads_service.dart';

class DownloadsState {
  const DownloadsState({
    this.saved = const {},
    this.inFlight = const {},
    this.failed = const {},
  });

  /// Chapters fully stored on the device, keyed by chapter id.
  final Map<int, SavedChapter> saved;

  /// Downloads in progress, chapter id → 0..1.
  final Map<int, double> inFlight;

  /// Chapters whose download failed, so the pill can offer a retry instead
  /// of silently going back to "Save". A cancel is not a failure.
  final Set<int> failed;

  int get totalBytes =>
      saved.values.fold(0, (total, chapter) => total + chapter.bytes);

  DownloadsState copyWith({
    Map<int, SavedChapter>? saved,
    Map<int, double>? inFlight,
    Set<int>? failed,
  }) => DownloadsState(
    saved: saved ?? this.saved,
    inFlight: inFlight ?? this.inFlight,
    failed: failed ?? this.failed,
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
  var _disposed = false;

  @override
  Future<DownloadsState> build() async {
    ref.onDispose(() {
      _disposed = true;
      for (final token in _cancelTokens.values) {
        token.cancel('downloads disposed');
      }
      _cancelTokens.clear();
    });
    final saved = await ref.watch(downloadsServiceProvider).scan();
    // Progress the server has not been told waits in each copy, and a server
    // that answers is the moment to send it. Listened to rather than watched:
    // being offline must not put the store back to its loading state.
    ref.listen(offlineProvider, (_, offline) {
      if (!offline) unawaited(syncPendingProgress());
    });
    // A server that is already answering is the same event as one coming
    // back, and the one that matters most: it is how a journey the app was
    // closed in the middle of reaches the server, since nothing else left
    // running knows there is anything to send.
    unawaited(syncPendingProgress(saved.values));
    return DownloadsState(saved: saved);
  }

  /// Downloads every page of [chapter] for offline reading. [chapter] carries
  /// the metadata to store alongside the pages; its `bytes` is ignored.
  Future<void> save(SavedChapter chapter) async {
    // The first scan may still be running when the pill is tapped; waiting
    // beats dropping the tap on the floor.
    var current = state.value;
    if (current == null) {
      try {
        await future;
      } on Object {
        return;
      }
      // Re-read rather than keep what the scan returned: a second pill tapped
      // during that same wait resumes first and writes its own entry, and
      // building on the stale snapshot would drop it — leaving a download
      // running that nothing on screen tracks any more.
      current = state.value;
      if (current == null) return;
    }
    if (current.saved.containsKey(chapter.chapterId) ||
        current.inFlight.containsKey(chapter.chapterId)) {
      return;
    }
    await _store(chapter);
  }

  /// Stores [chapter] again, over the copy that is already there: the answer
  /// to a copy being out of step with the server, which is never silently
  /// refetched (ADR-0009) and never silently kept.
  ///
  /// Refetched at the count the server gives now rather than the one the copy
  /// was made with — for a book the service asks the server itself, and a
  /// chapter of pictures is asked for its pages by the number it has today,
  /// which is the only reason storing it again puts the two back in step.
  /// Not [save], which is what refuses a chapter it already holds.
  Future<void> refresh(SavedChapter chapter) async {
    final current = state.value;
    if (current == null || current.inFlight.containsKey(chapter.chapterId)) {
      return;
    }
    await _store(chapter.copyWith(pages: chapter.serverPages ?? chapter.pages));
  }

  /// The download itself, which [save] and [refresh] share: the two differ
  /// only in whether a copy is already there.
  Future<void> _store(SavedChapter chapter) async {
    final current = state.value;
    if (current == null) return;
    final cancelToken = CancelToken();
    _cancelTokens[chapter.chapterId] = cancelToken;
    _write(
      current.copyWith(
        inFlight: {...current.inFlight, chapter.chapterId: 0},
        failed: {...current.failed}..remove(chapter.chapterId),
      ),
    );

    try {
      final saved = await ref
          .read(downloadsServiceProvider)
          .download(
            client: ref.read(kavitaClientProvider),
            chapter: chapter,
            onProgress: (progress) => _setProgress(chapter.chapterId, progress),
            cancelToken: cancelToken,
          );
      _finish(chapter.chapterId, saved: saved);
    } on Object catch (error) {
      // The service already removed the partial files. A deliberate cancel
      // is not a failure and must not offer a retry.
      final cancelled =
          error is DioException && error.type == DioExceptionType.cancel;
      _finish(chapter.chapterId, failed: !cancelled);
    } finally {
      _cancelTokens.remove(chapter.chapterId);
    }
  }

  /// Mirrors reading progress into the stored copy, so the Downloads tab can
  /// show what has been read even with no server in sight.
  ///
  /// [pending] is what the server has not been told: the number being sent
  /// and, for a book, the place within the page. Left alone where it is not
  /// given, because the server's own number arriving back down is not
  /// progress anybody has to post — and posting it without the anchor would
  /// cost a reader the words they had already read.
  Future<void> recordProgress(
    int chapterId,
    int pagesRead, {
    PendingProgress? pending,
  }) async {
    final current = state.value;
    final saved = current?.saved[chapterId];
    if (current == null || saved == null) return;
    if (saved.pagesRead == pagesRead && saved.pending == pending) return;
    final updated = saved.copyWith(pagesRead: pagesRead, pending: pending);
    _write(current.copyWith(saved: {...current.saved, chapterId: updated}));
    await ref.read(downloadsServiceProvider).writeMeta(updated);
  }

  /// The server has taken [sent]: the copy no longer holds it.
  ///
  /// Nothing to do where the copy has moved on since, which is the ordinary
  /// case in a chapter being read: a page turned while a post was in flight
  /// has already written a newer number over this one, and clearing that
  /// would lose the newer one instead.
  Future<void> clearPendingProgress(int chapterId, PendingProgress sent) async {
    final current = state.value;
    final saved = current?.saved[chapterId];
    if (current == null || saved == null || saved.pending != sent) return;
    final updated = saved.copyWith(clearPending: true);
    _write(current.copyWith(saved: {...current.saved, chapterId: updated}));
    await ref.read(downloadsServiceProvider).writeMeta(updated);
  }

  /// Sends progress the server has not been told: the page a reader is on,
  /// with the place within it for a book, out of every copy holding some.
  ///
  /// [copies] is whose to send, and is named by a caller that holds them
  /// before the state does — the store, which has just read them off disk.
  /// Asked for when a server starts answering, and when the store is read:
  /// the second is how a journey the app was closed in the middle of reaches
  /// the server, since nothing else is left running that knows about it.
  Future<void> syncPendingProgress([Iterable<SavedChapter>? copies]) async {
    final KavitaClient client;
    try {
      client = ref.read(kavitaClientProvider);
    } on StateError {
      return; // signed out: nobody to tell
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
        // Gone away again: every copy behind this one keeps what it holds,
        // and the next time the server answers is the next time sending it
        // is worth trying.
        if (KavitaClient.isUnreachable(error)) return;
        // Refused rather than out of reach — this one is not going to be
        // taken, but the copies behind it still get their turn.
      }
    }
  }

  /// What the server now says [chapterId] is made of: the number of pages it
  /// counts, which a copy was made with a number of its own (ADR-0009).
  ///
  /// Where the two disagree the copy is named out of date — never silently
  /// refetched, and never silently kept, because resuming at the wrong page
  /// is the one failure that makes a saved copy look broken. It is still
  /// opened, and still reads. Where the server comes back to the copy's own
  /// count, the name comes off.
  Future<void> notePageTotal(int chapterId, int total) async {
    final current = state.value;
    final saved = current?.saved[chapterId];
    if (current == null || saved == null) return;
    final agree = saved.pages == total;
    if (agree ? !saved.outOfDate : saved.serverPages == total) return;
    final updated = agree
        ? saved.copyWith(clearServerPages: true)
        : saved.copyWith(serverPages: total);
    _write(current.copyWith(saved: {...current.saved, chapterId: updated}));
    await ref.read(downloadsServiceProvider).writeMeta(updated);
  }

  void cancel(int chapterId) {
    _cancelTokens[chapterId]?.cancel('cancelled by user');
  }

  Future<void> remove(int chapterId) async {
    await ref.read(downloadsServiceProvider).remove(chapterId);
    final current = state.value;
    if (current == null) return;
    _write(
      current.copyWith(
        saved: {...current.saved}..remove(chapterId),
        failed: {...current.failed}..remove(chapterId),
      ),
    );
  }

  void _setProgress(int chapterId, double progress) {
    final current = state.value;
    if (current == null || !current.inFlight.containsKey(chapterId)) return;
    _write(
      current.copyWith(inFlight: {...current.inFlight, chapterId: progress}),
    );
  }

  void _finish(int chapterId, {SavedChapter? saved, bool failed = false}) {
    final current = state.value;
    if (current == null) return;
    // Built with statements on purpose: `cond ? {...} : {...}..remove(id)`
    // applies the cascade to *both* branches.
    final nextFailed = {...current.failed};
    if (failed) {
      nextFailed.add(chapterId);
    } else {
      nextFailed.remove(chapterId);
    }
    _write(
      current.copyWith(
        saved: saved == null
            ? current.saved
            : {...current.saved, chapterId: saved},
        inFlight: {...current.inFlight}..remove(chapterId),
        failed: nextFailed,
      ),
    );
  }

  void _write(DownloadsState next) {
    if (_disposed) return;
    state = AsyncData(next);
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
