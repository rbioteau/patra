import 'dart:async';

import 'package:flutter/material.dart';

import 'src/api/client_identity.dart';
import 'src/app.dart';
import 'src/auth/session.dart';
import 'src/session_scope.dart';
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
    // The scope rather than a bare `ProviderScope`: it owns the container,
    // and builds the app again on a fresh one when the tablet is handed to
    // somebody else. What is listed here is what the *device* owns, so it is
    // what survives that; nothing a profile owns is named at all, which is
    // what makes the teardown impossible to forget half of.
    SessionScope(
      auth: auth,
      overrides: [
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
