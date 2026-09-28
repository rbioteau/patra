/// The device golden: one known book, opened on a phone, photographed.
///
/// Run it through `tool/device_golden.sh`, never by hand — the script starts
/// the recorded Kavita this signs in to (`tool/golden_server.dart`), wires the
/// phone to it, and puts what comes out beside the reference in
/// `integration_test/golden/reference/` for a person to compare by eye.
///
/// **Why it exists.** Nothing paints under a test binding, so the renderer
/// that ships — the platform's web engine (ADR-0013) — is not the one the
/// suite pins: `test/book_reader_test.dart` checks what the engine is
/// *handed*, never what it draws. This is the floor under that gap, run by a
/// person before a tag and never by CI, which has no phone and would only
/// ever go green.
///
/// **What it photographs**, both times the first page of
/// `integration_test/golden/golden-book.epub` — a heading, prose the engine
/// justifies and hyphenates because the book says it is English, and a
/// picture between two paragraphs:
///
///   1. `book-streamed` — read from the server;
///   2. `book-offline` — the same book saved, the server taken away, and the
///      page read out of the copy.
///
/// The two should be the same picture: a saved book is handed the very
/// document a streamed one is.
///
/// It finds its way the way `store_screenshots_test.dart` does — by position,
/// by icon and by type, never by a label — and its helpers are that file's,
/// kept in step by hand: an integration test is its own program, and the two
/// recipes share nothing else.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patra/main.dart' as app;
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/features/reader/book_chrome.dart';
import 'package:patra/src/features/reader/book_web_page.dart';
import 'package:patra/src/settings/locale_settings.dart';

/// The recorded Kavita, reached through `adb reverse` — the script sets both
/// up. The password is only checked while recording against a real server;
/// replay takes any.
const _server = String.fromEnvironment(
  'GOLDEN_URL',
  defaultValue: 'http://127.0.0.1:5000',
);
const _control = String.fromEnvironment(
  'GOLDEN_CONTROL',
  defaultValue: 'http://127.0.0.1:5001',
);
const _user = String.fromEnvironment('GOLDEN_USER', defaultValue: 'golden');
const _password = String.fromEnvironment(
  'GOLDEN_PASSWORD',
  defaultValue: 'golden',
);

const _deadline = Duration(seconds: 90);

/// How long a page is given to be composed once its view is on screen. The
/// engine loads the file, lays it out, fetches nothing (the pictures are
/// already beside it) and runs the bridge that puts the reader at its place;
/// none of that is a frame Flutter can wait for, so it is a clock.
const _composed = Duration(seconds: 5);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a book, streamed and saved, as the web engine draws it', (
    tester,
  ) async {
    await app.main();
    await _beat(tester);

    await _signIn(tester);
    // English, whatever the phone speaks: the page counter and anything the
    // chrome leaves on screen are then the same words every run.
    await _forceLocale(tester, const Locale('en'));

    await _openTheBook(tester);
    await _waitForPage(tester);
    await _hideChrome(tester);
    await _ask('capture?name=book-streamed');
    await _leaveReader(tester);

    // Saved, then the server taken away: the copy is the only page there is.
    // Nothing at rest offers to save; the row's trailing swipe does.
    await tester.drag(find.byType(Slidable).first, const Offset(-200, 0));
    await _beat(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Save'));
    await _beat(tester);
    await _waitFor(tester, find.byIcon(Icons.check), 'a saved copy');
    await _ask('offline');
    try {
      await tester.tap(find.byType(Slidable).first);
      await _waitForPage(tester);
      await _hideChrome(tester);
      await _ask('capture?name=book-offline');
    } finally {
      await _ask('online');
    }
  });
}

/// Asks the host for something the device cannot do: a screenshot of the
/// glass, or the server gone.
Future<void> _ask(String what) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('$_control/$what'));
    final response = await request.close();
    final said = await response
        .transform(const SystemEncoding().decoder)
        .join();
    if (response.statusCode != HttpStatus.ok) {
      fail('the host refused $what: $said');
    }
  } finally {
    client.close();
  }
}

/// Signs in from an app that has never run — the script uninstalls it first.
/// Positional, because this is the one screen drawn before the language is
/// forced.
Future<void> _signIn(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
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
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _beat(tester);
  FocusManager.instance.primaryFocus?.unfocus();
  await _beat(tester, const Duration(milliseconds: 600));
  await _waitFor(tester, find.byType(NavigationBar), 'the app to open');
}

Future<void> _forceLocale(WidgetTester tester, Locale locale) async {
  // Settings opens on Profiles and Storage: the language row is under them,
  // and a list builds only what it shows.
  await _tabUntil(tester, 3, find.byType(SettingsScreen), 'the settings');
  await tester.scrollUntilVisible(
    find.byIcon(Icons.language),
    200,
    scrollable: find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(find.byIcon(Icons.language));
  final endonym = find.text(languageEndonym(locale));
  await _waitFor(tester, endonym, 'the language sheet');
  await tester.tap(endonym);
  await _waitFor(tester, find.byIcon(Icons.language), 'the sheet to close');
}

/// Library → the one cover → the one book on its series screen → the reader.
Future<void> _openTheBook(WidgetTester tester) async {
  final cover = find
      .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
      .first;
  await _tabUntil(tester, 1, cover, 'the library grid');
  await tester.tap(cover);
  await _waitFor(tester, find.byType(Slidable), 'the series screen');
  await tester.tap(find.byType(Slidable).first);
}

/// Waits for the page's view, then gives the engine its clock.
Future<void> _waitForPage(WidgetTester tester) async {
  await _waitFor(tester, find.byType(BookWebPage), 'the page of the book');
  await _beat(tester, _composed);
}

/// A book opens with its chrome up; the page is photographed without it,
/// with only the numeral at its foot.
Future<void> _hideChrome(WidgetTester tester) async {
  if (find.byType(BookTopBar).evaluate().isEmpty) return;
  await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
  await _beat(tester, const Duration(milliseconds: 600));
}

/// Brings the chrome up and closes the reader, back onto the series screen.
Future<void> _leaveReader(WidgetTester tester) async {
  if (find.byType(BookTopBar).evaluate().isEmpty) {
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
  }
  final back = find.byIcon(Icons.arrow_back);
  await _waitFor(tester, back, 'the reader chrome');
  await tester.tap(back.first);
  await _waitFor(tester, find.byType(Slidable), 'the series screen again');
}

/// A destination of the shell, by where it sits in the bar — see
/// `store_screenshots_test.dart` for why neither its label nor its icon.
Future<void> _tab(WidgetTester tester, int destination) async {
  final bar = tester.getRect(find.byType(NavigationBar));
  final quarter = bar.width / 4;
  await tester.tapAt(
    Offset(bar.left + quarter * (destination + 0.5), bar.center.dy),
  );
  await _beat(tester);
}

/// Taps a destination until [finder] is on screen: a tap made while the bar
/// is still arriving after the sign-in is a tap nothing took, and the first
/// run of this recipe waited ninety seconds on Home for exactly that.
Future<void> _tabUntil(
  WidgetTester tester,
  int destination,
  Finder finder,
  String what,
) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    await _tab(tester, destination);
    if (finder.evaluate().isNotEmpty) return;
  }
  await _waitFor(tester, finder, what);
}

/// Pumps until [finder] finds something, or fails saying what was on screen.
Future<void> _waitFor(WidgetTester tester, Finder finder, String what) async {
  final deadline = DateTime.now().add(_deadline);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
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

/// A fixed beat rather than `pumpAndSettle`, which a shimmer or a spinner
/// never lets settle.
Future<void> _beat(
  WidgetTester tester, [
  Duration of = const Duration(milliseconds: 1200),
]) async {
  final deadline = DateTime.now().add(of);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
