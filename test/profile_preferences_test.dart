import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/settings/cache_settings.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';

import 'test_support.dart';

/// Two people sharing one address, which is what a family tablet is.
final _romain = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-romain',
  token: signedToken(1),
);
final _lea = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 2,
  username: 'lea',
  apiKey: 'key-lea',
  token: signedToken(2),
);

/// A container reading as [active], on [store].
/// [keychain] is the **device's** side of these settings: what a `set` with
/// nobody reading falls back to writing, and where a chosen language also
/// lands. A person's own choices go to [store]; these are two stores because
/// they answer two different questions.
ProviderContainer _container({
  required ProfilePreferencesStore store,
  Profile? active,
  MemoryKeychain? keychain,
}) {
  final container = ProviderContainer(
    overrides: [
      testKeychain(keychain),
      profilePreferencesStoreProvider.overrideWithValue(store),
      initialAuthStateProvider.overrideWithValue(
        AuthState(profiles: [_romain, _lea], activeId: active?.id),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the store', () {
    test('remembers a direction under the profile that chose it', () async {
      final store = await preferencesStore();
      await store.setDirection(_romain.id, ReadingDirection.rightToLeft);

      expect(store.of(_romain.id).direction, ReadingDirection.rightToLeft);
      expect(
        store.of(_lea.id).direction,
        isNull,
        reason: 'nobody else chose it, so nothing of theirs moved',
      );
    });

    test(
      "a profile that never chose starts from the device's default",
      () async {
        // Which is what makes this an upgrade nobody notices: a device set
        // before it held profiles keeps its settings, for everybody on it.
        final store = await preferencesStore(
          deviceDirection: ReadingDirection.verticalScroll,
          deviceMagnify: true,
          deviceLanguage: const Locale('fr'),
        );

        expect(store.directionFor(_lea.id), ReadingDirection.verticalScroll);
        expect(store.magnifyFor(_lea.id), isTrue);
        expect(store.languageFor(_lea.id), const Locale('fr'));
      },
    );

    test('following the device is a choice, not the absence of one', () async {
      // The two readings of null had to be told apart somewhere: never having
      // chosen falls back to the device's default, while *choosing* to follow
      // the device is a person saying they want the system's language.
      final store = await preferencesStore(deviceLanguage: const Locale('fr'));
      expect(store.languageFor(_romain.id), const Locale('fr'));

      await store.setLanguage(_romain.id, null);
      expect(
        store.languageFor(_romain.id),
        isNull,
        reason: "the device's default must not stand back in for it",
      );
      expect(store.languageFor(_lea.id), const Locale('fr'));
    });

    test('what is chosen is written down and reads back', () async {
      final vault = MemoryPreferencesVault();
      final store = await preferencesStore(vault: vault);
      await store.setDirection(_romain.id, ReadingDirection.rightToLeft);
      await store.setMagnify(_romain.id, true);
      await store.setLanguage(_lea.id, const Locale('fr'));

      final reopened = await preferencesStore(
        vault: MemoryPreferencesVault(vault.value),
      );
      expect(reopened.of(_romain.id).direction, ReadingDirection.rightToLeft);
      expect(reopened.of(_romain.id).magnify, isTrue);
      expect(reopened.languageFor(_lea.id), const Locale('fr'));
      expect(reopened.of(_lea.id).direction, isNull);
    });

    test(
      'a row of the wrong shape costs a preference, never the app',
      () async {
        // Loaded before `runApp`, so the safe direction is the device's default
        // — the person is then on it and can choose again.
        final store = await preferencesStore(
          vault: MemoryPreferencesVault('{"${_romain.id}": {"direction": 7}}'),
          deviceDirection: ReadingDirection.rightToLeft,
        );
        expect(store.directionFor(_romain.id), ReadingDirection.rightToLeft);

        final broken = await preferencesStore(
          vault: MemoryPreferencesVault('not json at all'),
        );
        expect(broken.byProfile, isEmpty);
      },
    );

    test('a language this build dropped reads as no choice at all', () async {
      // Rather than as a language with no translations behind it, which is
      // the same answer the device's own setting gets.
      final store = await preferencesStore(
        vault: MemoryPreferencesVault('{"${_romain.id}": {"language": "xh"}}'),
        deviceLanguage: const Locale('fr'),
      );
      expect(store.languageFor(_romain.id), const Locale('fr'));
    });

    test('forgetting a profile takes its preferences with it', () async {
      final vault = MemoryPreferencesVault();
      final store = await preferencesStore(vault: vault);
      await store.setDirection(_romain.id, ReadingDirection.rightToLeft);
      await store.setDirection(_lea.id, ReadingDirection.verticalScroll);

      await store.forget(_romain.id);
      expect(store.of(_romain.id).direction, isNull);
      expect(store.of(_lea.id).direction, ReadingDirection.verticalScroll);
      expect(vault.value, isNot(contains(_romain.id)));
    });

    test('the last profile forgotten leaves nothing in the keychain', () async {
      final vault = MemoryPreferencesVault();
      final store = await preferencesStore(vault: vault);
      await store.setMagnify(_romain.id, true);

      await store.forget(_romain.id);
      expect(vault.value, isNull);
      expect(vault.clears, 1);
    });
  });

  group('the preferences in force', () {
    test('are the reading profile’s own', () async {
      final store = await preferencesStore(
        deviceDirection: ReadingDirection.leftToRight,
      );
      await store.setDirection(_romain.id, ReadingDirection.rightToLeft);
      await store.setMagnify(_romain.id, true);
      await store.setLanguage(_romain.id, const Locale('fr'));

      final his = _container(store: store, active: _romain);
      expect(
        his.read(defaultReadingDirectionProvider),
        ReadingDirection.rightToLeft,
      );
      expect(his.read(magnifyProvider), isTrue);
      expect(his.read(localeProvider), const Locale('fr'));

      // The next person to be handed the tablet, on a container of their own
      // — which is what `SessionScope` builds for them.
      final hers = _container(store: store, active: _lea);
      expect(
        hers.read(defaultReadingDirectionProvider),
        ReadingDirection.leftToRight,
      );
      expect(hers.read(magnifyProvider), isFalse);
      expect(hers.read(localeProvider), isNull);
    });

    test('follow whoever enters a container nobody has read in', () async {
      // The one way into a session that does *not* rebuild the app: the first
      // profile entered in a container. Preferences are a function of who is
      // reading, so this needs no wiring of its own.
      final store = await preferencesStore();
      await store.setDirection(_lea.id, ReadingDirection.verticalScroll);

      final container = ProviderContainer(
        overrides: [
          profilePreferencesStoreProvider.overrideWithValue(store),
          initialAuthStateProvider.overrideWithValue(
            AuthState(profiles: [_romain, _lea]),
          ),
          signInProvider.overrideWithValue(_signInAs(_lea)),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(defaultReadingDirectionProvider),
        ReadingDirection.leftToRight,
        reason: 'nobody is reading yet, so this is the gate',
      );

      await container.read(authProvider.notifier).resume(_lea);
      expect(
        container.read(defaultReadingDirectionProvider),
        ReadingDirection.verticalScroll,
      );
    });

    test('at the gate are the device’s own', () async {
      // The picker and the sign-in form stand in front of every session and
      // have nobody to ask.
      final store = await preferencesStore(deviceLanguage: const Locale('fr'));
      await store.setLanguage(_romain.id, null);

      final gate = _container(store: store);
      expect(gate.read(localeProvider), const Locale('fr'));
    });

    test('are what a choice changes, for that person alone', () async {
      final store = await preferencesStore();
      final his = _container(store: store, active: _romain);

      await his
          .read(defaultReadingDirectionProvider.notifier)
          .set(ReadingDirection.rightToLeft);
      await his.read(magnifyProvider.notifier).set(true);

      expect(
        his.read(defaultReadingDirectionProvider),
        ReadingDirection.rightToLeft,
      );
      expect(store.directionFor(_lea.id), ReadingDirection.leftToRight);
      expect(store.magnifyFor(_lea.id), isFalse);
    });

    test('are not recomputed because a token moved', () async {
      // `Profile` has no `==`, so a JWT renewal makes a new session instance
      // several times a session, and watching the session rather than its id
      // rebuilds all three notifiers each time — `localeProvider` among them,
      // which is what `MaterialApp.locale` reads. Nothing visible breaks,
      // because the store answers with the same value; counting is therefore
      // the only way to pin it, and `kavitaClientProvider` documents the same
      // care for the same reason.
      final store = _CountingStore();
      final his = _container(store: store, active: _romain);
      his.listen(
        defaultReadingDirectionProvider,
        (_, _) {},
        fireImmediately: true,
      );
      expect(store.reads, 1);

      await his.read(authProvider.notifier).updateToken('a-fresh-jwt');
      his.read(defaultReadingDirectionProvider);
      expect(store.reads, 1, reason: 'the id did not move, so nothing did');
    });

    test('survive the lock in front of them being taken off', () async {
      // Removing a profile takes its preferences, its lock and its saved
      // chapters together. Clearing a *PIN* is none of those: the person is
      // still there, and what they read in is no business of the lock's.
      final locks = await lockStore();
      final store = await preferencesStore();
      await store.setDirection(_romain.id, ReadingDirection.rightToLeft);
      await locks.set(_romain.id, '1234');

      await locks.clear(_romain.id);
      expect(store.directionFor(_romain.id), ReadingDirection.rightToLeft);
    });

    test('with nobody reading are the device’s to keep', () async {
      // No screen reaches this — Settings is inside a session — but a `set`
      // that silently kept nothing would be worse than one that writes the
      // only thing such a choice could belong to.
      final device = MemoryKeychain();
      final store = await preferencesStore();
      final gate = _container(store: store, keychain: device);

      await gate
          .read(defaultReadingDirectionProvider.notifier)
          .set(ReadingDirection.rightToLeft);
      await gate.read(magnifyProvider.notifier).set(true);

      expect(device.values['readingDirection'], 'rightToLeft');
      expect(device.values['loupeGesture'], 'true');
      expect(store.byProfile, isEmpty);
    });

    test(
      'a language chosen also becomes the one the gate is drawn in',
      () async {
        // There is no screen on which to set the gate's language, and there
        // should not be one: the last language anybody chose on this device is
        // the only evidence there is of what this household reads in.
        final device = MemoryKeychain();
        final store = await preferencesStore();
        final his = _container(store: store, active: _romain, keychain: device);

        await his.read(localeProvider.notifier).set(const Locale('fr'));

        expect(device.values['appLocale'], 'fr');
        expect(
          _container(store: store).read(localeProvider),
          const Locale('fr'),
        );
        expect(
          _container(store: store, active: _lea).read(localeProvider),
          const Locale('fr'),
          reason: 'she has not chosen, so the household default stands',
        );

        // And a person who has chosen is untouched by the next one to choose.
        await _container(
          store: store,
          active: _lea,
        ).read(localeProvider.notifier).set(null);
        expect(
          _container(store: store, active: _romain).read(localeProvider),
          const Locale('fr'),
        );
      },
    );
  });

  test('the image cache budget is the device’s, whoever is reading', () async {
    // Disk, and the iPad owns its disk. It is injected in `main()` alongside
    // the downloads root and the locks, so every container `SessionScope`
    // builds gets the same cap — never one budget per face.
    final store = await preferencesStore();
    ProviderContainer withLimit(Profile? active) {
      final container = ProviderContainer(
        overrides: [
          profilePreferencesStoreProvider.overrideWithValue(store),
          initialImageCacheLimitProvider.overrideWithValue(ImageCacheLimit.gb1),
          initialAuthStateProvider.overrideWithValue(
            AuthState(profiles: [_romain, _lea], activeId: active?.id),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    for (final active in [null, _romain, _lea]) {
      expect(
        withLimit(active).read(imageCacheLimitProvider),
        ImageCacheLimit.gb1,
      );
    }
  });
}

/// A store that says how often it was asked, which is the only way to see a
/// rebuild that changes no value.
class _CountingStore extends ProfilePreferencesStore {
  _CountingStore() : super(vault: MemoryPreferencesVault());

  int reads = 0;

  @override
  ReadingDirection directionFor(String? profileId) {
    reads++;
    return super.directionFor(profileId);
  }
}

/// A sign-in that answers as [profile], so entering it needs no network.
SignIn _signInAs(Profile profile) =>
    ({
      required String baseUrl,
      required String username,
      required Credential credential,
      ClientIdentity identity = const ClientIdentity.unknown(),
    }) async => LoginResult(
      username: profile.username,
      token: profile.token,
      apiKey: profile.apiKey,
    );
