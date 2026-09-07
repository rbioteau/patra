import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/lock/profile_lock.dart';

import 'test_support.dart';

Profile _profile({
  int accountId = 1,
  bool isAdmin = false,
  bool ageRestricted = false,
}) => Profile(
  baseUrl: 'https://kavita.example',
  accountId: accountId,
  username: 'romain',
  apiKey: 'key',
  isAdmin: isAdmin,
  ageRestricted: ageRestricted,
);

void main() {
  const romain = 'https://kavita.example#1';
  const lea = 'https://kavita.example#2';

  group('a lock', () {
    test('opens for its own PIN and for nothing else', () {
      final lock = ProfileLock.forPin('1234');

      expect(lock.accepts('1234'), isTrue);
      expect(lock.accepts('4321'), isFalse);
      expect(lock.accepts(''), isFalse);
    });

    test('does not hold the PIN anywhere in what it stores', () {
      final lock = ProfileLock.forPin('1234');

      expect(jsonEncode(lock.toJson()), isNot(contains('1234')));
    });

    test('salts, so two people who pick the same PIN store different rows', () {
      expect(
        ProfileLock.forPin('1234').hash,
        isNot(ProfileLock.forPin('1234').hash),
      );
    });

    test('is four digits, and refuses to be anything else', () {
      expect(ProfileLock.isValidPin('1234'), isTrue);
      expect(ProfileLock.isValidPin('123'), isFalse);
      expect(ProfileLock.isValidPin('12345'), isFalse);
      expect(ProfileLock.isValidPin('12a4'), isFalse);
      expect(ProfileLock.isValidPin(''), isFalse);
    });
  });

  group('the store', () {
    test('remembers a lock through the vault it was given', () async {
      final vault = MemoryLockVault();
      await ProfileLockStore(vault: vault).set(romain, '1234');

      // A second store on the same vault is what the next launch is.
      final reopened = ProfileLockStore(vault: vault);
      await reopened.load();

      expect(reopened.lockedIds, contains(romain));
      expect(reopened.unlocks(romain, '1234'), isTrue);
      expect(reopened.unlocks(romain, '9999'), isFalse);
    });

    test('locks one profile without locking the others', () async {
      final store = ProfileLockStore(vault: MemoryLockVault());
      await store.set(romain, '1234');

      expect(store.lockedIds, isNot(contains(lea)));
      expect(store.lockedIds, {romain});
      // A profile with no lock is open, which is the only question the
      // picker has to ask before entering one.
      expect(store.unlocks(lea, ''), isTrue);
    });

    test('changing the PIN replaces the lock rather than adding one', () async {
      final store = ProfileLockStore(vault: MemoryLockVault());
      await store.set(romain, '1234');
      await store.set(romain, '5678');

      expect(store.unlocks(romain, '1234'), isFalse);
      expect(store.unlocks(romain, '5678'), isTrue);
      expect(store.locks, hasLength(1));
    });

    test('clearing the last lock empties the vault rather than storing {}', () async {
      final vault = MemoryLockVault();
      final store = ProfileLockStore(vault: vault);
      await store.set(romain, '1234');
      await store.clear(romain);

      expect(store.lockedIds, isNot(contains(romain)));
      expect(vault.value, isNull);
      expect(vault.clears, 1);
    });

    test('refuses a PIN nothing could type back, and says so', () async {
      final vault = MemoryLockVault();
      final store = ProfileLockStore(vault: vault);

      // Out loud rather than silently: a caller that could not tell a lock
      // set from a lock declined would close its sheet on a profile it had
      // left open.
      expect(await store.set(romain, '12'), isFalse);
      expect(store.lockedIds, isNot(contains(romain)));
      expect(vault.writes, 0);
      expect(await store.set(romain, '1234'), isTrue);
    });

    test('a vault holding nonsense is a device with no locks', () async {
      final store = ProfileLockStore(vault: MemoryLockVault('not json at all'));

      expect(await store.load(), isEmpty);
    });

    test('a row of the wrong shape costs its own lock and no other', () async {
      final store = ProfileLockStore(
        vault: MemoryLockVault(
          jsonEncode({
            romain: {'salt': 'a', 'hash': 'b'},
            lea: {'salt': 7},
          }),
        ),
      );

      expect((await store.load()).keys, [romain]);
    });
  });

  group('who the app offers a lock to', () {
    // The asymmetry is the point rather than an oversight (ADR-0003): a
    // restricted account is already held back by the server, and that
    // protection does nothing once its owner is reading inside somebody
    // else's session. What is worth a PIN is the session that opens
    // everything.
    test('a profile the server puts no restriction on', () {
      expect(suggestsLock(_profile()), isTrue);
    });

    test('an administrator', () {
      expect(suggestsLock(_profile(isAdmin: true, ageRestricted: true)), isTrue);
    });

    test('never a restricted profile', () {
      expect(suggestsLock(_profile(ageRestricted: true)), isFalse);
    });
  });

  group('what a sign-in says about a restriction', () {
    LoginResult parse(Object? restriction) => LoginResult.fromJson({
      'username': 'romain',
      'token': 't',
      'apiKey': 'k',
      'ageRestriction': ?restriction,
    });

    test('Kavita\'s NotApplicable is no restriction at all', () {
      // -1 is the one value its own filters read as "return the query
      // untouched"; every other member of the enum is a ceiling.
      expect(
        parse({'ageRating': -1, 'includeUnknowns': false}).ageRestricted,
        isFalse,
      );
    });

    test('any rating is one', () {
      expect(
        parse({'ageRating': 8, 'includeUnknowns': false}).ageRestricted,
        isTrue,
      );
    });

    test('a response that says nothing reads as unrestricted', () {
      // The safe direction: it costs a suggestion nobody has to take, where
      // the other way round is a suggestion withheld from the profile that
      // most needs one.
      expect(parse(null).ageRestricted, isFalse);
    });
  });

  group('opening the app', () {
    Profile locked({String username = 'romain'}) => Profile(
      baseUrl: 'https://kavita.example',
      accountId: 1,
      username: username,
      apiKey: 'key',
    );

    test('a lone profile is opened into, as it always was', () {
      final state = AuthState(profiles: [locked()]).atLaunch();

      expect(state.active?.id, romain);
    });

    test('a lone *locked* profile is not', () {
      // Otherwise the lock could never be asked for on such a device: the
      // picker is the only thing that asks, and a device holding one profile
      // never sees one.
      final state = AuthState(profiles: [locked()]).atLaunch(locked: {romain});

      expect(state.active, isNull);
      expect(state.profiles, hasLength(1));
    });
  });
}
