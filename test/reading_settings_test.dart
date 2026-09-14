import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/settings/reading_settings.dart';

import 'test_support.dart';

void main() {
  // The direction is not here any more: #58 took the device's rung out of the
  // chain, so the key is written no more. What is left of this store is the
  // one device preference that survived it, and `directionNamed`, which the
  // two direction maps still parse their values with
  // (`test/profile_preferences_test.dart`).
  group('the magnify preference', () {
    // The concept was called a loupe until the word was found to be wrong for
    // it. The identifiers moved; the storage key deliberately did not, because
    // it is already written on every device that has turned the setting on.
    test(
      'is stored under its original key, whatever the code calls it',
      () async {
        final keychain = MemoryKeychain();
        await ReadingSettingsStore(keychain).saveMagnify(true);
        expect(
          keychain.values.keys.where((k) => k.endsWith('loupeGesture')),
          isNotEmpty,
          reason:
              'renaming this key would silently reset the setting on every '
              'device that has it on',
        );
      },
    );

    test('round-trips, and is off when nothing was ever stored', () async {
      final store = ReadingSettingsStore(MemoryKeychain());
      expect(await store.loadMagnify(), isFalse);
      await store.saveMagnify(true);
      expect(await store.loadMagnify(), isTrue);
      await store.saveMagnify(false);
      expect(await store.loadMagnify(), isFalse);
    });

    test('a value written before the rename still reads back on', () async {
      // The exact string a device that turned it on already holds. (Android
      // prefixes it natively, below the method channel, so what the Dart side
      // reads is the bare key.)
      final store = ReadingSettingsStore(
        MemoryKeychain({'loupeGesture': 'true'}),
      );
      expect(await store.loadMagnify(), isTrue);
    });
  });
}
