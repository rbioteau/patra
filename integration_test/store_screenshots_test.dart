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
import 'package:patra/src/widgets/profile_avatar.dart';

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
      await _beat(tester);
    }

    await app.main();
    await _beat(tester);

    await _signIn(tester);
    await _forceLocale(tester);

    // One language is in force from here on, so the app's own strings are what
    // the screens are drawing.
    final l10n = _strings();

    // 1 — the shelf: Continue over what is being read, On deck, the libraries.
    await _tab(tester, 0); // Home
    await _shoot(binding, '1-home');

    // 2 — who is reading. The picker is not a screen a fresh device shows: it
    // is reached the way a person reaches it, from the face on the home bar —
    // which is a `ProfileAvatar` in an `IconButton`, and not one of Material's
    // face icons, which is what the first run of this recipe guessed and spent
    // a run learning.
    final face = find.byType(ProfileAvatar);
    await tester.tap(face.first);
    // The picker is a screen *outside* the shell — that is what it is for —
    // so the bottom bar going away is what says it arrived, and it needs no
    // word from any language to say so.
    await _waitGone(tester, find.byType(NavigationBar), 'the picker');
    await _shoot(binding, '2-profiles');
    await tester.tap(face.first);
    await _waitFor(tester, find.byType(NavigationBar), 'home again');

    // 3 — a series, with something read and something saved so the screen is
    // not an empty catalogue.
    await _openFirstSeries(tester, l10n);
    await _shoot(binding, '3-series');

    // 4 — the page itself, with nothing over it.
    await _openReader(tester, l10n);
    await _shoot(binding, '4-reader');
    await _leaveReader(tester);

    // 5 — what is on the device.
    await _tab(tester, 2); // Downloads
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

  // Waited for and not assumed: a cold start has a keychain to read and a
  // splash to fade, and the first run of this recipe failed on exactly that —
  // asserting at the wrong moment says "no form", which reads like a wrong
  // screen rather than a wrong clock. `_waitFor` prints what is on screen when
  // it gives up, which is the difference between one run and two.
  await _waitFor(tester, fields.first, 'the sign-in form');

  expect(
    fields,
    findsNWidgets(3),
    reason: 'server, username and password, in that order',
  );

  await tester.enterText(fields.at(0), _server);
  await tester.enterText(fields.at(1), _user);
  await tester.enterText(fields.at(2), _password);
  await _beat(tester);

  // Submitted through the keyboard's "done", which is the password field's own
  // `onFieldSubmitted` — the app's path, and the only one that works on a
  // phone: entering text raises the soft keyboard, the keyboard covers the
  // button, and a tap aimed at it lands on whatever the form has behind it.
  // The first run of this recipe failed exactly there, with the hit test
  // reporting the masthead's tagline under the tap.
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _beat(tester);

  // The keyboard is put away before anything else is tapped. It is raised by
  // the text entry and it sits over the bottom of the screen, which is where
  // the shell keeps its destinations: a tap still finds them in the tree and
  // still misses them on the glass.
  FocusManager.instance.primaryFocus?.unfocus();
  await _beat(tester, const Duration(milliseconds: 600));

  await _waitFor(tester, find.byType(NavigationBar), 'the app to open');
}

/// Forces the language, so one run serves both listings.
///
/// Found by icon throughout — the Settings tab, then the row that opens the
/// sheet — because the labels on the way there are in the language being
/// replaced. The endonym is the one string that is the same in every language,
/// which is the whole reason a language is listed under its own name.
Future<void> _forceLocale(WidgetTester tester) async {
  await _tab(tester, 3); // Settings
  await _waitFor(tester, find.byIcon(Icons.language), 'the language row');
  await tester.tap(find.byIcon(Icons.language));
  final endonym = find.text(languageEndonym(Locale(_locale)));
  await _waitFor(tester, endonym, 'the language sheet');
  await tester.tap(endonym);
  await _waitFor(tester, find.byIcon(Icons.language), 'the sheet to close');
}

/// Library → the first cover → a series, then made worth photographing: one
/// chapter read, so "Continue" names a chapter, and one copy saved, so the
/// offline screens are not empty.
Future<void> _openFirstSeries(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await _tab(tester, 1); // Library
  final cover = find
      .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
      .first;
  await _waitFor(tester, cover, 'the library grid');
  await tester.tap(cover);
  await _waitFor(tester, find.byType(Slidable), 'the series screen');

  // The row's leading edge is progress, and the swipe is the app's own way of
  // marking a chapter read.
  await tester.drag(find.byType(Slidable).first, const Offset(160, 0));
  await _waitFor(tester, find.text(l10n.markRead), 'the mark-read pane');
  await tester.tap(find.text(l10n.markRead));
  await _beat(tester);

  // And one copy on the device, for the screen after this one. Found by icon,
  // both to tap it and to wait for it: an unsaved row's pill is `save_alt`,
  // and a saved one is a **check inside a circle** — the word "Saved" is only
  // its tooltip, so the first version of this recipe waited for a text that is
  // never drawn and waited forever.
  await tester.tap(find.byIcon(Icons.save_alt).first);
  await _beat(tester);
  await _waitFor(tester, find.byIcon(Icons.check), 'a saved copy');
}

/// Opens the reader, and dismisses its chrome: what a listing shows is the
/// page, not the controls over it.
Future<void> _openReader(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.byType(Slidable).first);
  await _waitFor(tester, find.byType(PageView), 'the reader');

  // The middle of the page toggles the chrome off. Tapping the sides would
  // turn a page instead — which is the reader working, but not the shot.
  final centre = tester.getCenter(find.byType(Scaffold).last);
  await tester.tapAt(centre);
  await _beat(tester);
}

/// Puts the chrome back and closes the reader, so the shell is reachable
/// again: `/reader` is declared outside it, which is the whole point of it.
Future<void> _leaveReader(WidgetTester tester) async {
  // The chrome back first, and waited for: it is only drawn while the controls
  // are up, which is the state the reader was just put back into.
  await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
  final back = find.byIcon(Icons.arrow_back);
  await _waitFor(tester, back, 'the reader chrome');
  await tester.tap(back.first);
  await _waitFor(tester, find.byType(Slidable), 'the series screen again');
}

/// A destination of the shell, by where it sits in the bar.
///
/// Not by its icon, and not by its label. The label is a word, and the bar
/// hides the words entirely when they do not fit the width — French at a large
/// system font does exactly that — so half the destinations have no text to
/// find. The icon is always drawn, but a tap aimed at an `Icon` is one the
/// framework may refuse: it hit-tests the *widget found*, and an icon nested
/// in a destination is not always the thing under the point. That refusal is a
/// warning, not a failure, so the run carries on and dies somewhere else —
/// which is what the ninth run of this recipe did, in the language step, two
/// screens away from the tap that missed.
///
/// The bar itself is the one thing guaranteed to be where it says it is, so
/// the destination is a quarter of it.
Future<void> _tab(WidgetTester tester, int destination) async {
  final bar = tester.getRect(find.byType(NavigationBar));
  final quarter = bar.width / 4;

  await tester.tapAt(
    Offset(bar.left + quarter * (destination + 0.5), bar.center.dy),
  );
  await _beat(tester);
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
  // What is on screen, not just what is missing: a run that says "the app did
  // not open" costs another run, and one that prints the screen does not.
  //
  // Rich text counts: the chapter rows and the section labels are `Text.rich`,
  // whose `data` is null and whose words are the ones worth seeing. The first
  // version of this dumped three strings off a screen full of them.
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText())
      .nonNulls
      .map((text) => text.replaceAll('\n', ' ').trim())
      .where((text) => text.isNotEmpty)
      .take(20)
      .join(' | ');
  fail(
    '$what did not arrive within ${_deadline.inSeconds}s. On screen: $texts',
  );
}

/// The other half of [_waitFor]: pumps until [finder] finds *nothing*.
///
/// A screen can be identified by what leaves rather than by what arrives, and
/// the picker is the one that has to be: it stands outside the shell, so the
/// bottom bar's absence is its signature, and every word on it is a word in
/// the language this step is about to change.
Future<void> _waitGone(WidgetTester tester, Finder finder, String what) async {
  final deadline = DateTime.now().add(_deadline);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  fail(
    '$what never arrived — ${finder.describeMatch(Plurality.many)} is still on screen.',
  );
}

/// Pumps for a fixed beat instead of waiting for the tree to be still.
///
/// `pumpAndSettle` waits for every scheduled frame to be done, and this app
/// rarely stops: a shelf that is still loading shimmers, a page that has not
/// arrived spins, and the reader keeps a placeholder animating while its
/// images come in. A recipe that demanded stillness hangs — rather than
/// fails — on the first screen doing its job, which is where the first real
/// run of this one stopped.
Future<void> _beat(
  WidgetTester tester, [
  Duration of = const Duration(milliseconds: 1200),
]) async {
  final deadline = DateTime.now().add(of);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
