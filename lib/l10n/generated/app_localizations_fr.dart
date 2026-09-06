// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTagline =>
      'Feuille après feuille. Un lecteur pour votre bibliothèque Kavita.';

  @override
  String get loginFooter =>
      'Nécessite un serveur Kavita v0.9+ · Jetons conservés dans le stockage sécurisé';

  @override
  String get serverAddress => 'Adresse du serveur';

  @override
  String get serverAddressHint => 'https://kavita.example.com';

  @override
  String get serverAddressRequired => 'Adresse requise';

  @override
  String get serverAddressInvalid =>
      'Saisissez une adresse complète, commençant par http:// ou https://';

  @override
  String get serverAddressLocalHint =>
      'Un serveur sur votre réseau peut utiliser http:// — par exemple http://192.168.1.10:5000';

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
  String unexpectedError(String error) {
    return 'Une erreur est survenue : $error';
  }

  @override
  String connectionUnreachable(String host) {
    return 'Impossible de joindre $host. Vérifiez l\'adresse, et que cet appareil est bien sur le même réseau que le serveur.';
  }

  @override
  String connectionBlockedByBrowser(String host) {
    return 'Le navigateur a bloqué la requête de Patra vers $host. Soit rien ne répond à cette adresse, soit le serveur n\'autorise pas les requêtes venant de cette page — Kavita doit être configuré pour cela, généralement dans le proxy inverse placé devant lui.';
  }

  @override
  String connectionTimedOut(String host) {
    return '$host n\'a pas répondu à temps.';
  }

  @override
  String connectionBadCertificate(String host) {
    return '$host présente un certificat que cet appareil ne reconnaît pas. Un certificat auto-signé doit d\'abord être installé sur l\'appareil.';
  }

  @override
  String get connectionBadCredentials =>
      'Le serveur a refusé ce nom d\'utilisateur ou ce mot de passe.';

  @override
  String connectionForbidden(String host) {
    return '$host a refusé : ce compte n\'y est pas autorisé.';
  }

  @override
  String connectionNotKavita(String host) {
    return '$host a répondu, mais aucun serveur Kavita ne se trouve à cette adresse.';
  }

  @override
  String connectionServerError(String host, int status) {
    return '$host a répondu par une erreur ($status).';
  }

  @override
  String get savedServers => 'Vos serveurs';

  @override
  String get addServer => 'Ajouter un serveur';

  @override
  String get openServer => 'Ouvrir';

  @override
  String get backToServers => 'Retour à vos serveurs';

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
  String get libraryEmpty => 'Cette bibliothèque est vide';

  @override
  String libraryEmptyBody(String library) {
    return 'Patra affiche ce que votre serveur a analysé. Ajoutez des fichiers à $library sur le serveur, puis lancez une analyse depuis Kavita.';
  }

  @override
  String get askServerToScan => 'Demander une analyse';

  @override
  String get scanning => 'Analyse en cours…';

  @override
  String get scanRequested =>
      'Analyse demandée. Kavita peut prendre un moment — tirez pour rafraîchir.';

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
  String get readerSettings => 'Réglages de lecture';

  @override
  String get dragToMagnify => 'Glisser pour agrandir';

  @override
  String get dragToMagnifyInVertical =>
      'Pas en lecture verticale — le glissement y fait défiler le chapitre.';

  @override
  String get dragToMagnifyExplained =>
      'Un doigt agrandit la page autour du point touché, et la longueur du geste décide de combien. Les pages se tournent en touchant les bords.';

  @override
  String get readingDirection => 'Sens de lecture';

  @override
  String get readingDirectionLtr => 'De gauche à droite';

  @override
  String get readingDirectionRtl => 'De droite à gauche';

  @override
  String get readingDirectionVerticalScroll => 'Vertical';

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
  String get clearCache => 'Vider le cache';

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
  String get serverOnline => 'Connecté';

  @override
  String get serverOffline => 'Hors ligne';

  @override
  String get serverChecking => 'Vérification…';

  @override
  String get generalSectionLabel => 'Général';

  @override
  String get appLanguage => 'Langue';

  @override
  String get appLanguageSystem => 'Système';

  @override
  String get readingSectionLabel => 'Lecture';

  @override
  String get defaultReadingDirection => 'Sens de lecture par défaut';

  @override
  String get aboutSectionLabel => 'À propos';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

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
