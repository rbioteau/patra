import 'dart:async';

import 'package:flutter/material.dart';

import 'src/api/client_identity.dart';
import 'src/app.dart';
import 'src/auth/session.dart';
import 'src/catalogue/catalogue_provider.dart';
import 'src/catalogue/catalogue_store.dart';
import 'src/session_scope.dart';
import 'src/downloads/image_cache_store.dart';
import 'src/lock/profile_lock.dart';
import 'src/settings/cache_settings.dart';
import 'src/settings/locale_settings.dart';
import 'src/settings/profile_preferences.dart';
import 'src/settings/reading_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read before the auth state is put through `atLaunch`, because which
  // profiles are locked is half of that rule: a device holding one locked
  // profile has to open signed out, or the lock would never be asked for at
  // all — the picker is the only thing that asks, and such a device would
  // never see one.
  final locks = ProfileLockStore();
  await locks.load();
  // `atLaunch`, not the stored state itself: a device holding more than one
  // profile opens on the picker rather than in whoever read last.
  final auth = (await SessionStorage.load()).atLaunch(locked: locks.lockedIds);
  // Resolved before runApp so the very first request — a resumed session's —
  // already identifies itself to the server.
  final identity = await ClientIdentity.resolve();
  // The device's own defaults, under the flat keys they have always lived in,
  // and behind them what each person has chosen for themselves. Read here for
  // the reason the locks are: a preference has to be in hand before the first
  // screen is drawn, and the gate is drawn before anybody has been chosen.
  final preferences = ProfilePreferencesStore(
    deviceDirection: await ReadingSettingsStore.load(),
    deviceMagnify: await ReadingSettingsStore.loadMagnify(),
    deviceLanguage: await LocaleSettingsStore.load(),
  );
  await preferences.load();
  // What the device remembers of the active profile's shelves, read whole
  // before the first frame — but only where `atLaunch` produced a session to
  // read one for. A device landing on the picker has nobody to read for yet,
  // and `SessionScope` takes that path.
  final launchingInto = auth.active?.id;
  final catalogue = launchingInto == null
      ? null
      : CatalogueStore(profileId: launchingInto);
  await catalogue?.loadSpine();
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
        // The store instance and not three values, for the reason the lock
        // store is one: what a person chooses during a session has to survive
        // a handover building the app again on a container of its own. Which
        // person's preferences are in force is not decided here — it is a
        // function of who is reading (`profile_preferences.dart`), so this
        // is device-owned wiring like everything else in this list.
        profilePreferencesStoreProvider.overrideWithValue(preferences),
        // The budget is disk, and the device owns its disk: one cap for
        // everybody, whoever is reading.
        initialImageCacheLimitProvider.overrideWithValue(cacheLimit),
        imageCacheStoreProvider.overrideWithValue(imageCache),
        // The store instance and not its contents: a lock belongs to the
        // device, so it has to survive a handover building the app again on
        // a container of its own — and a lock *set* during a session has to
        // survive it too, which an initial value read once before `runApp`
        // could not.
        profileLockStoreProvider.overrideWithValue(locks),
        // The store rather than the spine it just read, and for the third
        // time the same reason: a catalogue fills all session long, so what
        // has to survive is the thing holding it. One key of the family and
        // not the family itself — this is the profile the app opened in, and
        // anybody else entered later gets a store of their own from the root
        // above. Which catalogue is in force is not decided here; it is a
        // function of who is reading.
        if (catalogue != null)
          profileCatalogueProvider(
            catalogue.profileId,
          ).overrideWithValue(catalogue),
      ],
      child: const PatraApp(),
    ),
  );
}
