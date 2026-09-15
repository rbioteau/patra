import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/features/reader/reading_direction.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/widgets/reader_settings_sheet.dart';

import 'test_support.dart';

/// The chain resolved for a series nobody has set and nothing has guessed:
/// what is in force is the left-to-right a chapter has always opened in.
ChapterDirection _builtIn() =>
    ChapterDirection(series: null, library: null, detected: null);

void main() {
  testWidgets('the sheet reads what it shows through its own context', (
    tester,
  ) async {
    // Picking a direction closes the sheet *and* the chrome it was opened
    // from, so the cog is out of the tree by the time the sheet is asked to
    // draw itself again — and on a phone what asks it to draw itself again is
    // a change of the window's metrics, which is what the reader's own
    // immersive mode does as its chrome comes and goes. A sheet that kept
    // hold of the context it was opened with looks an ancestor up on a
    // deactivated element, and the frame dies.
    var showCog = true;
    StateSetter? setOuter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testKeychain(),
          profilePreferencesStoreProvider.overrideWithValue(
            ProfilePreferencesStore(keychain: MemoryKeychain()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return Scaffold(
                body: showCog
                    ? Builder(
                        builder: (cog) => IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () => showReaderSettingsSheet(
                            cog,
                            direction: _builtIn(),
                            libraryName: 'Manga',
                          ),
                        ),
                      )
                    : const SizedBox(),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('READING DIRECTION'), findsOneWidget);
    expect(
      find.text('Left to right — the default'),
      findsOneWidget,
      reason: 'the sheet says where the direction in force came from',
    );

    // The chrome goes, and with it the cog that opened the sheet.
    showCog = false;
    setOuter!(() {});
    await tester.pump();

    // The window's metrics change: the status bar coming back, or a rotation.
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
  group('where the direction in force came from', () {
    // A checked row alone reads as "I chose this", and a guess is not a
    // choice: the sheet says which rung answered, and draws the two rows
    // that act on the answer from what the rungs hold.

    testWidgets('a series reads as a choice about that series', (tester) async {
      await _openSheet(
        tester,
        ChapterDirection(
          series: ReadingDirection.rightToLeft,
          library: null,
          detected: null,
        ),
      );

      expect(
        find.text('Right to left — chosen for this series'),
        findsOneWidget,
      );
      // The way back, worded with the direction the series lands on.
      expect(find.text('Follow the default'), findsOneWidget);
      expect(find.text('Left to right'), findsWidgets);
      // And a guess is not a choice, so this is offered too: promoting is how
      // a direction becomes the shelf's own rather than only this series'.
      expect(
        find.text('Make this the default for Manga'),
        findsOneWidget,
        reason: 'nothing is stored for this library',
      );
    });

    testWidgets("the library's own reads as a choice about that shelf", (
      tester,
    ) async {
      await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          library: ReadingDirection.rightToLeft,
          detected: null,
        ),
      );

      expect(
        find.text('Right to left — the default for Manga'),
        findsOneWidget,
      );
      expect(
        find.text('Make this the default for Manga'),
        findsNothing,
        reason: 'it already is this library\u2019s',
      );
      expect(find.text('Follow the default for Manga'), findsOneWidget);
      expect(
        find.text('Left to right'),
        findsWidgets,
        reason: 'the row says which direction dropping it lands on',
      );
      expect(
        find.text('Follow the default'),
        findsNothing,
        reason: 'this series has no direction of its own to drop',
      );
    });

    testWidgets('a shelf the server has not named is still worded', (
      tester,
    ) async {
      // The name arrives with the library list, so a chapter opened before it
      // has landed has an id and no name: the row says "this library" rather
      // than trailing off into nothing.
      await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          library: ReadingDirection.rightToLeft,
          detected: null,
        ),
        libraryName: '',
      );

      expect(
        find.text('Right to left — the default for this library'),
        findsOneWidget,
      );
      expect(find.text('Follow the default for this library'), findsOneWidget);
    });

    testWidgets('a detection is never presented as a choice', (tester) async {
      // #57 fills the rung; this is what the sheet will say when it does.
      await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          library: null,
          detected: ReadingDirection.rightToLeft,
          // Nothing stored on this device either, which is the only case in
          // which the detected rung is asked at all: a direction somebody
          // stored here is a choice, and a guess must never beat one.
        ),
      );

      expect(
        find.text('Right to left — detected from the work'),
        findsOneWidget,
      );
      expect(
        find.text('Make this the default for Manga'),
        findsOneWidget,
        reason:
            'a library holding nothing counts as differing from everything, '
            'which is what lets a detected direction be promoted',
      );
    });

    testWidgets('a promoted library direction is offered no more', (tester) async {
      // The row is drawn while the direction in force differs from what the
      // library holds — and once promoted, it differs no longer.
      await _openSheet(
        tester,
        ChapterDirection(
          series: ReadingDirection.rightToLeft,
          library: ReadingDirection.rightToLeft,
          detected: null,
        ),
      );

      expect(
        find.text('Right to left — chosen for this series'),
        findsOneWidget,
      );
      expect(
        find.text('Make this the default for Manga'),
        findsNothing,
        reason: 'it already is this library\u2019s',
      );
      expect(
        find.text('Follow the default'),
        findsOneWidget,
        reason: 'the series still has one to drop, and it lands on the same',
      );
      expect(find.text('Right to left'), findsWidgets);
    });
  });

  group('the one-shot actions', () {
    // Independent of each other, and all one-shot: unlike the magnifying
    // switch and the width slider, they close the sheet.

    testWidgets('promoting to the library reports it and closes the sheet', (
      tester,
    ) async {
      final outcomes = await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          library: null,
          detected: ReadingDirection.rightToLeft,
        ),
      );

      // A detection is not a choice, and promoting is how one becomes a
      // shelf's: one tap, for every series the guess is wrong about.
      await tester.tap(find.text('Make this the default for Manga'));
      await tester.pumpAndSettle();

      expect(outcomes.single, isA<DirectionPromotedToLibrary>());
      expect(
        find.text('Drag to magnify'),
        findsNothing,
        reason: 'the sheet should have closed, as picking a direction does',
      );
    });

    testWidgets('dropping a library direction reports it, and names where the '
        'chapter lands', (tester) async {
      final outcomes = await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          library: ReadingDirection.verticalScroll,
          detected: null,
        ),
      );

      await tester.tap(find.text('Follow the default for Manga'));
      expect(find.text('Right to left'), findsWidgets);
      await tester.pumpAndSettle();

      expect(outcomes.single, isA<LibraryDirectionCleared>());
      expect(find.text('Drag to magnify'), findsNothing);
    });

    testWidgets('dropping a series direction reports it, and names where the '
        'series lands', (tester) async {
      final outcomes = await _openSheet(
        tester,
        ChapterDirection(
          series: ReadingDirection.verticalScroll,
          library: null,
          detected: null,
        ),
      );

      // Dropped, the series lands on the device's right-to-left: the row
      // names it, because "follow the default" alone promises nothing.
      await tester.tap(find.text('Follow the default'));
      expect(find.text('Right to left'), findsWidgets);
      await tester.pumpAndSettle();

      expect(outcomes.single, isA<SeriesDirectionCleared>());
      expect(find.text('Drag to magnify'), findsNothing);
    });

    testWidgets('picking a direction is still what it was', (tester) async {
      final outcomes = await _openSheet(
        tester,
        _builtIn(),
      );

      await tester.tap(find.text('Right to left'));
      await tester.pumpAndSettle();

      expect(
        outcomes.single,
        isA<DirectionPicked>().having(
          (outcome) => outcome.direction,
          'direction',
          ReadingDirection.rightToLeft,
        ),
      );
    });
  });

  group('for a book', () {
    // The sheet is the same surface for both, and what is in it is not: how
    // pages turn is a question about pictures, and a book has no page sizes
    // for anything to measure or to pair.
    testWidgets('offers a text size and a line spacing', (tester) async {
      await _openBookSheet(tester);

      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Line spacing'), findsOneWidget);
      expect(find.text('16 pt'), findsOneWidget);
      expect(find.text('155%'), findsOneWidget);
    });

    testWidgets('offers nothing that is a question about pictures', (
      tester,
    ) async {
      await _openBookSheet(tester);

      // No direction, because nothing detects one and there are no pictures
      // to turn; no strip width and no magnifying gesture, because a book is
      // not laid out at a width and its pages have no size to magnify.
      expect(find.text('READING DIRECTION'), findsNothing);
      expect(find.text('Left to right'), findsNothing);
      expect(find.text('Drag to magnify'), findsNothing);
      expect(find.text('Page width'), findsNothing);
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets('what the sliders are left at is what a book is set at', (
      tester,
    ) async {
      await _openBookSheet(tester);

      await tester.drag(find.byType(Slider).first, const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(
        find.text('16 pt'),
        findsNothing,
        reason: 'the size a book opens at is not the size it was set to',
      );
      expect(find.text('22 pt'), findsOneWidget);
      expect(
        find.text('155%'),
        findsOneWidget,
        reason: 'setting the size leaves the spacing alone',
      );
    });
  });

  testWidgets('a chapter of pictures is offered no text size', (tester) async {
    await _openSheet(tester, _builtIn());

    expect(find.text('READING DIRECTION'), findsOneWidget);
    expect(find.text('Text size'), findsNothing);
    expect(find.text('Line spacing'), findsNothing);
  });
}

/// Opens the reader's sheet over a cog of its own, and reports what it came
/// back with.
///
/// The outcomes are collected rather than returned, because a test taps a row
/// after the sheet is open and the answer arrives as the sheet closes.
Future<List<ReaderSettingsOutcome>> _openSheet(
  WidgetTester tester,
  ChapterDirection direction, {
  // The shelf the chapter is on, as the server names it — which is what the
  // two rows acting on the library's rung are worded with.
  String libraryName = 'Manga',
}) async {
  final outcomes = <ReaderSettingsOutcome>[];
  // Taller than the 600pt a widget test is given, because every row the
  // chain can ask for is more than a sheet is given on a real phone — and
  // the sheet does scroll, so the honest fix is a surface that reaches them
  // rather than a scroll in every test.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(),
        profilePreferencesStoreProvider.overrideWithValue(
          ProfilePreferencesStore(keychain: MemoryKeychain()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (cog) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                final outcome = await showReaderSettingsSheet(
                  cog,
                  direction: direction,
                  libraryName: libraryName,
                );
                if (outcome != null) outcomes.add(outcome);
              },
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  return outcomes;
}

/// Opens the sheet a book's cog opens, over a cog of its own.
Future<void> _openBookSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(),
        profilePreferencesStoreProvider.overrideWithValue(
          ProfilePreferencesStore(keychain: MemoryKeychain()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (cog) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => showBookSettingsSheet(cog),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}
