// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'A Kavita client';

  @override
  String get serverAddress => 'Server address';

  @override
  String get serverAddressHint => 'https://kavita.example.com';

  @override
  String get serverAddressRequired => 'Server address is required';

  @override
  String get serverAddressInvalid => 'Invalid address (http(s)://…)';

  @override
  String get username => 'Username';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get signIn => 'Sign in';

  @override
  String loginFailed(String error) {
    return 'Could not sign in: $error';
  }

  @override
  String get librariesTitle => 'Libraries';

  @override
  String get signOut => 'Sign out';

  @override
  String get retry => 'Retry';

  @override
  String get volumesTitle => 'Volumes';

  @override
  String volumeLabel(String name) {
    return 'Volume $name';
  }

  @override
  String get chaptersTitle => 'Chapters';

  @override
  String get specialsTitle => 'Specials';

  @override
  String chapterLabel(String range) {
    return 'Chapter $range';
  }

  @override
  String pageCount(int count) {
    return '$count pages';
  }

  @override
  String pageProgress(int current, int total) {
    return 'Page $current / $total';
  }
}
