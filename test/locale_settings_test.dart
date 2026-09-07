import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/settings/locale_settings.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a language is listed under its own name', () {
    // Never translated: someone who has landed in a language they cannot read
    // has to be able to find their way out of it.
    expect(languageEndonym(const Locale('fr')), 'Français');
    expect(languageEndonym(const Locale('en')), 'English');
  });

  test('every shipped language has a name of its own', () {
    // intl ships no endonyms, so a new locale needs a line added by hand. A
    // bare language code in the picker is what forgetting looks like.
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        languageEndonym(locale),
        isNot(locale.languageCode.toUpperCase()),
        reason: 'add ${locale.languageCode} to languageEndonym',
      );
    }
  });

  test('a language this build does not ship resolves to the device', () {
    // Rather than to a language with no translations behind it.
    expect(supportedLocale('xh'), isNull);
    expect(supportedLocale(''), isNull);
    expect(supportedLocale('fr'), const Locale('fr'));
  });

  test("the device's own language round-trips, and null clears it", () async {
    final stored = mockSecureStorage();
    expect(await LocaleSettingsStore.load(), isNull);

    await LocaleSettingsStore.save(const Locale('fr'));
    expect(stored['appLocale'], 'fr');
    expect(await LocaleSettingsStore.load(), const Locale('fr'));

    await LocaleSettingsStore.save(null);
    expect(
      stored.containsKey('appLocale'),
      isFalse,
      reason: 'following the device is stored as no preference at all',
    );
  });
}
