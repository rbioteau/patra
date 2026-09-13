import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/reader/reading_direction.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';

import 'test_support.dart';

/// Two people sharing one tablet, which is what a series direction belongs to
/// one of.
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

/// A container reading as [active], on [store], where the work itself
/// suggests [detected] — which is #57's rung, empty until it is filled.
ProviderContainer _container({
  required ProfilePreferencesStore store,
  Profile? active,
  Map<int, ReadingDirection> detected = const {},
}) {
  final container = ProviderContainer(
    overrides: [
      testKeychain(),
      profilePreferencesStoreProvider.overrideWithValue(store),
      initialAuthStateProvider.overrideWithValue(
        AuthState(profiles: [_romain, _lea], activeId: active?.id),
      ),
      // The seam, filled in here the way #57 will fill it in the app: one
      // provider, and nothing else about the chain moves.
      for (final entry in detected.entries)
        detectedDirectionProvider(entry.key).overrideWithValue(entry.value),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the chain', () {
    test('asks each rung only when the one above it has no answer', () async {
      final store = await preferencesStore(
        deviceDirection: ReadingDirection.leftToRight,
      );
      await store.setDirection(_romain.id, ReadingDirection.verticalScroll);
      await store.setSeriesDirection(_romain.id, 3, ReadingDirection.rightToLeft);

      final his = _container(store: store, active: _romain);
      final series = his.read(chapterDirectionProvider(3));
      expect(series.direction, ReadingDirection.rightToLeft);
      expect(series.source, ReadingDirectionSource.series);
      // Where the series lands if its own is dropped: the rung below.
      expect(series.withoutSeries, ReadingDirection.verticalScroll);

      final unread = his.read(chapterDirectionProvider(9));
      expect(unread.direction, ReadingDirection.verticalScroll);
      expect(unread.source, ReadingDirectionSource.profile);
      expect(unread.hasSeriesDirection, isFalse);

      // Somebody who has chosen nothing of their own is on the device's.
      final hers = _container(store: store, active: _lea);
      final onDevice = hers.read(chapterDirectionProvider(3));
      expect(onDevice.direction, ReadingDirection.leftToRight);
      expect(onDevice.source, ReadingDirectionSource.device);
      expect(
        hers.read(chapterDirectionProvider(9)).direction,
        ReadingDirection.leftToRight,
      );
    });

    test('a series direction belongs to the profile that chose it', () async {
      // The same series, the same tablet, two people: the direction is a
      // choice about a work, but it is still a person who made it.
      final store = await preferencesStore();
      final his = _container(store: store, active: _romain);
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.rightToLeft);

      expect(
        store.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.rightToLeft,
      );
      expect(store.seriesDirectionFor(_lea.id, 3), isNull);
      expect(
        _container(store: store, active: _lea)
            .read(chapterDirectionProvider(3))
            .direction,
        ReadingDirection.leftToRight,
      );
    });

    test('a series can go back to following the default', () async {
      // Set to the value the default already holds is not the same as unset:
      // a series that is set stops following a default that later changes, so
      // the sheet owes a way back — and it lands where the row said it would.
      final store = await preferencesStore(
        deviceDirection: ReadingDirection.rightToLeft,
      );
      final his = _container(store: store, active: _romain);
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.verticalScroll);
      expect(
        his.read(chapterDirectionProvider(3)).withoutSeries,
        ReadingDirection.rightToLeft,
      );

      await his.read(seriesDirectionsProvider.notifier).clear(3);
      expect(
        his.read(chapterDirectionProvider(3)).direction,
        ReadingDirection.rightToLeft,
      );
      expect(store.seriesDirectionFor(_romain.id, 3), isNull);
    });

    test('promoting to the profile leaves the series its own', () async {
      // One tap, one thing: the series keeps its direction, which now lands
      // on the same value the default does, so the way back stays free.
      final store = await preferencesStore();
      final his = _container(store: store, active: _romain);
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.rightToLeft);

      await his
          .read(profileDirectionProvider.notifier)
          .set(ReadingDirection.rightToLeft);

      expect(store.of(_romain.id).direction, ReadingDirection.rightToLeft);
      expect(
        store.seriesDirectionFor(_romain.id, 3),
        ReadingDirection.rightToLeft,
      );
      // Another series, which has no direction of its own, follows them now.
      expect(
        his.read(chapterDirectionProvider(9)).direction,
        ReadingDirection.rightToLeft,
      );
      expect(
        his.read(chapterDirectionProvider(9)).source,
        ReadingDirectionSource.profile,
      );
    });

    test('a stored default is never outranked by a detection', () async {
      // A guess must never beat a choice — and what counts as a choice is
      // what was *stored*, not the left-to-right the chain ends in.
      final store = await preferencesStore(
        deviceDirection: ReadingDirection.verticalScroll,
      );
      await store.setDirection(_romain.id, ReadingDirection.leftToRight);

      final his = _container(
        store: store,
        active: _romain,
        detected: {3: ReadingDirection.rightToLeft},
      );
      expect(his.read(chapterDirectionProvider(3)).direction, ReadingDirection.leftToRight);
      expect(
        his.read(chapterDirectionProvider(3)).source,
        ReadingDirectionSource.profile,
      );

      // Somebody who has stored nothing of their own is still outranked by
      // what this device stored, which is a choice somebody made here.
      final hers = _container(
        store: store,
        active: _lea,
        detected: {3: ReadingDirection.rightToLeft},
      );
      expect(
        hers.read(chapterDirectionProvider(3)).direction,
        ReadingDirection.verticalScroll,
      );
      expect(
        hers.read(chapterDirectionProvider(3)).source,
        ReadingDirectionSource.device,
      );
    });

    test('with nothing stored anywhere, the detected rung answers', () async {
      // The seam #57 fills: this is what a chapter will open in the day a
      // direction is detected, and no screen changes to make it so.
      final store = await preferencesStore();
      final his = _container(
        store: store,
        active: _romain,
        detected: {3: ReadingDirection.rightToLeft},
      );

      final detected = his.read(chapterDirectionProvider(3));
      expect(detected.direction, ReadingDirection.rightToLeft);
      expect(detected.source, ReadingDirectionSource.detected);
      // Promotable, because no stored default counts as differing from
      // everything: a guess is not a choice, but it can be made into one.
      expect(detected.canPromote, isTrue);

      // And a series nobody has set is the only thing that outranks it.
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.verticalScroll);
      expect(
        his.read(chapterDirectionProvider(3)).direction,
        ReadingDirection.verticalScroll,
      );
    });

    test('nothing chosen and nothing detected ends where it always did', () async {
      final store = await preferencesStore();
      final his = _container(store: store, active: _romain);

      final plain = his.read(chapterDirectionProvider(3));
      expect(plain.direction, ReadingDirection.leftToRight);
      expect(plain.source, ReadingDirectionSource.device);
      expect(plain.series, isNull);
      expect(plain.profile, isNull);
    });
  });

  group('what the reader is handed', () {
    test('is the whole answer, resolved for one series at a time', () async {
      // One value, so the sheet cannot check a row from one rung and word an
      // action from another.
      final store = await preferencesStore(
        deviceDirection: ReadingDirection.leftToRight,
      );
      await store.setDirection(_romain.id, ReadingDirection.verticalScroll);
      final his = _container(store: store, active: _romain);

      final before = his.read(chapterDirectionProvider(3));
      expect(before.direction, ReadingDirection.verticalScroll);
      expect(before.canPromote, isFalse, reason: 'it already is their default');
      expect(before.hasSeriesDirection, isFalse);

      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.rightToLeft);
      final after = his.read(chapterDirectionProvider(3));
      expect(after.direction, ReadingDirection.rightToLeft);
      expect(after.source, ReadingDirectionSource.series);
      expect(after.hasSeriesDirection, isTrue);
      expect(
        after.canPromote,
        isTrue,
        reason: 'their stored default is still vertical',
      );
      // His other series is untouched, which is the whole point of the rung.
      expect(
        his.read(chapterDirectionProvider(9)).direction,
        ReadingDirection.verticalScroll,
      );
    });

    test('is answered again when the person reading changes', () async {
      // A handover builds the app on a container of its own, but the same
      // store is the device's — so what follows the person has to be read
      // from it again rather than held.
      final store = await preferencesStore();
      await store.setSeriesDirection(_romain.id, 3, ReadingDirection.rightToLeft);
      await store.setSeriesDirection(_lea.id, 3, ReadingDirection.verticalScroll);

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
        container.read(chapterDirectionProvider(3)).direction,
        ReadingDirection.rightToLeft,
      );

      await container.read(authProvider.notifier).resume(_lea);
      expect(
        container.read(chapterDirectionProvider(3)).direction,
        ReadingDirection.verticalScroll,
      );
    });

    test('survives the app being closed, which is the store’s own promise', () async {
      // Loaded before `runApp`, written whole on every change.
      final keychain = MemoryKeychain();
      final store = await preferencesStore(keychain: keychain);
      final his = _container(store: store, active: _romain);
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.rightToLeft);

      final reopened = await preferencesStore(
        keychain: MemoryKeychain({...keychain.values}),
      );
      final next = _container(store: reopened, active: _romain);
      expect(
        next.read(chapterDirectionProvider(3)).direction,
        ReadingDirection.rightToLeft,
      );
    });
  });
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
