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
    test(
      "a profile that never chose starts from the device's default",
      () async {
        // Which is what makes this an upgrade nobody notices: a device set
        // before it held profiles keeps its settings, for everybody on it.
        final store = await preferencesStore(
          deviceMagnify: true,
          deviceWidthFactor: 0.6,
          deviceBookTextSize: 20,
          deviceBookLineHeight: 1.9,
          deviceLanguage: const Locale('fr'),
        );

        expect(store.magnifyFor(_lea.id), isTrue);
        expect(store.widthFactorFor(_lea.id), 0.6);
        expect(
          store.bookTextSizeFor(_lea.id),
          20,
          reason: 'a book is set at the size the device says, for everybody',
        );
        expect(store.bookLineHeightFor(_lea.id), 1.9);
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
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      await store.setMagnify(_romain.id, true);
      await store.setWidthFactor(_romain.id, 0.6);
      // How a book is set, which is one number for every book: a choice
      // about a person's eyes, not about one work.
      await store.setBookLineHeight(_romain.id, 1.9);
      await store.setBookTextSize(_romain.id, 20);
      await store.setBookReadingFace(_romain.id, ReadingFace.serif);
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.rightToLeft,
      );
      await store.setLanguage(_lea.id, const Locale('fr'));

      final reopened = await preferencesStore(
        keychain: MemoryKeychain({...keychain.values}),
      );
      expect(reopened.of(_romain.id).magnify, isTrue);
      expect(reopened.widthFactorFor(_romain.id), 0.6);
      expect(reopened.bookTextSizeFor(_romain.id), 20);
      expect(reopened.bookLineHeightFor(_romain.id), 1.9);
      expect(reopened.bookReadingFaceFor(_romain.id), ReadingFace.serif);
      expect(
        reopened.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.rightToLeft,
      );
      expect(reopened.languageFor(_lea.id), const Locale('fr'));
      expect(reopened.seriesDirectionFor(_lea.id, 3), isNull);
    });

    test(
      'a row of the wrong shape costs a preference, never the app',
      () async {
        // Loaded before `runApp`, so the safe direction is the least there is
        // to lose: one preference falls back to the device's default and the
        // rest of the row still stands.
        final store = await preferencesStore(
          keychain: MemoryKeychain({
            'profilePreferences':
                '{"${_romain.id}": {"magnify": "yes", "magnified": true,'
                ' "widthFactor": 0.6, "bookTextSize": 40,'
                ' "bookLineHeight": 9}}',
          }),
          deviceMagnify: true,
        );
        expect(store.of(_romain.id).magnify, isNull);
        expect(
          store.widthFactorFor(_romain.id),
          0.6,
          reason: 'one field of the wrong shape costs that field alone',
        );
        // A size no slider on this build can reach is answered with the
        // nearest one that can: a page drawn at 40pt while the sheet swears
        // it is set at 22 is the sheet lying about what is on the screen.
        expect(store.bookTextSizeFor(_romain.id), maxBookTextSize);
        expect(store.bookLineHeightFor(_romain.id), maxBookLineHeight);

        final broken = await preferencesStore(
          keychain: MemoryKeychain({'profilePreferences': 'not json at all'}),
        );
        expect(broken.byProfile, isEmpty);
      },
    );

    test('a direction stored by an older build is read no more', () async {
      // #58 took the profile's and the device's rungs out of the chain; the
      // row a device already holds is left where it is rather than deleted,
      // and parsing it has to keep working — it is simply not asked.
      final store = await preferencesStore(
        keychain: MemoryKeychain({
          'profilePreferences':
              '{"${_romain.id}": {"direction": "rightToLeft", "magnify": true,'
              ' "seriesDirections": {"3": "rightToLeft"}}}',
        }),
      );

      expect(store.of(_romain.id).magnify, isTrue);
      expect(
        store.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.rightToLeft,
        reason: 'what the row still says is read, as it always was',
      );
    });

    test('a language this build dropped reads as no choice at all', () async {
      // Rather than as a language with no translations behind it, which is
      // the same answer the device's own setting gets.
      final store = await preferencesStore(
        keychain: MemoryKeychain({
          'profilePreferences': '{"${_romain.id}": {"language": "xh"}}',
        }),
        deviceLanguage: const Locale('fr'),
      );
      expect(store.languageFor(_romain.id), const Locale('fr'));
    });
    test('an old reading face name reads as the closest current choice', () async {
      // The preference used to be a family name. A device holding one of those
      // strings must not silently reset the setting — it reads back as the
      // choice that stands closest to it. An unknown name reads as never having
      // chosen, so the default (the book's own) takes over.
      final legacyNames = {
        'literata': ReadingFace.serif,
        'sourceSerif4': ReadingFace.serif,
        'spaceGrotesk': ReadingFace.sans,
        'atkinsonHyperlegibleNext': ReadingFace.sans,
      };
      for (final entry in legacyNames.entries) {
        final store = await preferencesStore(
          keychain: MemoryKeychain({
            'profilePreferences':
                '{"${_romain.id}": {"bookReadingFace": "${entry.key}"}}',
          }),
        );
        expect(
          store.bookReadingFaceFor(_romain.id),
          entry.value,
          reason: '${entry.key} maps to ${entry.value.name}',
        );
      }

      // An unknown name costs the profile its face, not the app its page.
      final unknownStore = await preferencesStore(
        keychain: MemoryKeychain({
          'profilePreferences':
              '{"${_romain.id}": {"bookReadingFace": "comicSansMS"}}',
        }),
      );
      expect(
        unknownStore.bookReadingFaceFor(_romain.id),
        defaultBookReadingFace,
        reason: 'an unknown name reads as never having chosen',
      );
    });
    test('changing one preference keeps the others', () async {
      // `setLanguage` cannot go through `copyWith` — null is a choice — so it
      // builds the record by hand, and a field it forgets to carry is a
      // preference that quietly resets itself on the next launch. The two
      // direction maps are the fields most easily forgotten, being the
      // newest: a series and a library set for a person are theirs however
      // many times they change their language since.
      final store = await preferencesStore();
      await store.setMagnify(_romain.id, true);
      await store.setWidthFactor(_romain.id, 0.6);
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.verticalScroll,
      );
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.verticalScroll,
      );
      await store.setLanguage(_romain.id, const Locale('fr'));

      expect(store.of(_romain.id).magnify, isTrue);
      expect(store.widthFactorFor(_romain.id), 0.6);
      expect(store.languageFor(_romain.id), const Locale('fr'));
      expect(
        store.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.verticalScroll,
      );
      expect(
        store.libraryDirectionFor(_romain.id, 1),
        ReadingDirection.verticalScroll,
      );
    });

    test('forgetting a profile takes its preferences with it', () async {
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.verticalScroll,
      );
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.verticalScroll,
      );
      await store.setSeriesDirection(
        _lea.id,
        3,
        ReadingDirection.verticalScroll,
      );

      await store.forget(_romain.id);
      expect(store.seriesDirectionFor(_romain.id, 3), isNull);
      expect(store.libraryDirectionFor(_romain.id, 1), isNull);
      expect(
        store.seriesDirectionFor(_lea.id, 3),
        ReadingDirection.verticalScroll,
      );
      expect(
        keychain.values['profilePreferences'],
        isNot(contains(_romain.id)),
      );
    });

    test('a series direction belongs to the profile that chose it', () async {
      // It is a choice about a work rather than about a person, but it is
      // still a person who made it — and two people sharing a tablet do not
      // read the same series the same way round (ADR-0007).
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.rightToLeft,
      );
      await store.setSeriesDirection(
        _lea.id,
        3,
        ReadingDirection.verticalScroll,
      );

      expect(
        store.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.rightToLeft,
      );
      expect(
        store.seriesDirectionFor(_lea.id, 3),
        ReadingDirection.verticalScroll,
      );
      expect(
        store.seriesDirectionFor(_romain.id, 9),
        isNull,
        reason: 'a series nobody set was never given one',
      );

      final reopened = await preferencesStore(
        keychain: MemoryKeychain({...keychain.values}),
      );
      expect(
        reopened.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.rightToLeft,
      );
      expect(
        reopened.seriesDirectionFor(_lea.id, 3),
        ReadingDirection.verticalScroll,
      );
      expect(reopened.seriesDirectionFor(_romain.id, 9), isNull);
    });

    test('a series can go back to following the default', () async {
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.rightToLeft,
      );
      await store.setSeriesDirection(
        _romain.id,
        9,
        ReadingDirection.verticalScroll,
      );

      await store.clearSeriesDirection(_romain.id, 3);
      expect(store.seriesDirectionFor(_romain.id, 3), isNull);
      expect(
        store.seriesDirectionFor(_romain.id, 9),
        ReadingDirection.verticalScroll,
        reason: 'one series going back to the default moves no other',
      );

      final reopened = await preferencesStore(
        keychain: MemoryKeychain({...keychain.values}),
      );
      expect(reopened.seriesDirectionFor(_romain.id, 3), isNull);
      expect(
        reopened.seriesDirectionFor(_romain.id, 9),
        ReadingDirection.verticalScroll,
      );
    });

    test('a library direction belongs to the profile that chose it', () async {
      // The same shape as the series map it mirrors, and the same promise: a
      // choice about a shelf, kept with the person who made it and gone when
      // they are (#65).
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.rightToLeft,
      );
      await store.setLibraryDirection(
        _lea.id,
        1,
        ReadingDirection.verticalScroll,
      );

      expect(
        store.libraryDirectionFor(_romain.id, 1),
        ReadingDirection.rightToLeft,
      );
      expect(
        store.libraryDirectionFor(_lea.id, 1),
        ReadingDirection.verticalScroll,
      );
      expect(
        store.libraryDirectionFor(_romain.id, 2),
        isNull,
        reason: 'a library nobody set was never given one',
      );

      final reopened = await preferencesStore(
        keychain: MemoryKeychain({...keychain.values}),
      );
      expect(
        reopened.libraryDirectionFor(_romain.id, 1),
        ReadingDirection.rightToLeft,
      );
      expect(
        reopened.libraryDirectionFor(_lea.id, 1),
        ReadingDirection.verticalScroll,
      );

      await store.forget(_romain.id);
      expect(store.libraryDirectionFor(_romain.id, 1), isNull);
      expect(
        store.libraryDirectionFor(_lea.id, 1),
        ReadingDirection.verticalScroll,
      );
    });

    test('a library can go back to following what stands below it', () async {
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.rightToLeft,
      );
      await store.setLibraryDirection(
        _romain.id,
        2,
        ReadingDirection.verticalScroll,
      );

      await store.clearLibraryDirection(_romain.id, 1);
      expect(store.libraryDirectionFor(_romain.id, 1), isNull);
      expect(
        store.libraryDirectionFor(_romain.id, 2),
        ReadingDirection.verticalScroll,
        reason: 'one shelf going back moves no other',
      );

      final reopened = await preferencesStore(
        keychain: MemoryKeychain({...keychain.values}),
      );
      expect(reopened.libraryDirectionFor(_romain.id, 1), isNull);
      expect(
        reopened.libraryDirectionFor(_romain.id, 2),
        ReadingDirection.verticalScroll,
      );
    });

    test('a series map of the wrong shape costs a series, not the row', () async {
      // Read before `runApp`, so the safe direction is the least there is to
      // lose: one series goes back to following the default, and everything
      // else this profile chose is untouched.
      final store = await preferencesStore(
        keychain: MemoryKeychain({
          'profilePreferences':
              '{"${_romain.id}": {"magnify": true,'
              ' "seriesDirections": {"3": 7, "4": "webtoon",'
              ' "five": "rightToLeft", "6": "sideways"},'
              ' "libraryDirections": {"1": 7, "2": "webtoon",'
              ' "three": "rightToLeft"}}}',
        }),
      );

      expect(
        store.seriesDirectionFor(_romain.id, 3),
        isNull,
        reason: 'a direction that is not a name is no direction',
      );
      expect(
        store.seriesDirectionFor(_romain.id, 4),
        ReadingDirection.verticalScroll,
        reason: 'the legacy name is still read, like everywhere else',
      );
      expect(store.seriesDirectionFor(_romain.id, 5), isNull);
      expect(store.seriesDirectionFor(_romain.id, 6), isNull);
      expect(store.of(_romain.id).magnify, isTrue);
      // The library map is the same shape, read by the same parser (#65).
      expect(store.libraryDirectionFor(_romain.id, 1), isNull);
      expect(
        store.libraryDirectionFor(_romain.id, 2),
        ReadingDirection.verticalScroll,
      );
      expect(store.libraryDirectionFor(_romain.id, 3), isNull);

      final nonsense = await preferencesStore(
        keychain: MemoryKeychain({
          'profilePreferences':
              '{"${_romain.id}": {"magnify": true,'
              ' "seriesDirections": "nonsense"}}',
        }),
      );
      expect(nonsense.seriesDirectionFor(_romain.id, 3), isNull);
      expect(nonsense.of(_romain.id).magnify, isTrue);
    });

    test('the last profile forgotten leaves nothing in the keychain', () async {
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      await store.setMagnify(_romain.id, true);

      await store.forget(_romain.id);
      // An empty map is no row, not a row holding `{}`.
      expect(keychain.values.containsKey('profilePreferences'), isFalse);
    });
  });

  group('the preferences in force', () {
    test('are the reading profile’s own', () async {
      final store = await preferencesStore();
      await store.setMagnify(_romain.id, true);
      await store.setWidthFactor(_romain.id, 0.6);
      await store.setBookLineHeight(_romain.id, 1.9);
      await store.setBookTextSize(_romain.id, 20);
      await store.setBookReadingFace(_romain.id, ReadingFace.serif);
      await store.setLanguage(_romain.id, const Locale('fr'));
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.rightToLeft,
      );

      final his = _container(store: store, active: _romain);
      expect(his.read(seriesDirectionsProvider), {
        3: ReadingDirection.rightToLeft,
      });
      expect(his.read(magnifyProvider), isTrue);
      expect(his.read(widthFactorProvider), 0.6);
      expect(his.read(bookTextSizeProvider), 20);
      expect(his.read(bookLineHeightProvider), 1.9);
      expect(his.read(bookReadingFaceProvider), ReadingFace.serif);
      // The next person to be handed the tablet, on a container of their own
      // — which is what `SessionScope` builds for them.
      final hers = _container(store: store, active: _lea);
      expect(hers.read(seriesDirectionsProvider), isEmpty);
      expect(hers.read(magnifyProvider), isFalse);
      expect(
        hers.read(widthFactorProvider),
        1.0,
        reason:
            'she has not chosen, and 1.0 is how a chapter has always opened',
      );
      // How a book is set follows the person and not the device: she reads
      // on the same tablet, and a size chosen for somebody else's eyes is
      // not hers.
      expect(hers.read(bookTextSizeProvider), defaultBookTextSize);
      expect(hers.read(bookLineHeightProvider), defaultBookLineHeight);
      expect(
        hers.read(bookReadingFaceProvider),
        defaultBookReadingFace,
        reason: "a book is set in the book's own until somebody says otherwise",
      );
      expect(hers.read(localeProvider), isNull);
    });

    test('follow whoever enters a container nobody has read in', () async {
      // The one way into a session that does *not* rebuild the app: the first
      // profile entered in a container. Preferences are a function of who is
      // reading, so this needs no wiring of its own.
      final store = await preferencesStore();
      await store.setSeriesDirection(
        _lea.id,
        3,
        ReadingDirection.verticalScroll,
      );

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
        container.read(seriesDirectionsProvider),
        isEmpty,
        reason: 'nobody is reading yet, so this is the gate',
      );

      await container.read(authProvider.notifier).resume(_lea);
      expect(container.read(seriesDirectionsProvider), {
        3: ReadingDirection.verticalScroll,
      });
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
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.rightToLeft);
      await his.read(magnifyProvider.notifier).set(true);
      await his.read(widthFactorProvider.notifier).set(0.6);
      // What the sheet sets for a book, through the same seam it uses: the
      // notifier a slider's finger writes to when it lifts.
      await his.read(bookTextSizeProvider.notifier).set(20);
      await his.read(bookLineHeightProvider.notifier).set(1.9);

      expect(his.read(seriesDirectionsProvider), {
        3: ReadingDirection.rightToLeft,
      });
      expect(
        store.seriesDirectionFor(_lea.id, 3),
        isNull,
        reason: 'she never chose, so nothing of hers moved either',
      );
      expect(store.magnifyFor(_lea.id), isFalse);
      expect(store.widthFactorFor(_lea.id), 1.0);
      expect(store.bookTextSizeFor(_lea.id), defaultBookTextSize);
      expect(store.bookLineHeightFor(_lea.id), defaultBookLineHeight);
    });

    test('a face follows the person across a handover, not the device', () async {
      // A handover builds the app on a container of its own, but the store is
      // the device's — so what follows the person has to be read out of it
      // again rather than held by the container that chose it.
      final store = await preferencesStore();
      await store.setBookReadingFace(_romain.id, ReadingFace.serif);
      await store.setBookReadingFace(
        _lea.id,
        ReadingFace.sans,
      );

      final container = ProviderContainer(
        overrides: [
          testKeychain(),
          profilePreferencesStoreProvider.overrideWithValue(store),
          initialAuthStateProvider.overrideWithValue(
            AuthState(profiles: [_romain, _lea], activeId: _romain.id),
          ),
          signInProvider.overrideWithValue(_signInAs(_lea)),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(bookReadingFaceProvider),
        ReadingFace.serif,
        reason: 'the face is his, and the tablet is not what chose it',
      );

      await container.read(authProvider.notifier).resume(_lea);
      expect(
        container.read(bookReadingFaceProvider),
        ReadingFace.sans,
        reason: 'the next reader’s books are set in the face they chose',
      );
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
        seriesDirectionsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      expect(store.reads, 1);

      await his.read(authProvider.notifier).updateToken('a-fresh-jwt');
      his.read(seriesDirectionsProvider);
      expect(store.reads, 1, reason: 'the id did not move, so nothing did');
    });

    test('survive the lock in front of them being taken off', () async {
      // Removing a profile takes its preferences, its lock and its saved
      // chapters together. Clearing a *PIN* is none of those: the person is
      // still there, and what they read in is no business of the lock's.
      final locks = await lockStore();
      final store = await preferencesStore();
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.rightToLeft,
      );
      await locks.set(_romain.id, '1234');

      await locks.clear(_romain.id);
      expect(
        store.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.rightToLeft,
      );
    });

    test('with nobody reading are the device’s to keep', () async {
      // What a device holds for itself is the flat keys: magnifying, which
      // was a device setting before there were profiles. The reading
      // direction is not one of them any more and never was for everybody —
      // #58 took the rung out of the chain, so there is no key to write.
      final device = MemoryKeychain();
      final store = await preferencesStore();
      final gate = _container(store: store, keychain: device);

      await gate
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.rightToLeft);
      await gate.read(magnifyProvider.notifier).set(true);
      await gate.read(widthFactorProvider.notifier).set(0.6);

      expect(device.values['readingDirection'], isNull);
      expect(
        device.values['loupeGesture'],
        'true',
        reason: 'magnifying still falls back to the device, as it always did',
      );
      expect(store.byProfile, isEmpty);
      // Nothing of the width factor's: unlike magnifying it is not a value
      // this device ever held a key for, so with nobody reading there is
      // nowhere for it to go. No screen reaches this — Settings stands
      // inside a session, and the gate has no width to set.
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
  _CountingStore() : super(keychain: MemoryKeychain());

  int reads = 0;

  @override
  ProfilePreferences of(String? profileId) {
    reads++;
    return super.of(profileId);
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
