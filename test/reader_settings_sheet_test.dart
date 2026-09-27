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

    testWidgets('a promoted library direction is offered no more', (
      tester,
    ) async {
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
      final outcomes = await _openSheet(tester, _builtIn());

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
    testWidgets('offers the face a book is set in, and nothing else', (
      tester,
    ) async {
      await _openBookSheet(tester);

      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Line spacing'), findsOneWidget);
      expect(find.text('Reading face'), findsOneWidget);
      expect(find.text('16 pt'), findsOneWidget);
      expect(find.text('155%'), findsOneWidget);
      // Three choices, each labelled by the kind of type it is — not a font's
      // name. The row itself is the sample, composed in that face.
      expect(find.text("The book's own"), findsOneWidget);
      expect(find.text('Serif'), findsOneWidget);
      expect(find.text('Sans serif'), findsOneWidget);
      // How a book is justified and hyphenated is its own composition,
      // deferred to it, and not a way it is set (#130): no row for it.
      expect(
        find.textContaining(RegExp('justif|hyphen', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('the face is the third row, and the last', (tester) async {
      await _openBookSheet(tester);

      // Two sliders and no third: the face is picked from a list rather
      // than slid, so what follows the line spacing is not a number.
      expect(find.byType(Slider), findsNWidgets(2));
      final spacing = tester.getCenter(find.text('Line spacing'));
      final face = tester.getCenter(find.text('Reading face'));
      expect(face.dy, greaterThan(spacing.dy));
    });

    testWidgets('picking a face leaves the two numbers alone', (tester) async {
      await _openBookSheet(tester);

      await tester.tap(find.text('Serif'));
      await tester.pumpAndSettle();

      // The check moves to the face that was picked, and the sheet stays
      // open over the page it has just reset — which is why a face is not
      // something the sheet comes back with.
      expect(find.text('16 pt'), findsOneWidget);
      expect(find.text('155%'), findsOneWidget);
      // Two checks on the sheet — a face and a direction — and the face's is
      // the one above the direction's heading.
      final heading = tester.getCenter(find.text('READING DIRECTION')).dy;
      final faceChecks = tester
          .widgetList(find.byIcon(Icons.check))
          .map((icon) => tester.getCenter(find.byWidget(icon)).dy)
          .where((dy) => dy < heading)
          .toList();
      expect(faceChecks, [
        tester.getCenter(find.text('Serif')).dy,
      ], reason: 'exactly one of the three is in force');
    });
    testWidgets('offers nothing that is a question about pictures', (
      tester,
    ) async {
      await _openBookSheet(tester);

      // No strip width and no magnifying gesture, because a book is not laid
      // out at a width and its pages have no size to magnify.
      expect(find.text('Drag to magnify'), findsNothing);
      expect(find.text('Page width'), findsNothing);
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets('offers the two directions a book can turn in (#121)', (
      tester,
    ) async {
      await _openBookSheet(tester);

      expect(find.text('READING DIRECTION'), findsOneWidget);
      expect(find.text('Left to right'), findsOneWidget);
      expect(find.text('Right to left'), findsOneWidget);
      // A book's pages are the server's and are turned, so there is no strip
      // to scroll through: a row that could be picked and did nothing would
      // be worse than no row.
      expect(find.text('Vertical'), findsNothing);
    });

    testWidgets('the direction comes last, under how the book is set', (
      tester,
    ) async {
      // A book's direction is nearly always right and is there to be
      // corrected; its type is what a reader reaches for.
      await _openBookSheet(tester);

      final face = tester.getCenter(find.text('Reading face'));
      final direction = tester.getCenter(find.text('READING DIRECTION'));
      expect(direction.dy, greaterThan(face.dy));
    });

    testWidgets('a declaration reads as what the book says', (tester) async {
      // For a book the detected rung is no detection: it is what the book
      // declared of itself in its own stylesheet (#118).
      await _openBookSheet(
        tester,
        direction: ChapterDirection(
          series: null,
          library: null,
          detected: ReadingDirection.rightToLeft,
        ),
      );

      expect(find.text('Right to left — as the book declares'), findsOneWidget);
      expect(find.textContaining('detected from the work'), findsNothing);
    });

    testWidgets('picking a direction reports it and closes the sheet', (
      tester,
    ) async {
      final outcomes = await _openBookSheet(tester);

      await tester.tap(find.text('Right to left'));
      await tester.pumpAndSettle();

      expect(outcomes, hasLength(1));
      expect(
        (outcomes.single as DirectionPicked).direction,
        ReadingDirection.rightToLeft,
      );
      expect(find.text('Text size'), findsNothing, reason: 'one-shot');
    });

    testWidgets('the row back lands on what the book declares', (tester) async {
      final outcomes = await _openBookSheet(
        tester,
        direction: ChapterDirection(
          series: ReadingDirection.leftToRight,
          library: null,
          detected: ReadingDirection.rightToLeft,
        ),
      );

      expect(
        find.text('Left to right — chosen for this series'),
        findsOneWidget,
      );
      final back = find.widgetWithText(ListTile, 'Follow the default');
      expect(
        find.descendant(of: back, matching: find.text('Right to left')),
        findsOneWidget,
      );
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(outcomes.single, isA<SeriesDirectionCleared>());
    });

    testWidgets('a direction can be made the library\'s, as for pictures', (
      tester,
    ) async {
      final outcomes = await _openBookSheet(
        tester,
        direction: ChapterDirection(
          series: ReadingDirection.rightToLeft,
          library: null,
          detected: null,
        ),
        libraryName: 'Books',
      );

      await tester.tap(find.text('Make this the default for Books'));
      await tester.pumpAndSettle();
      expect(outcomes.single, isA<DirectionPromotedToLibrary>());
    });

    testWidgets('a promotion that would change nothing a book turns in is '
        'not offered', (tester) async {
      // A series scrolled as a strip on a shelf read left to right: the book
      // turns left to right either way, so writing it to the shelf would
      // close the sheet having done nothing.
      await _openBookSheet(
        tester,
        direction: ChapterDirection(
          series: ReadingDirection.verticalScroll,
          library: ReadingDirection.leftToRight,
          detected: null,
        ),
      );

      expect(find.textContaining('Make this the default for'), findsNothing);
    });

    testWidgets('a vertical direction inherited from a shelf reads as the '
        'left to right a book opens in', (tester) async {
      // A library read as a strip turns none of its books into one: the
      // reader collapses it, so the sheet names what the book really does.
      final outcomes = await _openBookSheet(
        tester,
        direction: ChapterDirection(
          series: null,
          library: ReadingDirection.verticalScroll,
          detected: null,
        ),
        libraryName: 'Mixed',
      );

      expect(
        find.text('Left to right — the default for Mixed'),
        findsOneWidget,
      );
      final row = find.widgetWithText(ListTile, 'Left to right').first;
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      // And the way back from the shelf names where the book lands in the
      // same terms.
      final back = find.widgetWithText(
        ListTile,
        'Follow the default for Mixed',
      );
      expect(
        find.descendant(of: back, matching: find.text('Left to right')),
        findsOneWidget,
      );
      // And tapping it drops the shelf's own, which is the way back from a
      // shelf of scans that turned the books beside them.
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(outcomes.single, isA<LibraryDirectionCleared>());
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
    // Nor a reading face: a chapter of pictures has no words to set in one.
    expect(find.text('Reading face'), findsNothing);
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

/// Opens the sheet a book's cog opens, over a cog of its own, and reports
/// what it came back with — as [_openSheet] does.
Future<List<ReaderSettingsOutcome>> _openBookSheet(
  WidgetTester tester, {
  ChapterDirection? direction,
  String libraryName = 'Books',
}) async {
  final outcomes = <ReaderSettingsOutcome>[];
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
                final outcome = await showBookSettingsSheet(
                  cog,
                  direction:
                      direction ??
                      ChapterDirection(
                        series: null,
                        library: null,
                        detected: null,
                      ),
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
