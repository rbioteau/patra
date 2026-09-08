import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../keychain.dart';

/// The **device's** language, under the flat key it has always been written
/// to — and the one the *gate* is drawn in, since the picker and the sign-in
/// form stand in front of every session and have nobody to ask.
///
/// What a person chooses is theirs and lives in `profile_preferences.dart`;
/// choosing one moves this too, because there is no screen on which to set
/// the gate's language and the last choice made here is the only evidence of
/// what this household reads in.
///
/// `null` means the device decides, which is both the default and a real
/// choice a person can come back to — not merely the absence of a stored one.
/// Everything downstream already reads that way: it is what `MaterialApp`'s
/// `locale` takes to mean "resolve against the system".
class LocaleSettingsStore {
  const LocaleSettingsStore(this._keychain);

  final Keychain _keychain;

  static const _key = 'appLocale';

  Future<Locale?> load() async {
    try {
      return supportedLocale(await _keychain.read(_key));
    } on Exception {
      return null;
    }
  }

  Future<void> save(Locale? locale) async {
    try {
      if (locale == null) {
        await _keychain.delete(_key);
      } else {
        await _keychain.write(_key, locale.languageCode);
      }
    } on Exception {
      // A preference is not worth surfacing a storage failure for.
    }
  }
}

/// The device's own language, on the device's keychain — derived, like the
/// reading defaults, because it holds nothing of its own.
final localeSettingsProvider = Provider<LocaleSettingsStore>(
  (ref) => LocaleSettingsStore(ref.watch(keychainProvider)),
);

/// The shipped [Locale] [code] names, or null where the build ships none.
///
/// Only a language this build actually has is accepted back: a code stored by
/// an older version whose locale has since been dropped resolves to the
/// device rather than to a language with no translations behind it. An empty
/// code is the same answer, which is what "follow the device" is stored as.
Locale? supportedLocale(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == code) return locale;
  }
  return null;
}

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
