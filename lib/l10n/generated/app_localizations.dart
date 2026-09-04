import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Subtitle under the wordmark on the login screen. 'patra' is Sanskrit for leaf, hence the opening.
  ///
  /// In en, this message translates to:
  /// **'Leaf by leaf. A reader for your Kavita library.'**
  String get appTagline;

  /// Reassurance note pinned to the bottom of the login screen
  ///
  /// In en, this message translates to:
  /// **'Requires a Kavita server v0.9+ · Tokens kept in secure storage'**
  String get loginFooter;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In en, this message translates to:
  /// **'https://kavita.example.com'**
  String get serverAddressHint;

  /// No description provided for @serverAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Server address is required'**
  String get serverAddressRequired;

  /// No description provided for @serverAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a full address, starting with http:// or https://'**
  String get serverAddressInvalid;

  /// Helper under the server address field, saying cleartext is allowed
  ///
  /// In en, this message translates to:
  /// **'A server on your own network can use http:// — for example http://192.168.1.10:5000'**
  String get serverAddressLocalHint;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Fallback for an unclassified failure, on any screen — never worded for one
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String unexpectedError(String error);

  /// No description provided for @connectionUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {host}. Check the address, and that this device is on the same network as the server.'**
  String connectionUnreachable(String host);

  /// No description provided for @connectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'{host} did not answer in time.'**
  String connectionTimedOut(String host);

  /// No description provided for @connectionBadCertificate.
  ///
  /// In en, this message translates to:
  /// **'{host} presented a certificate this device does not trust. A self-signed certificate has to be installed on the device first.'**
  String connectionBadCertificate(String host);

  /// Kavita answers every credential failure with a bare 401, so this one message covers a wrong password and a locked-out account alike
  ///
  /// In en, this message translates to:
  /// **'The server rejected this username or password.'**
  String get connectionBadCredentials;

  /// No description provided for @connectionForbidden.
  ///
  /// In en, this message translates to:
  /// **'{host} refused: this account is not allowed to do that.'**
  String connectionForbidden(String host);

  /// No description provided for @connectionNotKavita.
  ///
  /// In en, this message translates to:
  /// **'{host} answered, but there is no Kavita server behind that address.'**
  String connectionNotKavita(String host);

  /// No description provided for @connectionServerError.
  ///
  /// In en, this message translates to:
  /// **'{host} answered with an error ({status}).'**
  String connectionServerError(String host, int status);

  /// Section label above the list of previously used servers
  ///
  /// In en, this message translates to:
  /// **'Your servers'**
  String get savedServers;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add a server'**
  String get addServer;

  /// Call to action on a saved server that still has a live session: one tap and it opens
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openServer;

  /// Leaves the sign-in form for the list of saved servers
  ///
  /// In en, this message translates to:
  /// **'Back to your servers'**
  String get backToServers;

  /// No description provided for @editServer.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editServer;

  /// No description provided for @forgetServer.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forgetServer;

  /// Confirmation title; server is a host name
  ///
  /// In en, this message translates to:
  /// **'Forget {server}?'**
  String forgetServerConfirm(String server);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Home section listing works the user has started reading
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueSection;

  /// Home section listing the next thing to read in each series
  ///
  /// In en, this message translates to:
  /// **'On deck'**
  String get onDeckSection;

  /// No description provided for @librariesTitle.
  ///
  /// In en, this message translates to:
  /// **'Libraries'**
  String get librariesTitle;

  /// No description provided for @homeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to read yet. Your libraries will show up here once the server has scanned them.'**
  String get homeEmpty;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'This library is empty'**
  String get libraryEmpty;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Patra shows what your server has scanned. Add files to {library} on the server, then scan it from Kavita.'**
  String libraryEmptyBody(String library);

  /// Only shown to a Kavita admin: every scan endpoint is behind AdminPolicy
  ///
  /// In en, this message translates to:
  /// **'Ask server to scan'**
  String get askServerToScan;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// Confirmation after POST /api/Library/scan; the scan itself is asynchronous
  ///
  /// In en, this message translates to:
  /// **'Scan requested. Kavita may take a while — pull down to refresh.'**
  String get scanRequested;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Section header for the volumes of a series
  ///
  /// In en, this message translates to:
  /// **'Volumes'**
  String get volumesTitle;

  /// Section header for a volume; name is Kavita's volume number as a string, e.g. '1' or '1-2'
  ///
  /// In en, this message translates to:
  /// **'Volume {name}'**
  String volumeLabel(String name);

  /// Section header for chapters that belong to no volume, shown only when the series also has real volumes
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chaptersTitle;

  /// Section header for special chapters (one-shots, extras)
  ///
  /// In en, this message translates to:
  /// **'Specials'**
  String get specialsTitle;

  /// Chapter list label in a manga or image library; range is Kavita's chapter number or number range, e.g. '12' or '12-14'
  ///
  /// In en, this message translates to:
  /// **'Chapter {range}'**
  String chapterLabel(String range);

  /// Section header replacing Chapters in a comic library, where the unit is the issue
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get issuesTitle;

  /// Chapter list label in a comic library; range is Kavita's number or number range
  ///
  /// In en, this message translates to:
  /// **'Issue #{range}'**
  String issueLabel(String range);

  /// Section header replacing Volumes and Chapters in a book or light novel library, where a volume is a book
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get booksTitle;

  /// Volume or chapter label in a book or light novel library; name is Kavita's number or title
  ///
  /// In en, this message translates to:
  /// **'Book {name}'**
  String bookLabel(String name);

  /// Section header for volumes and volumeless chapters read as one story, in reading order. Kavita's Storyline tab
  ///
  /// In en, this message translates to:
  /// **'Storyline'**
  String get storylineTitle;

  /// Shown while the server rasterises a PDF into page images on its first open
  ///
  /// In en, this message translates to:
  /// **'Preparing the PDF'**
  String get pdfPreparing;

  /// Explanation under the PDF preparing indicator
  ///
  /// In en, this message translates to:
  /// **'The server is turning this PDF into pages. Only the first open waits.'**
  String get pdfPreparingBody;

  /// Shown on a chapter the image reader cannot open (EPUB, PDF)
  ///
  /// In en, this message translates to:
  /// **'Format not supported yet'**
  String get formatNotSupported;

  /// Explanation shown in place of the reader for a format it cannot open
  ///
  /// In en, this message translates to:
  /// **'This series is an EPUB. Patra reads image formats and PDFs for now; EPUB support is on the way.'**
  String get formatNotSupportedBody;

  /// Chapter tally in the series hero
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No chapters} =1{1 chapter} other{{count} chapters}}'**
  String seriesChapterCount(int count);

  /// Volume tally in the series hero, used when the series is organised in volumes rather than loose chapters
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 volume} other{{count} volumes}}'**
  String seriesVolumeCount(int count);

  /// Hero button for a volume with no chapter breakdown; volume is its number
  ///
  /// In en, this message translates to:
  /// **'Continue — Vol. {volume}'**
  String seriesContinueVolume(String volume);

  /// Hero button when a chapter is already started; chapter is its number or range
  ///
  /// In en, this message translates to:
  /// **'Continue — Ch. {chapter}'**
  String seriesContinue(String chapter);

  /// Hero button in a comic library, where a chapter is an issue; issue is its number or range
  ///
  /// In en, this message translates to:
  /// **'Continue — #{issue}'**
  String seriesContinueIssue(String issue);

  /// Hero button in a book or light novel library, where the unit is the book; book is its number or name
  ///
  /// In en, this message translates to:
  /// **'Continue — Book {book}'**
  String seriesContinueBook(String book);

  /// Hero button when the thing to resume has no number to show — a special, or a lone book. Its title is free text and would stretch the button, so the button says only what it does
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get seriesContinuePlain;

  /// No description provided for @seriesStartReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get seriesStartReading;

  /// No description provided for @seriesReadAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get seriesReadAgain;

  /// Short uppercase tag marking a finished chapter
  ///
  /// In en, this message translates to:
  /// **'READ'**
  String get readTag;

  /// No description provided for @pageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String pageCount(int count);

  /// No description provided for @pageProgress.
  ///
  /// In en, this message translates to:
  /// **'Page {current} / {total}'**
  String pageProgress(int current, int total);

  /// Compact page counter in the reader chrome
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String pageCounter(int current, int total);

  /// Page counter for a landscape two-page spread
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} / {total}'**
  String pageSpreadCounter(int first, int last, int total);

  /// Tooltip on the reader's top-bar cog, which opens the reading direction and the drag-to-magnify switch.
  ///
  /// In en, this message translates to:
  /// **'Reader settings'**
  String get readerSettings;

  /// Reader setting: a one-finger drag magnifies the page instead of turning it.
  ///
  /// In en, this message translates to:
  /// **'Drag to magnify'**
  String get dragToMagnify;

  /// Replaces dragToMagnifyExplained in the reader's sheet when the current reading direction is vertical scrolling, where the gesture is deliberately inert.
  ///
  /// In en, this message translates to:
  /// **'Not while reading vertically — there the drag scrolls the chapter.'**
  String get dragToMagnifyInVertical;

  /// Explains what turning the drag-to-magnify setting on changes, including what it costs: the swipe that turns a page.
  ///
  /// In en, this message translates to:
  /// **'One finger magnifies the page around the point you press, and how far you drag decides how much. Pages turn by tapping the sides.'**
  String get dragToMagnifyExplained;

  /// Title of the reader menu that picks how pages advance
  ///
  /// In en, this message translates to:
  /// **'Reading direction'**
  String get readingDirection;

  /// Full phrase, never an acronym like LTR
  ///
  /// In en, this message translates to:
  /// **'Left to right'**
  String get readingDirectionLtr;

  /// Full phrase, never an acronym like RTL; the manga direction
  ///
  /// In en, this message translates to:
  /// **'Right to left'**
  String get readingDirectionRtl;

  /// Continuous vertical scrolling direction, sits next to the two page-turning ones; the one word is enough on screen, it is the only vertical direction in the picker
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get readingDirectionVerticalScroll;

  /// Download action on a chapter; always worded, never icon-only
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savePill;

  /// Download in progress; tapping cancels
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String downloadingPct(int percent);

  /// Chapter is available offline; tapping removes it
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedPill;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// No description provided for @emptyDownloads.
  ///
  /// In en, this message translates to:
  /// **'No saved chapters yet. Save a chapter from a series to read it without the server.'**
  String get emptyDownloads;

  /// Storage meter caption; size is a preformatted string such as '124 MB'
  ///
  /// In en, this message translates to:
  /// **'{size} on this device'**
  String storageUsed(String size);

  /// Swipe action on a chapter or volume row that marks it read on the server
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markRead;

  /// Swipe action that undoes markRead, shown on a row already read
  ///
  /// In en, this message translates to:
  /// **'Mark unread'**
  String get markUnread;

  /// No description provided for @removeDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeDownload;

  /// No description provided for @removeDownloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the saved copy of {title}?'**
  String removeDownloadConfirm(String title);

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get serverUnreachable;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable — offline mode. Saved chapters remain readable.'**
  String get offlineBanner;

  /// No description provided for @storageSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageSectionLabel;

  /// No description provided for @imageCacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Image cache'**
  String get imageCacheLabel;

  /// No description provided for @imageCacheCaption.
  ///
  /// In en, this message translates to:
  /// **'Covers and pages read online. Clearing it never touches saved chapters.'**
  String get imageCacheCaption;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @imageCacheLimit.
  ///
  /// In en, this message translates to:
  /// **'Cache limit'**
  String get imageCacheLimit;

  /// No description provided for @imageCacheLimitCaption.
  ///
  /// In en, this message translates to:
  /// **'Once full, the oldest images are removed first.'**
  String get imageCacheLimitCaption;

  /// No description provided for @downloadedChapters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No saved chapter} =1{1 saved chapter} other{{count} saved chapters}}'**
  String downloadedChapters(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @serverSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverSectionLabel;

  /// No description provided for @switchServer.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get switchServer;

  /// Accessible label for the reachability dot on the settings server card
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get serverOnline;

  /// Shown beside the username, and as the dot's label, when the server cannot be reached
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get serverOffline;

  /// The dot's label while the reachability probe is still in flight
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get serverChecking;

  /// No description provided for @generalSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSectionLabel;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get appLanguage;

  /// The default option in Settings > Language: follow whatever language the device is set to. The other options are each named in their own language and are never translated.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appLanguageSystem;

  /// No description provided for @readingSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get readingSectionLabel;

  /// No description provided for @defaultReadingDirection.
  ///
  /// In en, this message translates to:
  /// **'Default reading direction'**
  String get defaultReadingDirection;

  /// No description provided for @aboutSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSectionLabel;

  /// Under the wordmark in Settings > About. Read off the binary rather than compiled in: CI passes the release tag to --build-name, so this is the version that shipped.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @sizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{count} B'**
  String sizeBytes(int count);

  /// No description provided for @sizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{count} MB'**
  String sizeMegabytes(String count);

  /// No description provided for @sizeGigabytes.
  ///
  /// In en, this message translates to:
  /// **'{count} GB'**
  String sizeGigabytes(String count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
