import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/api/client_identity.dart';
import 'src/app.dart';
import 'src/auth/session.dart';
import 'src/downloads/image_cache_store.dart';
import 'src/settings/cache_settings.dart';
import 'src/settings/locale_settings.dart';
import 'src/settings/reading_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `atLaunch`, not the stored state itself: a device holding more than one
  // profile opens on the picker rather than in whoever read last.
  final auth = (await SessionStorage.load()).atLaunch;
  // Resolved before runApp so the very first request — a resumed session's —
  // already identifies itself to the server.
  final identity = await ClientIdentity.resolve();
  final locale = await LocaleSettingsStore.load();
  final readingDirection = await ReadingSettingsStore.load();
  final magnify = await ReadingSettingsStore.loadMagnify();
  final cacheLimit = await ImageCacheSettingsStore.load();
  // One sweep on the way in, so a cache left over the budget by the previous
  // session — or by a limit lowered on the last one — is back inside it.
  final imageCache = ImageCacheStore();
  unawaited(imageCache.trimIfDue(cacheLimit.bytes));
  runApp(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(auth),
        clientIdentityProvider.overrideWithValue(identity),
        initialLocaleProvider.overrideWithValue(locale),
        initialReadingDirectionProvider.overrideWithValue(readingDirection),
        initialMagnifyProvider.overrideWithValue(magnify),
        initialImageCacheLimitProvider.overrideWithValue(cacheLimit),
        imageCacheStoreProvider.overrideWithValue(imageCache),
      ],
      child: const PatraApp(),
    ),
  );
}
