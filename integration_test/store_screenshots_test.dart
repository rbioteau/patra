/// Photographs the screens the two store listings show, on a device.
///
/// Run it through `tool/store_screenshots.sh`, never by hand: the script
/// clears the app's data first — the run has to start from the sign-in form,
/// or "the first chapter" is whichever one was last read — sizes the screen to
/// the ratio the stores ask for, and flattens what comes out. It goes through
/// `flutter drive`, because the half that *takes* a screenshot is here and the
/// half with a disk is `test_driver/store_screenshots.dart`.
///
/// **A recipe, not a test.** It asserts almost nothing: it walks the app the
/// way a person would and photographs what it finds. What makes it worth
/// committing is that it *makes* the state it photographs rather than assuming
/// it — signs in from nothing, forces the language, marks a chapter read so
/// "Continue" has somewhere to continue, waits for a copy to land before
/// shooting the offline screen. A screenshot of whatever the library happened
/// to be holding that afternoon is not a store asset.
///
/// It finds its way by **icon and by type, never by a hardcoded label**: the
/// sign-in form is answered before any language has been forced, so it is
/// found positionally; the tabs are found by their icons, which are the one
/// thing about them a language cannot move. The few labels that are genuinely
/// needed are read out of the app's own `AppLocalizations` — the same strings
/// the screens draw — so this file is never the second place a translation has
/// to change.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/l10n/generated/app_localizations_en.dart';
import 'package:patra/l10n/generated/app_localizations_fr.dart';
import 'package:patra/main.dart' as app;
import 'package:patra/src/settings/locale_settings.dart';
import 'package:patra/src/widgets/download_pill.dart';

/// What the script passes in. Credentials arrive as `--dart-define` and are
/// never written to a file, the same way `tool/measure_page_shapes.dart` takes
/// its server on the command line.
const _server = String.fromEnvironment('KAVITA_URL');
const _user = String.fromEnvironment('KAVITA_USER');
const _password = String.fromEnvironment('KAVITA_PASSWORD');
const _locale = String.fromEnvironment('PATRA_LOCALE', defaultValue: 'en');

/// How long a network step gets before the recipe gives up on it. Generous:
/// this runs against a real server, and a first-page fetch on a cold cache is
/// the slowest thing in the app.
const _deadline = Duration(seconds: 90);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the screens the store listings show', (tester) async {
    expect(
      _server,
      isNotEmpty,
      reason: 'KAVITA_URL is unset — run tool/store_screenshots.sh.',
    );

    // Android has to be told to draw into an image view before anything is
    // captured; iOS and the desktop hosts are already a surface of their own.
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }

    await app.main();
    await tester.pumpAndSettle();

    await _signIn(tester);
    await _forceLocale(tester);

    // One language is in force from here on, so the app's own strings are what
    // the screens are drawing.
    final l10n = _strings();

    // 1 — the shelf: Continue over what is being read, On deck, the libraries.
    await _tab(tester, Icons.home_outlined);
    await _shoot(binding, '1-home');

    // 2 — who is reading. The picker is not a screen a fresh device shows: it
    // is reached the way a person reaches it, from the face on the home bar,
    // which is also the only way there is.
    await tester.tap(find.byIcon(Icons.face_outlined));
    await tester.pumpAndSettle();
    await _shoot(binding, '2-profiles');
    await tester.tap(find.byIcon(Icons.face_outlined));
    await tester.pumpAndSettle();

    // 3 — a series, with something read and something saved so the screen is
    // not an empty catalogue.
    await _openFirstSeries(tester, l10n);
    await _shoot(binding, '3-series');

    // 4 — the page itself, with nothing over it.
    await _openReader(tester, l10n);
    await _shoot(binding, '4-reader');
    await _leaveReader(tester);

    // 5 — what is on the device.
    await _tab(tester, Icons.download_outlined);
    await _shoot(binding, '5-downloads');
  });
}

/// The strings the app will draw, read off its own localizations.
///
/// Not written here: a label spelled out in this file would be a second place
/// to change when one is reworded, and the second place is always the one that
/// goes stale.
AppLocalizations _strings() => switch (_locale) {
  'fr' => AppLocalizationsFr(),
  _ => AppLocalizationsEn(),
};

/// Signs in from an app that has never run.
///
/// Positional, and deliberately: this is the one screen reached before the
/// language has been forced, so a text finder here would be a finder in
/// whatever language the device happens to be in. The three fields are the
/// server, the username and the password, in that order, and there are three
/// of them only because the script cleared the app's data — the server field
/// is not drawn once one is remembered.
Future<void> _signIn(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  expect(
    fields,
    findsNWidgets(3),
    reason: 'the run must start from cleared app data (tool/store_screenshots.sh clears it)',
  );

  await tester.enterText(fields.at(0), _server);
  await tester.enterText(fields.at(1), _user);
  await tester.enterText(fields.at(2), _password);
  await tester.pumpAndSettle();

  await tester.tap(find.byType(FilledButton));
  await _waitFor(tester, find.byType(NavigationBar), 'the app to open');
}

/// Forces the language, so one run serves both listings.
///
/// Found by icon throughout — the Settings tab, then the row that opens the
/// sheet — because the labels on the way there are in the language being
/// replaced. The endonym is the one string that is the same in every language,
/// which is the whole reason a language is listed under its own name.
Future<void> _forceLocale(WidgetTester tester) async {
  await _tab(tester, Icons.tune_outlined);
  await tester.tap(find.byIcon(Icons.language));
  await tester.pumpAndSettle();
  await tester.tap(find.text(languageEndonym(Locale(_locale))));
  await tester.pumpAndSettle();
}

/// Library → the first cover → a series, then made worth photographing: one
/// chapter read, so "Continue" names a chapter, and one copy saved, so the
/// offline screens are not empty.
Future<void> _openFirstSeries(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await _tab(tester, Icons.grid_view_outlined);
  await tester.tap(
    find
        .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
        .first,
  );
  await tester.pumpAndSettle();

  // The row's leading edge is progress, and the swipe is the app's own way of
  // marking a chapter read.
  await tester.drag(find.byType(Slidable).first, const Offset(160, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.markRead));
  await tester.pumpAndSettle();

  // And one copy on the device, for the screen after this one.
  await tester.tap(find.byType(DownloadPill).first);
  await tester.pumpAndSettle();
  await _waitFor(tester, find.text(l10n.savedPill), 'a saved copy');
}

/// Opens the reader, and dismisses its chrome: what a listing shows is the
/// page, not the controls over it.
Future<void> _openReader(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.byType(Slidable).first);
  await tester.pumpAndSettle();

  // The middle of the page toggles the chrome off. Tapping the sides would
  // turn a page instead — which is the reader working, but not the shot.
  final centre = tester.getCenter(find.byType(Scaffold).last);
  await tester.tapAt(centre);
  await tester.pumpAndSettle();
}

/// Puts the chrome back and closes the reader, so the shell is reachable
/// again: `/reader` is declared outside it, which is the whole point of it.
Future<void> _leaveReader(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.arrow_back).first);
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// A destination of the shell, by icon: the one thing about it a language
/// cannot move. The label may not even be drawn — the bar falls back to icons
/// when the labels do not fit — but the icon is always there.
Future<void> _tab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

/// Takes one screenshot and hands the bytes to the driver, which is the half
/// that owns a filesystem.
///
/// The name is the file name, numeric prefix included: the stores show the
/// screenshots in upload order, and the prefix is what keeps that order
/// visible in a directory listing.
Future<void> _shoot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.takeScreenshot(name);
}

/// Pumps until [finder] finds something, or gives up loudly.
///
/// `pumpAndSettle` cannot wait for a network: it waits for frames to stop, and
/// a download in flight has no frames left to schedule. So the wait is on the
/// thing itself, with a clock.
Future<void> _waitFor(WidgetTester tester, Finder finder, String what) async {
  final deadline = DateTime.now().add(_deadline);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('$what did not arrive within ${_deadline.inSeconds}s');
}
