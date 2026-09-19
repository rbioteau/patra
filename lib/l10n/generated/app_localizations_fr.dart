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
      'Nécessite un serveur Kavita v0.9+ · Connexion conservée dans le stockage sécurisé';

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
  String connectionSignInExpired(String name, String host) {
    return 'La connexion enregistrée de $name sur $host a été refusée. Votre mot de passe est de nouveau nécessaire.';
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
  String get addProfile => 'Ajouter un profil';

  @override
  String get whoIsReading => 'Qui lit ?';

  @override
  String get useAnotherServer => 'Utiliser un autre serveur';

  @override
  String get backToProfiles => 'Retour à vos profils';

  @override
  String get forgetProfile => 'Oublier';

  @override
  String get forgetThisProfile => 'Oublier ce profil';

  @override
  String forgetProfileConfirm(String name, String host) {
    return 'Oublier $name sur $host ?';
  }

  @override
  String forgetProfileDownloads(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres enregistrés ($size) seront aussi supprimés.',
      one: '1 chapitre enregistré ($size) sera aussi supprimé.',
    );
    return '$_temp0';
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
  String libraryEmptyBodyAdmin(String library) {
    return 'Patra affiche ce que votre serveur a analysé. Ajoutez des fichiers à $library sur le serveur, puis demandez une analyse.';
  }

  @override
  String get libraryActions => 'Actions de la bibliothèque';

  @override
  String get askServerToScan => 'Demander une analyse';

  @override
  String get scanNeedsServer => 'Nécessite le serveur — hors ligne';

  @override
  String get scanning => 'Analyse en cours…';

  @override
  String get scanRequested =>
      'Analyse demandée. Kavita peut prendre un moment — tirez pour rafraîchir.';

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
  String get bookPageUnavailable => 'Cette page n\'a pas pu être chargée.';

  @override
  String get bookContents => 'Sommaire';

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
  String get seriesContinuePlain => 'Reprendre';

  @override
  String get seriesStartReading => 'Commencer la lecture';

  @override
  String get seriesReadAgain => 'Relire';

  @override
  String readPageCount(int count) {
    return 'Lu · $count pages';
  }

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
  String get pageWidth => 'Largeur de page';

  @override
  String get pageWidthExplained =>
      'Largeur à laquelle les pages sont dessinées en lecture verticale. 100 % est tout l\'écran.';

  @override
  String get pageWidthInPaged =>
      'Pas en lecture page à page — la page y est ajustée à l\'écran.';

  @override
  String get bookTextSize => 'Taille du texte';

  @override
  String get bookTextSizeExplained =>
      'La taille des mots d\'un livre. Tous les livres sont composés à cette taille.';

  @override
  String textSizePoints(int size) {
    return '$size pt';
  }

  @override
  String get bookLineSpacing => 'Interligne';

  @override
  String get bookLineSpacingExplained =>
      'L\'espace entre les lignes d\'un livre, en part de la taille des mots.';

  @override
  String get bookReadingFace => 'Police de lecture';

  @override
  String get bookReadingFaceExplained =>
      'La police d\'un livre. Tous les livres sont composés dans cette police.';

  @override
  String get readingFaceSpaceGrotesk => 'Space Grotesk';

  @override
  String get readingFaceSourceSerif4 => 'Source Serif 4';

  @override
  String get readingFaceLiterata => 'Literata';

  @override
  String get readingFaceAtkinsonHyperlegibleNext =>
      'Atkinson Hyperlegible Next';

  @override
  String percent(int value) {
    return '$value %';
  }

  @override
  String get readingDirection => 'Sens de lecture';

  @override
  String get readingDirectionLtr => 'De gauche à droite';

  @override
  String get readingDirectionRtl => 'De droite à gauche';

  @override
  String get readingDirectionVerticalScroll => 'Vertical';

  @override
  String directionSourceSeries(String direction) {
    return '$direction — choisi pour cette série';
  }

  @override
  String directionSourceDetected(String direction) {
    return '$direction — détecté d\'après l\'œuvre';
  }

  @override
  String directionSourceBuiltIn(String direction) {
    return '$direction — le réglage par défaut';
  }

  @override
  String directionSourceLibrary(String direction, String library) {
    return '$direction — le réglage par défaut de $library';
  }

  @override
  String promoteLibraryDirection(String library) {
    return 'En faire le réglage par défaut de $library';
  }

  @override
  String get followDefaultDirection => 'Suivre le réglage par défaut';

  @override
  String followDefaultDirectionForLibrary(String library) {
    return 'Suivre le réglage par défaut de $library';
  }

  @override
  String get thisLibrary => 'cette bibliothèque';

  @override
  String get savePill => 'Enregistrer';

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
  String copyOutOfDate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return 'Obsolète — le serveur compte maintenant $_temp0';
  }

  @override
  String get refreshCopy => 'Actualiser';

  @override
  String get refreshingCopy => 'Actualisation…';

  @override
  String get downloadsQueueSection => 'En cours de téléchargement';

  @override
  String get downloadsPendingSection => 'À reprendre';

  @override
  String get downloadsSavedSection => 'Enregistrés';

  @override
  String get downloadsPausedSection => 'En pause';

  @override
  String downloadsBatchSummary(int done, int total, int percent) {
    return '$done sur $total · $percent %';
  }

  @override
  String get downloadsWaiting => 'En attente';

  @override
  String get downloadsPreparing => 'Préparation';

  @override
  String get downloadsInProgress => 'En cours';

  @override
  String get downloadsStoppedShort => 'Interrompu';

  @override
  String get downloadsFailed => 'N\'a pas pu finir';

  @override
  String get downloadsPaused => 'En pause';

  @override
  String get resumeDownload => 'Reprendre';

  @override
  String resumeDownloadsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count téléchargements se sont arrêtés à la fermeture de l\'application.',
      one: 'Un téléchargement s\'est arrêté à la fermeture de l\'application.',
    );
    return '$_temp0';
  }

  @override
  String get resumeDownloadsLater => 'Plus tard';

  @override
  String pauseDownload(String title) {
    return 'Mettre en pause $title';
  }

  @override
  String get serverUnreachable => 'Serveur inaccessible';

  @override
  String get offlineBanner =>
      'Serveur inaccessible — mode hors ligne. Les chapitres enregistrés restent lisibles.';

  @override
  String get homeOfflineWithSaved =>
      'Le serveur est hors de portée. Ce que vous avez enregistré est toujours là.';

  @override
  String get homeOfflineNothingSaved =>
      'Le serveur est hors de portée, et rien n\'est encore enregistré sur cet appareil.';

  @override
  String get seeDownloads => 'Voir vos téléchargements';

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
  String get otherProfilesSectionLabel => 'Autres profils sur cet appareil';

  @override
  String get switchProfile => 'Changer de profil';

  @override
  String get profileLock => 'Verrouiller ce profil';

  @override
  String get profileLockExplained =>
      'Un code empêche les personnes avec qui vous partagez cet appareil d\'entrer dans votre profil. Ce n\'est pas une protection en cas de perte ou de vol : ce qui est enregistré ici reste lisible sur un appareil perdu.';

  @override
  String get profileLockSuggested =>
      'Utile sur un appareil partagé : rien sur le serveur ne limite ce profil.';

  @override
  String get profileLockChange => 'Changer le code';

  @override
  String get profileLockChoose => 'Choisissez un code';

  @override
  String get profileLockRepeat => 'Saisissez-le à nouveau';

  @override
  String get profileLockMismatch => 'Les deux codes sont différents.';

  @override
  String profileLockEnterFor(String name) {
    return 'Saisissez le code de $name';
  }

  @override
  String get profileLockWrong => 'Code incorrect.';

  @override
  String get profileLockUseBiometrics => 'Déverrouiller sans le code';

  @override
  String profileLockBiometricReason(String name) {
    return 'Déverrouiller le profil de $name';
  }

  @override
  String get profileLockBackspace => 'Effacer';

  @override
  String get profileLockedBadge => 'Verrouillé';

  @override
  String get serverOnline => 'Connecté';

  @override
  String get serverOffline => 'Hors ligne';

  @override
  String serverVersion(String version) {
    return 'Kavita $version';
  }

  @override
  String get serverChecking => 'Vérification…';

  @override
  String get generalSectionLabel => 'Général';

  @override
  String get appLanguage => 'Langue';

  @override
  String get appLanguageSystem => 'Système';

  @override
  String get aboutSectionLabel => 'À propos';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get licensesTitle => 'Licences';

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

  @override
  String get batchDownload => 'Télécharger la suite';

  @override
  String volumeRangeLabel(String from, String to) {
    return 'Tomes $from à $to';
  }

  @override
  String chapterRangeLabel(String from, String to) {
    return 'Chapitres $from à $to';
  }

  @override
  String issueRangeLabel(String from, String to) {
    return 'Numéros #$from à #$to';
  }

  @override
  String bookRangeLabel(String from, String to) {
    return 'Livres $from à $to';
  }

  @override
  String get batchDownloadSizeCaption =>
      'Combien de chapitres non lus un appui sur une série enregistre, à partir d\'où vous en êtes, d\'un tome à l\'autre.';

  @override
  String batchSizeHint(int count) {
    return 'Les $count prochains sont en cours. Ce nombre se règle dans Réglages › Stockage.';
  }

  @override
  String get batchDownloadVolume => 'Télécharger le reste';

  @override
  String get batchDownloadSize => 'Taille du téléchargement par lot';

  @override
  String batchDownloadSizeOption(int count) {
    return '$count chapitres';
  }

  @override
  String get inThisSeries => 'Dans cette série';

  @override
  String get sortSheetTitle => 'Trier';

  @override
  String sortTooltip(String order) {
    return 'Trier : $order';
  }

  @override
  String get sortReadingPosition => 'Position de lecture';

  @override
  String get sortReadingPositionHint =>
      'Là où vous en êtes d\'abord, puis la suite';

  @override
  String get sortNewest => 'Plus récents';

  @override
  String get sortNewestHint => 'Les derniers d\'abord';

  @override
  String get sortOldest => 'Plus anciens';

  @override
  String get sortOldestHint => 'Depuis le début';

  @override
  String get groupReadingNow => 'En cours';

  @override
  String get groupUpNext => 'À suivre';

  @override
  String get groupStartHere => 'Commencer ici';

  @override
  String groupAlreadyRead(int count) {
    return 'Déjà lus · $count';
  }

  @override
  String get showReadChapters => 'Afficher';

  @override
  String get hideReadChapters => 'Masquer';

  @override
  String batchDownloading(int count) {
    return 'Téléchargement des $count prochains…';
  }

  @override
  String batchDownloadingProgress(int done, int count) {
    return '$done sur $count enregistrés';
  }

  @override
  String batchAllSaved(int count) {
    return 'Les $count prochains sont enregistrés';
  }

  @override
  String get batchReadyOffline => 'Prêts à lire hors ligne';

  @override
  String batchAlreadySaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count déjà enregistrés',
      one: '1 déjà enregistré',
    );
    return '$_temp0';
  }
}
