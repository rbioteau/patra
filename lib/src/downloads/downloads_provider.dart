import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final downloadsServiceProvider = Provider<DownloadsService>(
  (ref) => DownloadsService(),
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
        current = await future;
      } on Object {
        return;
      }
    }
    if (current.saved.containsKey(chapter.chapterId) ||
        current.inFlight.containsKey(chapter.chapterId)) {
      return;
    }

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
  Future<void> recordProgress(int chapterId, int pagesRead) async {
    final current = state.value;
    final saved = current?.saved[chapterId];
    if (current == null || saved == null || saved.pagesRead == pagesRead) {
      return;
    }
    final updated = saved.copyWith(pagesRead: pagesRead);
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
