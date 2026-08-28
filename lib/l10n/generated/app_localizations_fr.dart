// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTagline => 'Un client Kavita';

  @override
  String get serverAddress => 'Adresse du serveur';

  @override
  String get serverAddressHint => 'https://kavita.example.com';

  @override
  String get serverAddressRequired => 'Adresse requise';

  @override
  String get serverAddressInvalid => 'Adresse invalide (http(s)://…)';

  @override
  String get username => 'Utilisateur';

  @override
  String get usernameRequired => 'Utilisateur requis';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordRequired => 'Mot de passe requis';

  @override
  String get signIn => 'Se connecter';

  @override
  String loginFailed(String error) {
    return 'Connexion impossible : $error';
  }

  @override
  String get librariesTitle => 'Bibliothèques';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get retry => 'Réessayer';

  @override
  String get volumesTitle => 'Tomes';

  @override
  String volumeLabel(String name) {
    return 'Tome $name';
  }

  @override
  String get chaptersTitle => 'Chapitres';

  @override
  String get specialsTitle => 'Hors-série';

  @override
  String chapterLabel(String range) {
    return 'Chapitre $range';
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
