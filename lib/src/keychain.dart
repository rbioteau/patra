/// Where the device keeps what it must not keep in the open: one row per
/// name, and every one of them the device's own.
///
/// It holds the auth keys, the profile locks, each person's preferences, the
/// device's own defaults and the install's device id. Per ADR-0004 an auth
/// key is a **whole Kavita account** — non-expiring, and only its owner can
/// rotate one — so a device remembering four profiles keeps four complete
/// account credentials here. That is the reason this is a seam and not a
/// convenience: what goes through it is worth naming.
///
/// **Every store here used to build its own.** There were seven
/// `FlutterSecureStorage()`s across `auth/`, `settings/`, `lock/` and
/// `api/`: two behind a seam of their own — two seams, in fact, declaring the
/// identical `read`/`write`/`clear` under two names — and five behind
/// nothing at all. A store that creates its own platform dependency cannot be
/// exercised without one, so tests reached *under* them through a mock of the
/// plugin's method channel; and on a test binding this plugin has no platform
/// behind it, so on Linux a write reaches for libsecret and **hangs the test
/// rather than failing it**. Fourteen suites carried that mock.
///
/// So the interface is the plugin's own shape, kept deliberately narrow: the
/// real adapter is a pass-through, the fake is a `Map`, and a store's own
/// tests exercise its rules rather than a channel.
///
/// **Nothing is swallowed here.** Every store already decides for itself what
/// a failure costs — `SessionStorage.save` keeps a running session over a
/// write it could not make, `ProfileLockStore` refuses to fail a startup over
/// a read — and those are different answers to different questions. An
/// adapter that caught for them would take that choice away and make each one
/// unable to tell "nothing stored" from "could not be read".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One keyed row store, and the whole of what this app asks of a keychain.
///
/// [readAll] earns its place: `SessionStorage` reads two rows and sweeps
/// seven retired ones on the path `main()` awaits before the first frame, and
/// nine round trips there would be paid for on every launch.
abstract class Keychain {
  Future<String?> read(String key);

  Future<Map<String, String>> readAll();

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The device's real keychain: the Android keystore, and iOS's own.
///
/// No options on purpose — every store here built a bare
/// `const FlutterSecureStorage()`, so there is nothing per-store to carry
/// over, and a difference introduced here would apply to rows that were
/// written without it.
class SecureKeychain implements Keychain {
  const SecureKeychain();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// The one thing a test overrides to stand in for the device's keychain.
///
/// One provider rather than one per store, and that is the point of it: the
/// four stateless stores are derived from this, so a second instance of one
/// costs nothing and there is no reason for `main()` and the tree to agree
/// about which instance exists — only about which keychain does. The two
/// stores that hold their loaded state (`ProfileLockStore`,
/// `ProfilePreferencesStore`) still arrive as instances of their own, built
/// on this in `main()`.
final keychainProvider = Provider<Keychain>((ref) => const SecureKeychain());
