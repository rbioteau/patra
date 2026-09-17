import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../keychain.dart';

/// Whether this device has been told, once, that the batch's size is a
/// setting.
///
/// The batch card says what it will fetch and never why that many; the one
/// moment the question is asked is the first tap, so that is where the answer
/// goes — a SnackBar naming the setting, with a way to it — and then never
/// again. The flag is the **device's**, not a person's: it is the interface
/// being discovered, not a choice being made, and a family tablet has one
/// interface however many people read on it. Held in the keychain like the
/// device's other rows, and read only when a tap asks, so nothing is loaded
/// for it before the app starts.
class BatchSizeHintStore {
  const BatchSizeHintStore(this._keychain);

  final Keychain _keychain;

  static const _key = 'batchSizeHintShown';

  /// True where it was shown — and where the keychain cannot say, because a
  /// hint that cannot be remembered is not worth repeating on every tap.
  Future<bool> wasShown() async {
    try {
      return await _keychain.read(_key) != null;
    } on Exception {
      return true;
    }
  }

  Future<void> markShown() async {
    try {
      await _keychain.write(_key, 'true');
    } on Exception {
      // A hint is not worth surfacing a storage failure for.
    }
  }
}

/// Derived from the device's keychain, holding nothing of its own.
final batchSizeHintProvider = Provider<BatchSizeHintStore>(
  (ref) => BatchSizeHintStore(ref.watch(keychainProvider)),
);
