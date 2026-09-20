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
      // The seam, filled in here the way #57 fills it in the app: one
      // provider, and nothing else about the chain moves. Keyed by series,
      // because that is what the rung remembers — it is asked with the
      // library beside it (#120) only so that it can read the shelf's type
      // off the catalogue, which is not what any test here is about.
      detectedDirectionProvider.overrideWith(
        (ref, key) => detected[key.seriesId],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the chain', () {
    test('asks each rung only when the one above it has no answer', () async {
      // Series, library, detected, built-in: the whole chain in one test, with
      // every rung but the last holding an answer.
      final store = await preferencesStore();
      final his = _container(
        store: store,
        active: _romain,
        detected: {
          3: ReadingDirection.verticalScroll,
          9: ReadingDirection.verticalScroll,
        },
      );
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.rightToLeft,
      );
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.leftToRight,
      );

      final series = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(series.direction, ReadingDirection.leftToRight);
      expect(series.source, ReadingDirectionSource.series);
      // Where the series lands if its own is dropped: the rung below.
      expect(series.withoutSeries, ReadingDirection.rightToLeft);

      // Another work on the same shelf, with nothing of its own.
      final onShelf = his.read(
        chapterDirectionProvider((seriesId: 9, libraryId: 1)),
      );
      expect(onShelf.direction, ReadingDirection.rightToLeft);
      expect(onShelf.source, ReadingDirectionSource.library);
      expect(onShelf.hasSeriesDirection, isFalse);

      // Another shelf, which nobody has set: the guess answers.
      final guessed = his.read(
        chapterDirectionProvider((seriesId: 9, libraryId: 2)),
        // Detected for series 9 as well, so the rung under the library's has
        // something to say for once.
      );
      expect(guessed.direction, ReadingDirection.verticalScroll);

      // And where nothing was chosen and nothing was measured, the built-in.
      final plain = his.read(
        chapterDirectionProvider((seriesId: 4, libraryId: 2)),
      );
      expect(plain.direction, ReadingDirection.leftToRight);
      expect(plain.source, ReadingDirectionSource.builtIn);
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
        _container(
          store: store,
          active: _lea,
        ).read(chapterDirectionProvider((seriesId: 3, libraryId: 1))).direction,
        ReadingDirection.leftToRight,
      );
    });

    test('a series can go back to following what stands below it', () async {
      // Set to the value below it already holds is not the same as unset: a
      // series that is set stops following a library or a guess that later
      // changes, so the sheet owes a way back — and it lands where the row
      // said it would.
      final store = await preferencesStore();
      final his = _container(store: store, active: _romain);
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.rightToLeft,
      );
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.verticalScroll);
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .withoutSeries,
        ReadingDirection.rightToLeft,
      );

      await his.read(seriesDirectionsProvider.notifier).clear(3);
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.rightToLeft,
      );
      expect(store.seriesDirectionFor(_romain.id, 3), isNull);
    });

    test('a choice is never outranked by a detection', () async {
      // A guess must never beat a choice — and what counts as a choice is a
      // series or a library that was set, not the left-to-right the chain
      // ends in.
      final store = await preferencesStore();
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.leftToRight,
      );
      await store.setSeriesDirection(
        _romain.id,
        3,
        ReadingDirection.verticalScroll,
      );

      final his = _container(
        store: store,
        active: _romain,
        detected: {3: ReadingDirection.rightToLeft},
      );
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.verticalScroll,
      );
      expect(
        his.read(chapterDirectionProvider((seriesId: 3, libraryId: 1))).source,
        ReadingDirectionSource.series,
      );

      // Somebody who has set nothing of their own is guessed for, which is
      // the whole point of the rung: it is a guess and it says so.
      final hers = _container(
        store: store,
        active: _lea,
        detected: {3: ReadingDirection.rightToLeft},
      );
      expect(
        hers
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.rightToLeft,
      );
      expect(
        hers.read(chapterDirectionProvider((seriesId: 3, libraryId: 1))).source,
        ReadingDirectionSource.detected,
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

      final detected = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(detected.direction, ReadingDirection.rightToLeft);
      expect(detected.source, ReadingDirectionSource.detected);
      // Promotable, because a library holding nothing counts as differing
      // from everything: a guess is not a choice, but it can be made into one.
      expect(detected.canPromoteToLibrary, isTrue);

      // And a series nobody has set is the only thing that outranks it.
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.verticalScroll);
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.verticalScroll,
      );
    });

    test(
      'nothing chosen and nothing detected ends where it always did',
      () async {
        final store = await preferencesStore();
        final his = _container(store: store, active: _romain);

        final plain = his.read(
          chapterDirectionProvider((seriesId: 3, libraryId: 1)),
        );
        expect(plain.direction, ReadingDirection.leftToRight);
        expect(plain.source, ReadingDirectionSource.builtIn);
        expect(plain.series, isNull);
        expect(plain.library, isNull);
      },
    );
  });

  group('the library\u2019s rung', () {
    // #65: a direction for a whole library, on the work's side of the chain —
    // under one series' own choice, above the guess. It is the rung that
    // corrects a library the detection is wrong about wholesale, and it is
    // what replaced the profile's own (#58).

    test('is asked under the series and above a detection', () async {
      final store = await preferencesStore();
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.rightToLeft,
      );

      final his = _container(
        store: store,
        active: _romain,
        detected: {3: ReadingDirection.verticalScroll},
      );
      final shelf = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(shelf.direction, ReadingDirection.rightToLeft);
      expect(shelf.source, ReadingDirectionSource.library);
      expect(
        shelf.withoutLibrary,
        ReadingDirection.verticalScroll,
        reason: 'the guess stands below it, and it is not this',
      );

      // One series of the shelf saying otherwise for itself still wins.
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.leftToRight);
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.leftToRight,
      );

      // And a series on another shelf is untouched by either.
      final elsewhere = his.read(
        chapterDirectionProvider((seriesId: 9, libraryId: 2)),
      );
      expect(elsewhere.direction, ReadingDirection.leftToRight);
      expect(elsewhere.source, ReadingDirectionSource.builtIn);
    });

    test(
      'every series in the library follows it, and nothing outside does',
      () async {
        // Set once for a shelf: the whole point of the rung is that a library
        // whose type is wrong is wrong for all of them at once.
        final store = await preferencesStore();
        final his = _container(store: store, active: _romain);
        await his
            .read(libraryDirectionsProvider.notifier)
            .set(1, ReadingDirection.rightToLeft);

        for (final seriesId in [3, 4, 5]) {
          expect(
            his
                .read(
                  chapterDirectionProvider((seriesId: seriesId, libraryId: 1)),
                )
                .direction,
            ReadingDirection.rightToLeft,
          );
        }
        expect(
          his
              .read(chapterDirectionProvider((seriesId: 3, libraryId: 2)))
              .direction,
          ReadingDirection.leftToRight,
        );
      },
    );

    test('outranks a detection, and is outranked by a series', () async {
      // A guess must never beat a choice, and a library's direction is one.
      final store = await preferencesStore();
      final his = _container(
        store: store,
        active: _romain,
        detected: {3: ReadingDirection.verticalScroll},
      );
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.verticalScroll,
      );

      await his
          .read(libraryDirectionsProvider.notifier)
          .set(1, ReadingDirection.rightToLeft);
      final chosen = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(chosen.direction, ReadingDirection.rightToLeft);
      expect(chosen.source, ReadingDirectionSource.library);

      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.verticalScroll);
      expect(
        his.read(chapterDirectionProvider((seriesId: 3, libraryId: 1))).source,
        ReadingDirectionSource.series,
      );
    });

    test('belongs to the profile that set it', () async {
      // A choice about a shelf, made by somebody: it goes where they go and
      // stays behind when they do.
      final store = await preferencesStore();
      final his = _container(store: store, active: _romain);
      await his
          .read(libraryDirectionsProvider.notifier)
          .set(1, ReadingDirection.rightToLeft);

      expect(
        store.libraryDirectionFor(_romain.id, 1),
        ReadingDirection.rightToLeft,
      );
      expect(store.libraryDirectionFor(_lea.id, 1), isNull);
      expect(
        _container(
          store: store,
          active: _lea,
        ).read(chapterDirectionProvider((seriesId: 3, libraryId: 1))).direction,
        ReadingDirection.leftToRight,
      );

      await store.forget(_romain.id);
      expect(store.libraryDirectionFor(_romain.id, 1), isNull);
    });

    test('can be dropped again, and the row says where it lands', () async {
      // Set is not the same as unset: a library that is set stops following
      // a guess that later changes, so the sheet owes a way back — and it is
      // worded with the direction the chapter really opens in.
      final store = await preferencesStore();
      final his = _container(
        store: store,
        active: _romain,
        detected: {3: ReadingDirection.rightToLeft},
      );
      await his
          .read(libraryDirectionsProvider.notifier)
          .set(1, ReadingDirection.verticalScroll);

      final shelf = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(shelf.hasLibraryDirection, isTrue);
      expect(shelf.withoutLibrary, ReadingDirection.rightToLeft);

      await his.read(libraryDirectionsProvider.notifier).clear(1);
      final dropped = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(dropped.direction, ReadingDirection.rightToLeft);
      expect(dropped.source, ReadingDirectionSource.detected);
      expect(store.libraryDirectionFor(_romain.id, 1), isNull);
    });

    test('a series keeping its own is where the library lands', () async {
      // Dropping the library's own does not move a series that has one: the
      // row is worded with what a chapter really opens in, not merely with
      // what the shelf falls back to.
      final store = await preferencesStore();
      final his = _container(store: store, active: _romain);
      await his
          .read(libraryDirectionsProvider.notifier)
          .set(1, ReadingDirection.rightToLeft);
      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.verticalScroll);

      final shelf = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(shelf.direction, ReadingDirection.verticalScroll);
      expect(shelf.withoutLibrary, ReadingDirection.verticalScroll);
      // Another series of the same shelf does follow it down.
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 4, libraryId: 1)))
            .withoutLibrary,
        ReadingDirection.leftToRight,
      );
    });
  });

  group('what the reader is handed', () {
    test('is the whole answer, resolved for one series at a time', () async {
      // One value, so the sheet cannot check a row from one rung and word an
      // action from another.
      final store = await preferencesStore();
      await store.setLibraryDirection(
        _romain.id,
        1,
        ReadingDirection.verticalScroll,
      );
      final his = _container(store: store, active: _romain);

      final before = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(before.direction, ReadingDirection.verticalScroll);
      expect(
        before.canPromoteToLibrary,
        isFalse,
        reason: 'it already is this library\u2019s',
      );
      expect(before.hasSeriesDirection, isFalse);

      await his
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.rightToLeft);
      final after = his.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(after.direction, ReadingDirection.rightToLeft);
      expect(after.source, ReadingDirectionSource.series);
      expect(after.hasSeriesDirection, isTrue);
      expect(
        after.canPromoteToLibrary,
        isTrue,
        reason: 'this library\u2019s own is still vertical',
      );
      // His other series is untouched, which is the whole point of the rung.
      expect(
        his
            .read(chapterDirectionProvider((seriesId: 9, libraryId: 1)))
            .direction,
        ReadingDirection.verticalScroll,
      );
    });

    test('is answered again when the person reading changes', () async {
      // A handover builds the app on a container of its own, but the same
      // store is the device's — so what follows the person has to be read
      // from it again rather than held.
      final store = await preferencesStore();
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
        container
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.rightToLeft,
      );

      await container.read(authProvider.notifier).resume(_lea);
      expect(
        container
            .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
            .direction,
        ReadingDirection.verticalScroll,
      );
    });

    test(
      'survives the app being closed, which is the store’s own promise',
      () async {
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
          next
              .read(chapterDirectionProvider((seriesId: 3, libraryId: 1)))
              .direction,
          ReadingDirection.rightToLeft,
        );
      },
    );
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
