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

  /// Reassurance note pinned to the bottom of the sign-in screen. Says sign-in and not token on purpose: the JWT is never written down, and what the keychain holds is the account auth key (ADR-0004)
  ///
  /// In en, this message translates to:
  /// **'Requires a Kavita server v0.9+ · Sign-in kept in secure storage'**
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

  /// No description provided for @connectionBlockedByBrowser.
  ///
  /// In en, this message translates to:
  /// **'The browser blocked Patra\'s request to {host}. Either nothing is answering there, or the server does not allow requests from this page — Kavita has to be configured to, usually in the reverse proxy in front of it.'**
  String connectionBlockedByBrowser(String host);

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

  /// Shown when opening a remembered profile fails because the stored auth key was refused. Named by person and host, because a server can hold several profiles and only one of them was refused. Deliberately not the bad-credentials message: no password was sent, so nothing the person typed was rejected
  ///
  /// In en, this message translates to:
  /// **'The saved sign-in for {name} on {host} was refused. Your password is needed again.'**
  String connectionSignInExpired(String name, String host);

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

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add a profile'**
  String get addProfile;

  /// Heading over the profile picker
  ///
  /// In en, this message translates to:
  /// **'Who is reading?'**
  String get whoIsReading;

  /// Reveals the address field when the device knows one server and the account being added is on another
  ///
  /// In en, this message translates to:
  /// **'Use another server'**
  String get useAnotherServer;

  /// Leaves the sign-in form for the list of remembered profiles
  ///
  /// In en, this message translates to:
  /// **'Back to your profiles'**
  String get backToProfiles;

  /// No description provided for @forgetProfile.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forgetProfile;

  /// Settings button that removes the profile the app is currently read as, credential and all
  ///
  /// In en, this message translates to:
  /// **'Forget this profile'**
  String get forgetThisProfile;

  /// Confirmation title; name is the profile's username and host a host name. Both, because a server can hold several profiles and one of them is being removed
  ///
  /// In en, this message translates to:
  /// **'Forget {name} on {host}?'**
  String forgetProfileConfirm(String name, String host);

  /// Second line of the confirmation for removing a profile, naming the saved reading that goes with it. Nothing can reach those files once the profile is gone, so what is about to be deleted has to be said before it is
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved chapter ({size}) will be deleted too.} other{{count} saved chapters ({size}) will be deleted too.}}'**
  String forgetProfileDownloads(int count, String size);

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

  /// Shown to somebody who is not an administrator, and so has no way to ask for a scan from here: Kavita is still the only route, so the sentence keeps pointing at it
  ///
  /// In en, this message translates to:
  /// **'Patra shows what your server has scanned. Add files to {library} on the server, then scan it from Kavita.'**
  String libraryEmptyBody(String library);

  /// Shown to an administrator, who has the button right below: sending them to Kavita for something they can do here would be wrong
  ///
  /// In en, this message translates to:
  /// **'Patra shows what your server has scanned. Add files to {library} on the server, then ask for a scan.'**
  String libraryEmptyBodyAdmin(String library);

  /// Tooltip of the Library tab's app bar menu. Only drawn for an administrator, and only once a library is selected
  ///
  /// In en, this message translates to:
  /// **'Library actions'**
  String get libraryActions;

  /// Only shown to a Kavita administrator: every scan endpoint is behind AdminPolicy. Worded, never an icon: a refresh glyph would be confused with the pull-to-refresh on the same screen, which asks Kavita what it already knows
  ///
  /// In en, this message translates to:
  /// **'Ask server to scan'**
  String get askServerToScan;

  /// Why the scan menu item is disabled offline. Disabled with its reason rather than hidden, so it cannot be mistaken for having lost the admin role
  ///
  /// In en, this message translates to:
  /// **'Needs the server — offline'**
  String get scanNeedsServer;

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

  /// Shown in place of a page of a book the server could not produce
  ///
  /// In en, this message translates to:
  /// **'This page could not be loaded.'**
  String get bookPageUnavailable;

  /// A book's table of contents: the label on the control in the reader's bottom chrome that opens it, and the heading of the sheet it opens.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get bookContents;

  /// Pages remaining in the chapter the home hero would resume
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page left} other{{count} pages left}}'**
  String homeHeroPagesLeft(int count);

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

  /// A finished row's metadata line, drawn in the accent. The word is part of the sentence rather than a tag beside the title, so a translation is free to order it its own way
  ///
  /// In en, this message translates to:
  /// **'Read · {count} pages'**
  String readPageCount(int count);

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

  /// Tooltip on the reader's top-bar cog, which opens what there is to choose about what is being read: the reading direction for a chapter of pictures, the text size and the line spacing for a book.
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

  /// Reader setting: how wide pages are drawn while reading vertically, as a percentage of the screen's width.
  ///
  /// In en, this message translates to:
  /// **'Page width'**
  String get pageWidth;

  /// Explains what the page width setting changes, and says where it applies.
  ///
  /// In en, this message translates to:
  /// **'How wide pages are drawn while reading vertically. 100% is the whole screen.'**
  String get pageWidthExplained;

  /// Replaces pageWidthExplained in the reader's sheet when the chapter is being paged, where no strip is laid out at a width of its own.
  ///
  /// In en, this message translates to:
  /// **'Not while paging — there a page is fitted to the screen.'**
  String get pageWidthInPaged;

  /// Reader setting: how large the words of a book are set. Offered for a book, where the sheet offers no reading direction.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get bookTextSize;

  /// Explains what the text size setting changes, and says where it applies.
  ///
  /// In en, this message translates to:
  /// **'How large the words of a book are. Every book is set at this size.'**
  String get bookTextSizeExplained;

  /// A size of type, in points — the value the text size setting is shown at.
  ///
  /// In en, this message translates to:
  /// **'{size} pt'**
  String textSizePoints(int size);

  /// Reader setting: the room between a book's lines, as a share of the size of its words.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get bookLineSpacing;

  /// Explains what the line spacing setting changes, and says where it applies.
  ///
  /// In en, this message translates to:
  /// **'The room between a book\'s lines, as a share of the size of the words.'**
  String get bookLineSpacingExplained;

  /// Reader setting: the typeface a book's words are set in. Offered for a book, beside its text size and line spacing.
  ///
  /// In en, this message translates to:
  /// **'Reading face'**
  String get bookReadingFace;

  /// Explains what the reading face setting changes, and says where it applies.
  ///
  /// In en, this message translates to:
  /// **'The face a book is set in. Every book is set in this face.'**
  String get bookReadingFaceExplained;

  /// The name of a typeface the app ships. A proper noun, never translated.
  ///
  /// In en, this message translates to:
  /// **'Space Grotesk'**
  String get readingFaceSpaceGrotesk;

  /// The name of a typeface the app ships. A proper noun, never translated.
  ///
  /// In en, this message translates to:
  /// **'Source Serif 4'**
  String get readingFaceSourceSerif4;

  /// The name of a typeface the app ships. A proper noun, never translated.
  ///
  /// In en, this message translates to:
  /// **'Literata'**
  String get readingFaceLiterata;

  /// The name of a typeface the app ships. A proper noun, never translated.
  ///
  /// In en, this message translates to:
  /// **'Atkinson Hyperlegible Next'**
  String get readingFaceAtkinsonHyperlegibleNext;

  /// A value shown as a percentage of the whole.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percent(int value);

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

  /// In the reader's sheet: the reading direction in force is one chosen for this one series alone.
  ///
  /// In en, this message translates to:
  /// **'{direction} — chosen for this series'**
  String directionSourceSeries(String direction);

  /// In the reader's sheet: the reading direction in force was worked out from the work itself rather than chosen by anybody; a guess is not a choice, so this is said out loud.
  ///
  /// In en, this message translates to:
  /// **'{direction} — detected from the work'**
  String directionSourceDetected(String direction);

  /// In the reader's sheet: the reading direction in force is the one a chapter opens in having never been given another — nothing was chosen for this series or its library, and nothing was detected either. Worded neutrally, because it is nobody's choice.
  ///
  /// In en, this message translates to:
  /// **'{direction} — the default'**
  String directionSourceBuiltIn(String direction);

  /// In the reader's sheet: the reading direction in force is one chosen for every series in this library. {library} is the library's own name, as the server words it.
  ///
  /// In en, this message translates to:
  /// **'{direction} — the default for {library}'**
  String directionSourceLibrary(String direction, String library);

  /// Reader action: makes the reading direction in force the one every series in this library opens in, so a shelf the guess gets wrong is put right in one tap. {library} is the library's own name, as the server words it; drawn only where it is not already that library's.
  ///
  /// In en, this message translates to:
  /// **'Make this the default for {library}'**
  String promoteLibraryDirection(String library);

  /// Reader action: drops the direction chosen for this series, which then follows the default again. The direction it lands on is shown beside the row; worded 'the default' rather than 'my default' because it may be a detected one.
  ///
  /// In en, this message translates to:
  /// **'Follow the default'**
  String get followDefaultDirection;

  /// Reader action: drops the direction chosen for a whole library, whose series then follow what stands below it again. The direction the chapter lands on is shown beside the row. {library} is the library's own name, as the server words it.
  ///
  /// In en, this message translates to:
  /// **'Follow the default for {library}'**
  String followDefaultDirectionForLibrary(String library);

  /// Stands in for a library's name where the server's list has not reached the device yet, in the reader's rows that name a library.
  ///
  /// In en, this message translates to:
  /// **'this library'**
  String get thisLibrary;

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

  /// Downloads row for a saved copy the server no longer counts the same number of pages for; count is what the server says now, as against the number the copy was made with. The copy is still readable — this is the mark a refresh is offered against (ADR-0009)
  ///
  /// In en, this message translates to:
  /// **'Out of date — the server now counts {count, plural, =1{1 page} other{{count} pages}}'**
  String copyOutOfDate(int count);

  /// Button on an out-of-date saved copy: stores it again, with the pages the server counts now
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshCopy;

  /// What the refresh button becomes while the copy is being stored again
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get refreshingCopy;

  /// Downloads tab section heading over the copies still being fetched
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadsQueueSection;

  /// Downloads tab section heading over copies that failed or stopped with the app, which stay listed until they are retried
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get downloadsPendingSection;

  /// One line answering where a batch has got to: how many of its copies are on the device, and how far through the pages of the whole batch the work is. The percentage is over pages, not copies, which is why it can move without the count in front of it.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} · {percent}%'**
  String downloadsBatchSummary(int done, int total, int percent);

  /// What a queued copy says instead of a percentage: it has pages to fetch and none fetched yet, so there is nothing to count
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get downloadsWaiting;

  /// What a copy the app was closed in the middle of says: it keeps the pages it had, and a retry fetches only what is missing
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get downloadsStoppedShort;

  /// What a copy whose fetch was refused or failed says, beside its Retry control
  ///
  /// In en, this message translates to:
  /// **'Could not finish'**
  String get downloadsFailed;

  /// What a copy the app deliberately stopped says — it left the foreground, or the reader left their profile. It keeps the pages it has and goes on by itself when the app, or the profile, comes back
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadsPaused;

  /// Control on a paused copy that sends it on again from the pages it kept; also the answer that resumes everything a cold start found stopped
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeDownload;

  /// The one question a cold start asks, in a strip across the app rather than a dialog: how many copies the previous run was closed in the middle of. Nothing is fetched until it is answered, and each copy keeps the pages it already has
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One download stopped when the app closed.} other{{count} downloads stopped when the app closed.}}'**
  String resumeDownloadsBody(int count);

  /// Dismisses the cold-start question: what was paused stops being resumable and waits for a retry, so nothing is fetched behind the reader's back
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get resumeDownloadsLater;

  /// Tooltip of the cancel control on one in-flight copy in the Downloads tab; worded with the title because the row carries no room for the word, and a glyph says nothing to a screen reader
  ///
  /// In en, this message translates to:
  /// **'Cancel {title}'**
  String cancelDownload(String title);

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

  /// Home's empty state offline, when the device holds saved chapters. Deliberately NOT the offlineBanner sentence: that one belongs to the indicator in the app bar and must not reappear over content (test/offline_indicator_test.dart). This is an empty state — Home has nothing to draw at all — pointing at the one tab that does.
  ///
  /// In en, this message translates to:
  /// **'The server is out of reach. What you saved is still here.'**
  String get homeOfflineWithSaved;

  /// Home's empty state offline when there is nothing saved either, so there is nowhere to send the reader
  ///
  /// In en, this message translates to:
  /// **'The server is out of reach, and nothing is saved on this device yet.'**
  String get homeOfflineNothingSaved;

  /// Button on Home's offline empty state, opening the Downloads tab
  ///
  /// In en, this message translates to:
  /// **'See your downloads'**
  String get seeDownloads;

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

  /// Settings section heading over the remembered profiles that are not the one being read as; each can be removed without being signed into
  ///
  /// In en, this message translates to:
  /// **'Other profiles on this device'**
  String get otherProfilesSectionLabel;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get switchProfile;

  /// Title of the settings row that gives the active profile a PIN
  ///
  /// In en, this message translates to:
  /// **'Lock this profile'**
  String get profileLock;

  /// What turning the profile lock on does, and the one thing it must never be taken to mean. The auth key each profile keeps is a whole Kavita account and only its owner can rotate it (ADR-0004), so the second sentence is not modesty — it is the fact
  ///
  /// In en, this message translates to:
  /// **'A PIN keeps the people you share this device with out of your profile. It is not protection for a lost or stolen device: what is stored here can still be read off one.'**
  String get profileLockExplained;

  /// Shown under the lock row only for a profile the server puts no age restriction on, or an administrator. A restricted profile is never told this: the server already holds it back, and a lock on it would protect nothing (ADR-0003)
  ///
  /// In en, this message translates to:
  /// **'Worth doing on a shared device: nothing on the server holds this profile back from anything.'**
  String get profileLockSuggested;

  /// No description provided for @profileLockChange.
  ///
  /// In en, this message translates to:
  /// **'Change the PIN'**
  String get profileLockChange;

  /// Heading of the sheet that sets a profile's PIN
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get profileLockChoose;

  /// Heading of the second step of setting a PIN
  ///
  /// In en, this message translates to:
  /// **'Enter it again'**
  String get profileLockRepeat;

  /// No description provided for @profileLockMismatch.
  ///
  /// In en, this message translates to:
  /// **'Those two PINs are different.'**
  String get profileLockMismatch;

  /// Heading of the sheet asking for a locked profile's PIN before it is entered
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN for {name}'**
  String profileLockEnterFor(String name);

  /// No description provided for @profileLockWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN.'**
  String get profileLockWrong;

  /// Button that asks the device to recognise its owner instead. Worded for neither a face nor a fingerprint: which one the device offers is not knowable from here
  ///
  /// In en, this message translates to:
  /// **'Unlock without the PIN'**
  String get profileLockUseBiometrics;

  /// What the operating system's own biometric prompt says it is for
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}\'s profile'**
  String profileLockBiometricReason(String name);

  /// No description provided for @profileLockBackspace.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileLockBackspace;

  /// Said under a face on the picker, so the cost of tapping it is known before it is tapped
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get profileLockedBadge;

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

  /// On the settings server card, after the username. The server names itself because the About section on the same screen prints Patra's own version, and a bare number under a hostname could be either. Verbatim, four dot-separated integers and no 'v' prefix: Kavita's own admin screen prints the same string unmodified, and this number's job is to be read back into a bug report.
  ///
  /// In en, this message translates to:
  /// **'Kavita {version}'**
  String serverVersion(String version);

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

  /// The row under Settings > About that opens what the app ships under: its own bundled faces, and every package it is built from. Spelled the way the page it opens titles itself, because that title is one tap away and two spellings of one word read as a mistake.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licensesTitle;

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

  /// Batch card title when there is something to fetch. No number: how many is a setting (batchDownloadSize), and the subtitle names the range instead
  ///
  /// In en, this message translates to:
  /// **'Download what\'s next'**
  String get batchDownload;

  /// A run of whole volumes on the batch card, the unit said once; from and to are Kavita's volume numbers
  ///
  /// In en, this message translates to:
  /// **'Volumes {from} to {to}'**
  String volumeRangeLabel(String from, String to);

  /// A run of numbered chapters on the batch card, in a manga or image library
  ///
  /// In en, this message translates to:
  /// **'Chapters {from} to {to}'**
  String chapterRangeLabel(String from, String to);

  /// A run of issues on the batch card, in a comic library
  ///
  /// In en, this message translates to:
  /// **'Issues #{from} to #{to}'**
  String issueRangeLabel(String from, String to);

  /// A run of books on the batch card, in a book or light novel library
  ///
  /// In en, this message translates to:
  /// **'Books {from} to {to}'**
  String bookRangeLabel(String from, String to);

  /// Caption under the batch download size row in Settings › Storage
  ///
  /// In en, this message translates to:
  /// **'How many unread chapters one tap on a series saves, from where you are, across volumes.'**
  String get batchDownloadSizeCaption;

  /// SnackBar shown once per device, on the first tap of the batch card, with an action leading to Settings; count is the batch size in force
  ///
  /// In en, this message translates to:
  /// **'Downloading the next {count}. That number is yours to choose in Settings › Storage.'**
  String batchSizeHint(int count);

  /// Button on a volume section header to enqueue all unread chapters in that volume
  ///
  /// In en, this message translates to:
  /// **'Download remaining'**
  String get batchDownloadVolume;

  /// Settings label for choosing how many unread chapters to include in a batch download
  ///
  /// In en, this message translates to:
  /// **'Batch download size'**
  String get batchDownloadSize;

  /// Option in the batch download size picker; count is 3, 5, 10, or 20
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String batchDownloadSizeOption(int count);

  /// Header of the list under the series hero, over whatever that series turns out to hold — volumes, chapters, specials. Deliberately not the library's unit: the list heads its own sections, and a unit would name only one of the kinds of row under it. The sort control hangs off this row
  ///
  /// In en, this message translates to:
  /// **'In this series'**
  String get inThisSeries;

  /// Header of the sheet the sort control on the series screen opens, over the three orders it offers
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortSheetTitle;

  /// Tooltip and screen-reader label of the sort control on the series screen, naming the order in force. The control itself is an icon, so this is the only place its name is said
  ///
  /// In en, this message translates to:
  /// **'Sort: {order}'**
  String sortTooltip(String order);

  /// An order in the sort sheet on the series screen: the chapter under way first, then what comes next, with everything already read folded away at the bottom. The default
  ///
  /// In en, this message translates to:
  /// **'Reading position'**
  String get sortReadingPosition;

  /// The rule behind Reading position, in one line, under its name in the sort sheet
  ///
  /// In en, this message translates to:
  /// **'Where you are first, then what comes next'**
  String get sortReadingPositionHint;

  /// An order in the sort sheet on the series screen: the sections in reverse reading order, highest number first
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// The rule behind Newest, under its name in the sort sheet
  ///
  /// In en, this message translates to:
  /// **'Latest first'**
  String get sortNewestHint;

  /// An order in the sort sheet on the series screen: the sections in reading order, from the beginning
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get sortOldest;

  /// The rule behind Oldest, under its name in the sort sheet
  ///
  /// In en, this message translates to:
  /// **'From the beginning'**
  String get sortOldestHint;

  /// Group header over the one chapter under way, in the reading-position view. Drawn in the accent, since it is about reading progress
  ///
  /// In en, this message translates to:
  /// **'Reading now'**
  String get groupReadingNow;

  /// Group header over the unread chapters that follow, in the reading-position view, once the series has been started
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get groupUpNext;

  /// Group header over the unread chapters when nothing in the series has been read yet
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get groupStartHere;

  /// Group header over the finished chapters, folded away by default; count is how many there are
  ///
  /// In en, this message translates to:
  /// **'Already read · {count}'**
  String groupAlreadyRead(int count);

  /// Control on the Already read header that unfolds the finished chapters
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get showReadChapters;

  /// Control on the Already read header that folds the finished chapters away again
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideReadChapters;

  /// Batch card title while at least one of the next N unread chapters is being fetched; count is how many the batch covers
  ///
  /// In en, this message translates to:
  /// **'Downloading next {count}…'**
  String batchDownloading(int count);

  /// Batch card subtitle while it runs: how many of the batch are already on the device
  ///
  /// In en, this message translates to:
  /// **'{done} of {count} saved'**
  String batchDownloadingProgress(int done, int count);

  /// Batch card title once every one of the next N unread chapters is on the device
  ///
  /// In en, this message translates to:
  /// **'Next {count} saved'**
  String batchAllSaved(int count);

  /// Batch card subtitle once the whole batch is saved
  ///
  /// In en, this message translates to:
  /// **'Ready to read offline'**
  String get batchReadyOffline;

  /// Appended to the batch card subtitle when part of the batch is already on the device — which is what the card looks like after one of a saved batch has been finished and the window has moved on by one
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 already saved} other{{count} already saved}}'**
  String batchAlreadySaved(int count);
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
