import 'dart:io';
import 'dart:isolate';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The disk cache behind every cover and every page read online.
///
/// This is *not* the offline library: `cached_network_image` keeps what you
/// have merely looked at in the system cache directory, where the OS may
/// reclaim it at any time. Saved chapters live in the documents directory and
/// are never touched here.
///
/// It is also capped: [trim] rolls the oldest files out once the cache grows
/// past its budget, so browsing a library cannot fill the device on its own.
class ImageCacheStore {
  ImageCacheStore({Directory? root}) : _rootOverride = root;

  static const _cacheKey = 'libCachedImageData';

  /// The reader would ask for a trim on every page turn; one sweep per
  /// interval is enough to keep the cache inside its budget.
  static const _trimInterval = Duration(seconds: 20);

  final Directory? _rootOverride;
  Future<void>? _trimming;
  DateTime? _lastTrim;

  Future<Directory> _dir() async {
    final override = _rootOverride;
    if (override != null) return override;
    final temp = await getTemporaryDirectory();
    return Directory('${temp.path}/$_cacheKey');
  }

  Future<int> size() async {
    try {
      final path = (await _dir()).path;
      return await Isolate.run(() => _measure(path));
    } on Exception {
      return 0;
    }
  }

  /// Deletes the oldest files until the cache fits in [maxBytes], and answers
  /// what it holds afterwards.
  ///
  /// `flutter_cache_manager` only caps its cache by *number* of objects, and a
  /// full page scan is not a cover: here only bytes are meaningful. Sweeping
  /// the files ourselves is safe — the manager checks that a file still exists
  /// before serving its database row and drops the row when it does not, so an
  /// evicted image is simply downloaded again.
  ///
  /// "Oldest" is by write time, not by last read: `atime` is unreliable on both
  /// platforms (Android mounts `relatime`), so the file that has been in the
  /// cache the longest is the one that goes.
  ///
  /// Both halves of the sweep run **off the UI isolate**. A 512 MB cache of
  /// comic pages is thousands of files, and the walk is one syscall to list
  /// plus one to stat each of them; on the main isolate that is thousands of
  /// event-loop hops competing with the image decodes the reader is doing at
  /// that very moment — the reader is what asks for the sweep. Only
  /// [getTemporaryDirectory] has to stay here (it is a plugin call, and
  /// plugins answer on the main isolate), so the path is resolved first and
  /// the isolate is handed nothing but a String and an int.
  Future<int> trim(int maxBytes) async {
    try {
      final path = (await _dir()).path;
      return await Isolate.run(() => _sweep(path, maxBytes));
    } on Exception {
      return 0;
    }
  }

  /// [trim], throttled: at most one sweep at a time and one per
  /// [_trimInterval]. This is what the reader calls while pages pile up.
  Future<void> trimIfDue(int maxBytes) {
    final running = _trimming;
    if (running != null) return running;
    final last = _lastTrim;
    if (last != null && DateTime.now().difference(last) < _trimInterval) {
      return Future.value();
    }
    final sweep = trim(maxBytes).whenComplete(() {
      _lastTrim = DateTime.now();
      _trimming = null;
    });
    return _trimming = sweep;
  }

  Future<void> clear() async {
    // Both halves matter: the files on disk, and the decoded images Flutter
    // is still holding in memory.
    try {
      await DefaultCacheManager().emptyCache();
    } on Exception {
      // Nothing to do: the directory sweep below is the fallback.
    }
    try {
      final dir = await _dir();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the next attempt.
    }
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}

/// Adds up what the cache holds. Runs in its own isolate, so the I/O is
/// deliberately synchronous: there is no UI thread here to yield to, and the
/// async form would only buy thousands of scheduler round-trips.
int _measure(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final stat = entity.statSync();
    if (stat.type == FileSystemEntityType.notFound) continue;
    total += stat.size;
  }
  return total;
}

/// Deletes the oldest files until [path] fits in [maxBytes], and answers what
/// it holds afterwards. Runs in its own isolate; see [_measure].
int _sweep(String path, int maxBytes) {
  final dir = Directory(path);
  if (!dir.existsSync()) return 0;

  var total = 0;
  final entries = <(File, FileStat)>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final stat = entity.statSync();
    // Listed a moment ago and already gone: it is nobody's budget now.
    if (stat.type == FileSystemEntityType.notFound) continue;
    entries.add((entity, stat));
    total += stat.size;
  }
  if (total <= maxBytes) return total;

  entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
  for (final (file, stat) in entries) {
    if (total <= maxBytes) break;
    try {
      file.deleteSync();
      total -= stat.size;
    } on FileSystemException {
      // Already gone, or held open: it still counts against the budget.
    }
  }
  return total;
}

final imageCacheStoreProvider = Provider<ImageCacheStore>(
  (ref) => ImageCacheStore(),
);

/// Size of the image cache on disk; invalidate to recompute after clearing.
final imageCacheSizeProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(imageCacheStoreProvider).size(),
);
