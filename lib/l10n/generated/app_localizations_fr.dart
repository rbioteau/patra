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
  String get savedServers => 'Vos serveurs';

  @override
  String get addServer => 'Ajouter un serveur';

  @override
  String get editServer => 'Modifier';

  @override
  String get forgetServer => 'Oublier';

  @override
  String forgetServerConfirm(String server) {
    return 'Oublier $server ?';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get navHome => 'Accueil';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navDownloads => 'Téléchargements';

  @override
  String get navSettings => 'Réglages';

  @override
  String get continueSection => 'Reprendre';

  @override
  String get onDeckSection => 'À suivre';

  @override
  String get librariesTitle => 'Bibliothèques';

  @override
  String get homeEmpty =>
      'Rien à lire pour l\'instant. Vos bibliothèques apparaîtront ici dès que le serveur les aura analysées.';

  @override
  String get libraryEmpty => 'Cette bibliothèque est vide.';

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
  String get issuesTitle => 'Numéros';

  @override
  String issueLabel(String range) {
    return 'Numéro #$range';
  }

  @override
  String get booksTitle => 'Livres';

  @override
  String bookLabel(String name) {
    return 'Livre $name';
  }

  @override
  String get storylineTitle => 'Arc narratif';

  @override
  String get pdfPreparing => 'Préparation du PDF';

  @override
  String get pdfPreparingBody =>
      'Le serveur découpe ce PDF en pages. Seule la première ouverture attend.';

  @override
  String get formatNotSupported => 'Format pas encore pris en charge';

  @override
  String get formatNotSupportedBody =>
      'Cette série est un EPUB. Patra lit les formats image et les PDF pour l\'instant ; la prise en charge de l\'EPUB arrive.';

  @override
  String seriesChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
      zero: 'Aucun chapitre',
    );
    return '$_temp0';
  }

  @override
  String seriesVolumeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tomes',
      one: '1 tome',
    );
    return '$_temp0';
  }

  @override
  String seriesContinueVolume(String volume) {
    return 'Reprendre — tome $volume';
  }

  @override
  String seriesContinue(String chapter) {
    return 'Reprendre — ch. $chapter';
  }

  @override
  String seriesContinueIssue(String issue) {
    return 'Reprendre — #$issue';
  }

  @override
  String seriesContinueBook(String book) {
    return 'Reprendre — livre $book';
  }

  @override
  String get seriesContinuePlain => 'Reprendre';

  @override
  String get seriesStartReading => 'Commencer la lecture';

  @override
  String get seriesReadAgain => 'Relire';

  @override
  String get readTag => 'LU';

  @override
  String pageCount(int count) {
    return '$count pages';
  }

  @override
  String pageProgress(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String pageCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String pageSpreadCounter(int first, int last, int total) {
    return '$first–$last / $total';
  }

  @override
  String get readingDirection => 'Sens de lecture';

  @override
  String get readingDirectionLtr => 'De gauche à droite';

  @override
  String get readingDirectionRtl => 'De droite à gauche';

  @override
  String get readingModeWebtoon => 'Vertical';

  @override
  String get savePill => 'Enregistrer';

  @override
  String downloadingPct(int percent) {
    return '$percent %';
  }

  @override
  String get savedPill => 'Enregistré';

  @override
  String get downloadsTitle => 'Téléchargements';

  @override
  String get emptyDownloads =>
      'Aucun chapitre enregistré. Enregistrez un chapitre depuis une série pour le lire sans le serveur.';

  @override
  String storageUsed(String size) {
    return '$size sur cet appareil';
  }

  @override
  String get markRead => 'Marquer lu';

  @override
  String get markUnread => 'Marquer non lu';

  @override
  String get removeDownload => 'Supprimer';

  @override
  String removeDownloadConfirm(String title) {
    return 'Supprimer la copie enregistrée de $title ?';
  }

  @override
  String get serverUnreachable => 'Serveur inaccessible';

  @override
  String get offlineBanner =>
      'Serveur inaccessible — mode hors ligne. Les chapitres enregistrés restent lisibles.';

  @override
  String get storageSectionLabel => 'Stockage';

  @override
  String get imageCacheLabel => 'Cache d\'images';

  @override
  String get imageCacheCaption =>
      'Couvertures et pages lues en ligne. Le vider ne touche jamais aux chapitres enregistrés.';

  @override
  String get clearCache => 'Vider';

  @override
  String get imageCacheLimit => 'Taille maximale';

  @override
  String get imageCacheLimitCaption =>
      'Une fois plein, les images les plus anciennes sont supprimées en premier.';

  @override
  String downloadedChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres enregistrés',
      one: '1 chapitre enregistré',
      zero: 'Aucun chapitre enregistré',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get serverSectionLabel => 'Serveur';

  @override
  String get switchServer => 'Changer de serveur';

  @override
  String get readingSectionLabel => 'Lecture';

  @override
  String get defaultReadingDirection => 'Sens de lecture par défaut';

  @override
  String get aboutSectionLabel => 'À propos';

  @override
  String sizeBytes(int count) {
    return '$count o';
  }

  @override
  String sizeMegabytes(String count) {
    return '$count Mo';
  }

  @override
  String sizeGigabytes(String count) {
    return '$count Go';
  }
}
