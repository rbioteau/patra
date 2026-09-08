/// A PIN in front of a profile, and the rules about who is offered one.
///
/// **What a lock is for, exactly.** It keeps the people who share a device
/// out of each other's profiles, and that is the whole of it. It is not
/// protection for a device that has been lost: the auth key each profile
/// keeps is a complete, non-expiring Kavita account credential sitting in the
/// keychain, only its own owner can rotate one (ADR-0004), and the pages a
/// profile has saved are ordinary files. Nothing here changes any of that, so
/// nothing here — in code or in copy — may imply otherwise.
///
/// The store takes the device's [Keychain], with the real one as its default,
/// so the rules below can be exercised without one.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../keychain.dart';

/// One profile's lock: a salt and what the PIN hashes to under it.
///
/// The PIN itself is never written down, which is worth being precise about
/// because the hash is **not** what makes the lock hard to break. Four digits
/// is ten thousand guesses, so anything that can read the keychain has the
/// PIN either way — and it could read the auth key sitting beside it, which
/// is worth incomparably more. What the hash really buys is that a PIN
/// somebody also uses on a bank card or a phone lock screen does not end up
/// legible in a file, and that is reason enough not to store it plainly.
class ProfileLock {
  const ProfileLock({required this.salt, required this.hash});

  /// Random per lock, so two people who pick the same PIN do not store the
  /// same row — the one comparison that is cheap enough to be worth denying.
  final String salt;

  /// `sha256(salt + pin)`, hex.
  final String hash;

  /// How many digits a PIN is. Fixed rather than a range: the pad draws that
  /// many dots and submits when the last one lands, so the number is part of
  /// the surface and not a validation rule tacked onto it.
  static const pinLength = 4;

  /// Digits only, and exactly [pinLength] of them.
  static bool isValidPin(String pin) =>
      pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  static final _random = Random.secure();

  /// The lock [pin] produces. [salt] is a parameter so a test can pin the
  /// hashing itself; nothing in the app passes one.
  factory ProfileLock.forPin(String pin, {String? salt}) {
    final withSalt =
        salt ??
        base64Url.encode(List.generate(12, (_) => _random.nextInt(256)));
    return ProfileLock(salt: withSalt, hash: _digest(withSalt, pin));
  }

  static String _digest(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt$pin')).toString();

  /// Whether [pin] is the one this lock was made from.
  bool accepts(String pin) => _digest(salt, pin) == hash;

  Map<String, dynamic> toJson() => {'salt': salt, 'hash': hash};

  /// Defensive like every other read from the keychain: this is loaded from
  /// `main()` before `runApp`, so a row of the wrong shape must cost its
  /// profile its lock and never cost the device its app. Losing a lock is
  /// the safe direction — the profile is then merely unlocked, and Settings
  /// can give it one again.
  static ProfileLock? fromJson(Object? json) {
    if (json is! Map) return null;
    final salt = json['salt'];
    final hash = json['hash'];
    if (salt is! String || hash is! String) return null;
    if (salt.isEmpty || hash.isEmpty) return null;
    return ProfileLock(salt: salt, hash: hash);
  }
}

/// Where the locks are kept — the module's platform dependency, injected.
///
/// One value rather than a key per profile, because the whole map is read at
/// once before the app starts and written whole on every change: a lock is a
/// fact about the device, not about a session, and there is never a reason to
/// read one profile's without the others'.
/// Every lock this device holds, keyed by [Profile.id].
///
/// Loaded once, before `runApp` — the app has to know which profiles are
/// locked before it decides where to open ([AuthState.atLaunch]) — and kept
/// in memory afterwards, so this instance is the one the app reads. It is
/// injected the way the image cache store is, and for the same reason: it
/// belongs to the **device**, so it has to survive a handover building the
/// app again on a container of its own.
class ProfileLockStore {
  ProfileLockStore({Keychain? keychain})
    : _keychain = keychain ?? const SecureKeychain();

  final Keychain _keychain;

  /// One row rather than a key per profile, because the whole map is read at
  /// once before the app starts and written whole on every change: a lock is
  /// a fact about the device, not about a session, and there is never a
  /// reason to read one profile's without the others'.
  static const _key = 'profileLocks';

  Map<String, ProfileLock> _locks = const {};

  /// What is locked right now. Empty until [load], which is what a test that
  /// never calls it gets.
  Map<String, ProfileLock> get locks => Map.unmodifiable(_locks);

  Set<String> get lockedIds => _locks.keys.toSet();

  Future<Map<String, ProfileLock>> load() async {
    final String? raw;
    try {
      raw = await _keychain.read(_key);
    } on Exception {
      // A keychain that cannot be read is a device with no locks, not a
      // device that cannot start — same rule as `SessionStorage.load`.
      return locks;
    }
    if (raw == null) return locks;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return locks;
      _locks = {
        for (final entry in decoded.entries)
          '${entry.key}': ?ProfileLock.fromJson(entry.value),
      };
    } on FormatException {
      // Unreadable is unlocked, as above.
    }
    return locks;
  }

  /// Gives [profileId] a lock, or replaces the one it has, and answers
  /// whether it took.
  ///
  /// Anything that is not a PIN is refused rather than stored as a lock
  /// nothing could ever open — and refused **out loud**, because a caller
  /// that could not tell a lock set from a lock declined would close its
  /// sheet on a profile it had left open.
  Future<bool> set(String profileId, String pin) async {
    if (!ProfileLock.isValidPin(pin)) return false;
    _locks = {..._locks, profileId: ProfileLock.forPin(pin)};
    await _flush();
    return true;
  }

  /// Takes the lock off [profileId]. Also what removing a profile has to do:
  /// a lock outliving the profile it stood in front of would lock the same
  /// person out on the day they sign back in, with a PIN nothing remembers
  /// asking for.
  Future<void> clear(String profileId) async {
    if (!_locks.containsKey(profileId)) return;
    _locks = {
      for (final entry in _locks.entries)
        if (entry.key != profileId) entry.key: entry.value,
    };
    await _flush();
  }

  /// Whether [pin] opens [profileId]. A profile with no lock is open, which
  /// is what makes this the only question the picker has to ask.
  bool unlocks(String profileId, String pin) =>
      _locks[profileId]?.accepts(pin) ?? true;

  /// An empty map is **no row**, not a row holding `{}`.
  ///
  /// Failures are swallowed here rather than in the keychain, which is where
  /// that decision belongs: the lock is still in memory for this run and the
  /// next change tries again, so there is nothing to surface.
  Future<void> _flush() async {
    try {
      if (_locks.isEmpty) {
        await _keychain.delete(_key);
        return;
      }
      await _keychain.write(
        _key,
        jsonEncode({
          for (final entry in _locks.entries) entry.key: entry.value.toJson(),
        }),
      );
    } on Exception {
      // As above.
    }
  }
}

/// Whether the app offers [profile] a lock.
///
/// **A profile the server restricts nothing about — and never a restricted
/// one**, which is the opposite of where one would first think to put it and
/// is the point rather than an oversight (ADR-0003). Kavita's age restriction
/// protects the *account* it is set on and does exactly nothing once a child
/// is reading inside an adult's session, so on a family device the thing
/// worth a PIN is the session that can open everything; a lock on the
/// nine-year-old's profile would protect nothing the server is not already
/// protecting.
///
/// **An administrator counts as unrestricted even when a rating is set on
/// it**, and that is not a loophole in the rule but the same rule applied
/// honestly: a Kavita admin can edit any account's restriction, their own
/// included, so a restriction on an admin is a preference rather than a
/// limit. Reading it as protection would be reading a fence somebody can
/// open from the inside.
///
/// It is a suggestion and not a rule: Settings lets any profile be locked,
/// because whose profile it is remains theirs to decide.
bool suggestsLock(Profile profile) => profile.isAdmin || !profile.ageRestricted;

/// The store, built before `runApp` and injected there. The default is an
/// unloaded one, which is a device with no locks — what a test gets.
final profileLockStoreProvider = Provider<ProfileLockStore>(
  (ref) => ProfileLockStore(),
);

/// Which profiles are locked, as a screen watches it.
class ProfileLocksNotifier extends Notifier<Map<String, ProfileLock>> {
  @override
  Map<String, ProfileLock> build() => ref.read(profileLockStoreProvider).locks;

  ProfileLockStore get _store => ref.read(profileLockStoreProvider);

  Future<bool> set(String profileId, String pin) async {
    final took = await _store.set(profileId, pin);
    state = _store.locks;
    return took;
  }

  Future<void> clear(String profileId) async {
    await _store.clear(profileId);
    state = _store.locks;
  }

  bool unlocks(String profileId, String pin) => _store.unlocks(profileId, pin);
}

final profileLocksProvider =
    NotifierProvider<ProfileLocksNotifier, Map<String, ProfileLock>>(
      ProfileLocksNotifier.new,
    );
