import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/settings/reading_settings.dart';

import 'test_support.dart';

void main() {
  test('the direction saved before the rename is still the one restored', () {
    // The enum name *is* the stored value, and an unrecognised string falls
    // back to left-to-right without a word — so dropping the legacy name is
    // how a reader who chose vertical scrolling gets left-to-right on the
    // next launch and nothing says why.
    final store = ReadingSettingsStore(
      MemoryKeychain({'readingDirection': 'webtoon'}),
    );
    expect(store.load(), completion(ReadingDirection.verticalScroll));
  });

  test('a preference is written under the name the enum carries now', () async {
    final keychain = MemoryKeychain({'readingDirection': 'webtoon'});
    await ReadingSettingsStore(keychain).save(ReadingDirection.verticalScroll);
    expect(keychain.values['readingDirection'], 'verticalScroll');
  });

  test('a value from no version at all is no answer', () {
    final store = ReadingSettingsStore(
      MemoryKeychain({'readingDirection': 'sideways'}),
    );
    expect(store.load(), completion(isNull));
  });

  test('a device that never chose has no answer, and that is not the built-in '
      'left-to-right', () async {
    // The chain only asks the device's own default last, and it must not be
    // answered by a fallback nobody chose: a direction detected from the work
    // (#57) has to be able to beat it, where it must never beat a direction
    // somebody stored (ADR-0007). Left-to-right is where the chain *ends*,
    // which is a different thing from what this device holds.
    final store = ReadingSettingsStore(MemoryKeychain());
    expect(await store.load(), isNull);

    await store.save(ReadingDirection.rightToLeft);
    expect(await store.load(), ReadingDirection.rightToLeft);
  });

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
