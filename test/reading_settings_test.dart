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
}
