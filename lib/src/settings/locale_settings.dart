import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/generated/app_localizations.dart';

/// The language the app is shown in, when the user would rather not be shown
/// the one the device is set to.
///
/// `null` means the device decides, which is both the default and a real
/// choice a person can come back to — not merely the absence of a stored one.
/// Everything downstream already reads that way: it is what `MaterialApp`'s
/// `locale` takes to mean "resolve against the system".
class LocaleSettingsStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'appLocale';

  /// Only a language this build actually ships is accepted back. A code stored
  /// by an older version whose locale has since been dropped resolves to the
  /// system rather than to a language with no translations behind it.
  static Locale? _supported(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }

  static Future<Locale?> load() async {
    try {
      return _supported(await _storage.read(key: _key));
    } on Exception {
      return null;
    }
  }

  static Future<void> save(Locale? locale) async {
    try {
      if (locale == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: locale.languageCode);
      }
    } on Exception {
      // A preference is not worth surfacing a storage failure for.
    }
  }
}

/// Preference restored before the app started; injected in main().
final initialLocaleProvider = Provider<Locale?>((ref) => null);

/// The language the app is shown in. Null follows the device.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => ref.read(initialLocaleProvider);

  Future<void> set(Locale? locale) async {
    state = locale;
    await LocaleSettingsStore.save(locale);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

/// What each language calls itself.
///
/// Deliberately *not* translated, and deliberately not derived: a language is
/// listed under its own name so someone who has landed in a language they
/// cannot read can still find their way out. `intl` ships no endonyms, so this
/// is the one place a new locale needs a line of its own — without it the list
/// would offer a bare language code.
String languageEndonym(Locale locale) => switch (locale.languageCode) {
  'en' => 'English',
  'fr' => 'Français',
  _ => locale.languageCode.toUpperCase(),
};
