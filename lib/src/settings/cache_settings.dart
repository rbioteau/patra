import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../keychain.dart';

/// How much disk the image cache may hold before the oldest files roll out.
///
/// A cap, never "unlimited": the cache is filled by merely browsing, and on a
/// phone it will happily outgrow the chapters the user actually chose to save.
enum ImageCacheLimit {
  mb128(128),
  mb256(256),
  mb512(512),
  gb1(1024),
  gb2(2048);

  const ImageCacheLimit(this.megabytes);

  final int megabytes;

  int get bytes => megabytes * 1024 * 1024;
}

class ImageCacheSettingsStore {
  const ImageCacheSettingsStore(this._keychain);

  final Keychain _keychain;

  static const _key = 'imageCacheLimit';
  static const defaultLimit = ImageCacheLimit.mb512;

  Future<ImageCacheLimit> load() async {
    try {
      final raw = await _keychain.read(_key);
      return ImageCacheLimit.values.firstWhere(
        (limit) => limit.name == raw,
        orElse: () => defaultLimit,
      );
    } on Exception {
      return defaultLimit;
    }
  }

  Future<void> save(ImageCacheLimit limit) async {
    try {
      await _keychain.write(_key, limit.name);
    } on Exception {
      // A preference is not worth surfacing a storage failure for.
    }
  }
}

/// The budget's store, on the device's keychain — derived, holding nothing
/// of its own.
final imageCacheSettingsProvider = Provider<ImageCacheSettingsStore>(
  (ref) => ImageCacheSettingsStore(ref.watch(keychainProvider)),
);

/// Preference restored before the app started; injected in main().
final initialImageCacheLimitProvider = Provider<ImageCacheLimit>(
  (ref) => ImageCacheSettingsStore.defaultLimit,
);

class ImageCacheLimitNotifier extends Notifier<ImageCacheLimit> {
  @override
  ImageCacheLimit build() => ref.read(initialImageCacheLimitProvider);

  Future<void> set(ImageCacheLimit limit) async {
    state = limit;
    await ref.read(imageCacheSettingsProvider).save(limit);
  }
}

final imageCacheLimitProvider =
    NotifierProvider<ImageCacheLimitNotifier, ImageCacheLimit>(
      ImageCacheLimitNotifier.new,
    );
