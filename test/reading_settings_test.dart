import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/settings/reading_settings.dart';

import 'test_support.dart';

void main() {
  // Reaching the mocked storage channel needs a binding; these are plain
  // tests, not testWidgets, so nothing has made one.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the direction saved before the rename is still the one restored', () {
    // The enum name *is* the stored value, and an unrecognised string falls
    // back to left-to-right without a word — so dropping the legacy name is
    // how a reader who chose vertical scrolling gets left-to-right on the
    // next launch and nothing says why.
    mockSecureStorage({'readingDirection': 'webtoon'});
    expect(
      ReadingSettingsStore.load(),
      completion(ReadingDirection.verticalScroll),
    );
  });

  test('a preference is written under the name the enum carries now', () async {
    final stored = mockSecureStorage({'readingDirection': 'webtoon'});
    await ReadingSettingsStore.save(ReadingDirection.verticalScroll);
    expect(stored['readingDirection'], 'verticalScroll');
  });

  test('a value from no version at all is left-to-right', () {
    mockSecureStorage({'readingDirection': 'sideways'});
    expect(
      ReadingSettingsStore.load(),
      completion(ReadingDirection.leftToRight),
    );
  });

  group('the magnify preference', () {
    // The concept was called a loupe until the word was found to be wrong for
    // it. The identifiers moved; the storage key deliberately did not, because
    // it is already written on every device that has turned the setting on.
    test(
      'is stored under its original key, whatever the code calls it',
      () async {
        final stored = mockSecureStorage();
        await ReadingSettingsStore.saveMagnify(true);
        expect(
          stored.keys.where((k) => k.endsWith('loupeGesture')),
          isNotEmpty,
          reason:
              'renaming this key would silently reset the setting on every '
              'device that has it on',
        );
      },
    );

    test('round-trips, and is off when nothing was ever stored', () async {
      mockSecureStorage();
      expect(await ReadingSettingsStore.loadMagnify(), isFalse);
      await ReadingSettingsStore.saveMagnify(true);
      expect(await ReadingSettingsStore.loadMagnify(), isTrue);
      await ReadingSettingsStore.saveMagnify(false);
      expect(await ReadingSettingsStore.loadMagnify(), isFalse);
    });

    test('a value written before the rename still reads back on', () async {
      // The exact string a device that turned it on already holds. (Android
      // prefixes it natively, below the method channel, so what the Dart side
      // reads is the bare key.)
      mockSecureStorage({'loupeGesture': 'true'});
      expect(await ReadingSettingsStore.loadMagnify(), isTrue);
    });
  });
}
