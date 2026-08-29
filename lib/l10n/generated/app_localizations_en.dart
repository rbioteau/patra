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
  String get savedServers => 'Your servers';

  @override
  String get addServer => 'Add a server';

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
  String get libraryEmpty => 'This library is empty.';

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
  String get readingDirection => 'Reading direction';

  @override
  String get readingDirectionLtr => 'Left to right';

  @override
  String get readingDirectionRtl => 'Right to left';

  @override
  String get readingModeWebtoon => 'Webtoon (vertical)';

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
  String get clearCache => 'Clear';

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
  String get readingSectionLabel => 'Reading';

  @override
  String get defaultReadingDirection => 'Default reading direction';

  @override
  String get aboutSectionLabel => 'About';

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
