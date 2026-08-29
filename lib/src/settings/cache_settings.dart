import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  static const _storage = FlutterSecureStorage();
  static const _key = 'imageCacheLimit';
  static const defaultLimit = ImageCacheLimit.mb512;

  static Future<ImageCacheLimit> load() async {
    try {
      final raw = await _storage.read(key: _key);
      return ImageCacheLimit.values.firstWhere(
        (limit) => limit.name == raw,
        orElse: () => defaultLimit,
      );
    } on Exception {
      return defaultLimit;
    }
  }

  static Future<void> save(ImageCacheLimit limit) async {
    try {
      await _storage.write(key: _key, value: limit.name);
    } on Exception {
      // A preference is not worth surfacing a storage failure for.
    }
  }
}

/// Preference restored before the app started; injected in main().
final initialImageCacheLimitProvider = Provider<ImageCacheLimit>(
  (ref) => ImageCacheSettingsStore.defaultLimit,
);

class ImageCacheLimitNotifier extends Notifier<ImageCacheLimit> {
  @override
  ImageCacheLimit build() => ref.read(initialImageCacheLimitProvider);

  Future<void> set(ImageCacheLimit limit) async {
    state = limit;
    await ImageCacheSettingsStore.save(limit);
  }
}

final imageCacheLimitProvider =
    NotifierProvider<ImageCacheLimitNotifier, ImageCacheLimit>(
      ImageCacheLimitNotifier.new,
    );
