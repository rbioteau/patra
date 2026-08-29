import 'dart:io';

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
class ImageCacheStore {
  const ImageCacheStore();

  static const _cacheKey = 'libCachedImageData';

  Future<Directory> _dir() async {
    final temp = await getTemporaryDirectory();
    return Directory('${temp.path}/$_cacheKey');
  }

  Future<int> size() async {
    try {
      final dir = await _dir();
      if (!dir.existsSync()) return 0;
      var total = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } on Exception {
      return 0;
    }
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

final imageCacheStoreProvider = Provider<ImageCacheStore>(
  (ref) => const ImageCacheStore(),
);

/// Size of the image cache on disk; invalidate to recompute after clearing.
final imageCacheSizeProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(imageCacheStoreProvider).size(),
);
