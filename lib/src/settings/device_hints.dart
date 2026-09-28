import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../keychain.dart';

/// Whether this device has been told something, once.
///
/// What is taught this way is that a series' volumes are selected by a
/// long-press: a line over the list says so until the gesture has been used
/// once. The keychain row is named per hint, so another can join it.
///
/// The flag is the **device's**, not a person's: it is the interface being
/// discovered, not a choice being made, and a family tablet has one interface
/// however many people read on it. Held in the keychain like the device's
/// other rows, and read only when a screen asks, so nothing is loaded for it
/// before the app starts.
class DeviceHint {
  const DeviceHint(this._keychain, this._key);

  final Keychain _keychain;
  final String _key;

  /// True where it was shown — and where the keychain cannot say, because a
  /// hint that cannot be remembered is not worth repeating on every visit.
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

/// The series screen's "long-press to select" line.
final selectionHintProvider = Provider<DeviceHint>(
  (ref) => DeviceHint(ref.watch(keychainProvider), 'selectionHintShown'),
);

/// Whether the selection line is still to be drawn: false until the keychain
/// has answered, so a device that has already learnt the gesture never sees
/// the line flash in and out.
class SelectionHintNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      !await ref.watch(selectionHintProvider).wasShown();

  /// The gesture has been used: the line goes, on this device, for good.
  Future<void> dismiss() async {
    if (state.value == false) return;
    state = const AsyncData(false);
    await ref.read(selectionHintProvider).markShown();
  }
}

final selectionHintVisibleProvider =
    AsyncNotifierProvider<SelectionHintNotifier, bool>(
      SelectionHintNotifier.new,
    );
