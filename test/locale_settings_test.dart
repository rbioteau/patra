import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/settings/locale_settings.dart';

import 'test_support.dart';

void main() {
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

  test('following the device is the default, and it is a value', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(localeProvider), isNull);
  });

  test('a preference restored at startup is what the app opens in', () {
    final container = ProviderContainer(
      overrides: [initialLocaleProvider.overrideWithValue(const Locale('fr'))],
    );
    addTearDown(container.dispose);
    expect(container.read(localeProvider), const Locale('fr'));
  });

  testWidgets('the chosen language is the one the app is shown in', (
    tester,
  ) async {
    final stored = mockSecureStorage();
    final container = ProviderContainer(
      overrides: [initialLocaleProvider.overrideWithValue(const Locale('fr'))],
    );
    addTearDown(container.dispose);

    late AppLocalizations l10n;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: ref.watch(localeProvider),
            home: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context);
                return Text(l10n.appLanguage);
              },
            ),
          ),
        ),
      ),
    );

    // Set against a device whose own language is English.
    expect(find.text('Langue'), findsOneWidget);

    await container.read(localeProvider.notifier).set(null);
    await tester.pump();
    expect(
      find.text('Language'),
      findsOneWidget,
      reason: 'null hands the choice back to the device, it does not clear it',
    );
    expect(
      stored.containsKey('appLocale'),
      isFalse,
      reason: 'following the device is stored as no preference at all',
    );

    await container.read(localeProvider.notifier).set(const Locale('fr'));
    await tester.pump();
    expect(stored['appLocale'], 'fr');
  });
}
