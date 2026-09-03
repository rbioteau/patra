// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Leaf by leaf. A reader for your Kavita library.';

  @override
  String get loginFooter =>
      'Requires a Kavita server v0.9+ · Tokens kept in secure storage';

  @override
  String get serverAddress => 'Server address';

  @override
  String get serverAddressHint => 'https://kavita.example.com';

  @override
  String get serverAddressRequired => 'Server address is required';

  @override
  String get serverAddressInvalid =>
      'Enter a full address, starting with http:// or https://';

  @override
  String get serverAddressLocalHint =>
      'A server on your own network can use http:// — for example http://192.168.1.10:5000';

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
  String unexpectedError(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String connectionUnreachable(String host) {
    return 'Could not reach $host. Check the address, and that this device is on the same network as the server.';
  }

  @override
  String connectionTimedOut(String host) {
    return '$host did not answer in time.';
  }

  @override
  String connectionBadCertificate(String host) {
    return '$host presented a certificate this device does not trust. A self-signed certificate has to be installed on the device first.';
  }

  @override
  String get connectionBadCredentials =>
      'The server rejected this username or password.';

  @override
  String connectionForbidden(String host) {
    return '$host refused: this account is not allowed to do that.';
  }

  @override
  String connectionNotKavita(String host) {
    return '$host answered, but there is no Kavita server behind that address.';
  }

  @override
  String connectionServerError(String host, int status) {
    return '$host answered with an error ($status).';
  }

  @override
  String get savedServers => 'Your servers';

  @override
  String get addServer => 'Add a server';

  @override
  String get openServer => 'Open';

  @override
  String get backToServers => 'Back to your servers';

  @override
  String get editServer => 'Edit';

  @override
  String get forgetServer => 'Forget';

  @override
  String forgetServerConfirm(String server) {
    return 'Forget $server?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navSettings => 'Settings';

  @override
  String get continueSection => 'Continue';

  @override
  String get onDeckSection => 'On deck';

  @override
  String get librariesTitle => 'Libraries';

  @override
  String get homeEmpty =>
      'Nothing to read yet. Your libraries will show up here once the server has scanned them.';

  @override
  String get libraryEmpty => 'This library is empty';

  @override
  String libraryEmptyBody(String library) {
    return 'Patra shows what your server has scanned. Add files to $library on the server, then scan it from Kavita.';
  }

  @override
  String get askServerToScan => 'Ask server to scan';

  @override
  String get scanning => 'Scanning…';

  @override
  String get scanRequested =>
      'Scan requested. Kavita may take a while — pull down to refresh.';

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
  String get issuesTitle => 'Issues';

  @override
  String issueLabel(String range) {
    return 'Issue #$range';
  }

  @override
  String get booksTitle => 'Books';

  @override
  String bookLabel(String name) {
    return 'Book $name';
  }

  @override
  String get storylineTitle => 'Storyline';

  @override
  String get pdfPreparing => 'Preparing the PDF';

  @override
  String get pdfPreparingBody =>
      'The server is turning this PDF into pages. Only the first open waits.';

  @override
  String get formatNotSupported => 'Format not supported yet';

  @override
  String get formatNotSupportedBody =>
      'This series is an EPUB. Patra reads image formats and PDFs for now; EPUB support is on the way.';

  @override
  String seriesChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
      zero: 'No chapters',
    );
    return '$_temp0';
  }

  @override
  String seriesVolumeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count volumes',
      one: '1 volume',
    );
    return '$_temp0';
  }

  @override
  String seriesContinueVolume(String volume) {
    return 'Continue — Vol. $volume';
  }

  @override
  String seriesContinue(String chapter) {
    return 'Continue — Ch. $chapter';
  }

  @override
  String seriesContinueIssue(String issue) {
    return 'Continue — #$issue';
  }

  @override
  String seriesContinueBook(String book) {
    return 'Continue — Book $book';
  }

  @override
  String get seriesContinuePlain => 'Continue';

  @override
  String get seriesStartReading => 'Start reading';

  @override
  String get seriesReadAgain => 'Read again';

  @override
  String get readTag => 'READ';

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
  String get dragToMagnify => 'Drag to magnify';

  @override
  String get dragToMagnifyExplained =>
      'One finger magnifies the page around the point you press, and how far you drag decides how much. Pages turn by tapping the sides.';

  @override
  String get readingDirection => 'Reading direction';

  @override
  String get readingDirectionLtr => 'Left to right';

  @override
  String get readingDirectionRtl => 'Right to left';

  @override
  String get readingDirectionVerticalScroll => 'Vertical';

  @override
  String get savePill => 'Save';

  @override
  String downloadingPct(int percent) {
    return '$percent%';
  }

  @override
  String get savedPill => 'Saved';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get emptyDownloads =>
      'No saved chapters yet. Save a chapter from a series to read it without the server.';

  @override
  String storageUsed(String size) {
    return '$size on this device';
  }

  @override
  String get markRead => 'Mark read';

  @override
  String get markUnread => 'Mark unread';

  @override
  String get removeDownload => 'Remove';

  @override
  String removeDownloadConfirm(String title) {
    return 'Remove the saved copy of $title?';
  }

  @override
  String get serverUnreachable => 'Server unreachable';

  @override
  String get offlineBanner =>
      'Server unreachable — offline mode. Saved chapters remain readable.';

  @override
  String get storageSectionLabel => 'Storage';

  @override
  String get imageCacheLabel => 'Image cache';

  @override
  String get imageCacheCaption =>
      'Covers and pages read online. Clearing it never touches saved chapters.';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get imageCacheLimit => 'Cache limit';

  @override
  String get imageCacheLimitCaption =>
      'Once full, the oldest images are removed first.';

  @override
  String downloadedChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved chapters',
      one: '1 saved chapter',
      zero: 'No saved chapter',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get serverSectionLabel => 'Server';

  @override
  String get switchServer => 'Switch server';

  @override
  String get serverOnline => 'Connected';

  @override
  String get serverOffline => 'Offline';

  @override
  String get serverChecking => 'Checking…';

  @override
  String get generalSectionLabel => 'General';

  @override
  String get appLanguage => 'Language';

  @override
  String get appLanguageSystem => 'System';

  @override
  String get readingSectionLabel => 'Reading';

  @override
  String get defaultReadingDirection => 'Default reading direction';

  @override
  String get aboutSectionLabel => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String sizeBytes(int count) {
    return '$count B';
  }

  @override
  String sizeMegabytes(String count) {
    return '$count MB';
  }

  @override
  String sizeGigabytes(String count) {
    return '$count GB';
  }
}
