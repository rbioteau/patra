import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/features/reader/reading_direction.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/widgets/reader_settings_sheet.dart';
import 'test_support.dart';

/// The chain resolved for a series nobody has set: what is in force is the
/// [device] default, which is the whole of what most chapters open on.
ChapterDirection _fromDevice(ReadingDirection device) => ChapterDirection(
  series: null,
  profile: null,
  detected: null,
  device: device,
);

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
            ProfilePreferencesStore(
              keychain: MemoryKeychain(),
              deviceDirection: ReadingDirection.verticalScroll,
            ),
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
                            direction: _fromDevice(
                              ReadingDirection.verticalScroll,
                            ),
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
      find.text('Vertical — the default'),
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
          profile: null,
          detected: null,
          device: ReadingDirection.leftToRight,
        ),
      );

      expect(find.text('Right to left — chosen for this series'), findsOneWidget);
      // The way back, worded with the direction the series lands on.
      expect(find.text('Follow the default'), findsOneWidget);
      expect(find.text('Left to right'), findsWidgets);
      // And a guess is not a choice, so this is offered too: promoting is how
      // a direction becomes somebody's own default rather than a series'.
      expect(
        find.text('Make this my default'),
        findsOneWidget,
        reason: 'nothing is stored as the profile\u2019s own',
      );
    });

    testWidgets("the profile's own reads as their default", (tester) async {
      await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          profile: ReadingDirection.rightToLeft,
          detected: null,
          device: ReadingDirection.leftToRight,
        ),
      );

      expect(find.text('Right to left — your default'), findsOneWidget);
      expect(
        find.text('Follow the default'),
        findsNothing,
        reason: 'this series has no direction of its own to drop',
      );
      expect(
        find.text('Make this my default'),
        findsNothing,
        reason: 'it already is their default',
      );
    });

    testWidgets('a detection is never presented as a choice', (tester) async {
      // #57 fills the rung; this is what the sheet will say when it does.
      await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          profile: null,
          detected: ReadingDirection.rightToLeft,
          // Nothing stored on this device either, which is the only case in
          // which the detected rung is asked at all: a direction somebody
          // stored here is a choice, and a guess must never beat one.
          device: null,
        ),
      );

      expect(find.text('Right to left — detected from the work'), findsOneWidget);
      expect(
        find.text('Make this my default'),
        findsOneWidget,
        reason:
            'no stored default counts as differing from everything, which is '
            'what lets a detected direction be promoted',
      );
    });

    testWidgets('a promoted default is offered no more', (tester) async {
      // The row is drawn while the direction in force differs from what the
      // profile has stored — and once promoted, it differs no longer.
      await _openSheet(
        tester,
        ChapterDirection(
          series: ReadingDirection.rightToLeft,
          profile: ReadingDirection.rightToLeft,
          detected: null,
          device: ReadingDirection.leftToRight,
        ),
      );

      expect(find.text('Right to left — chosen for this series'), findsOneWidget);
      expect(
        find.text('Make this my default'),
        findsNothing,
        reason: 'it already is their default',
      );
      expect(
        find.text('Follow the default'),
        findsOneWidget,
        reason: 'the series still has one to drop, and it lands on the same',
      );
      expect(find.text('Right to left'), findsWidgets);
    });
  });

  group('the two actions', () {
    // Independent of each other, and both one-shot: unlike the magnifying
    // switch and the width slider, they close the sheet.

    testWidgets('promoting reports the promotion and closes the sheet', (
      tester,
    ) async {
      final outcomes = await _openSheet(
        tester,
        ChapterDirection(
          series: null,
          profile: null,
          detected: null,
          device: ReadingDirection.rightToLeft,
        ),
      );

      await tester.tap(find.text('Make this my default'));
      await tester.pumpAndSettle();

      expect(outcomes.single, isA<DirectionPromoted>());
      expect(
        find.text('Drag to magnify'),
        findsNothing,
        reason: 'the sheet should have closed, as picking a direction does',
      );
    });

    testWidgets('dropping a series direction reports it, and names where the '
        'series lands', (tester) async {
      final outcomes = await _openSheet(
        tester,
        ChapterDirection(
          series: ReadingDirection.verticalScroll,
          profile: null,
          detected: null,
          device: ReadingDirection.rightToLeft,
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
        _fromDevice(ReadingDirection.leftToRight),
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
}

/// Opens the reader's sheet over a cog of its own, and reports what it came
/// back with.
///
/// The outcomes are collected rather than returned, because a test taps a row
/// after the sheet is open and the answer arrives as the sheet closes.
Future<List<ReaderSettingsOutcome>> _openSheet(
  WidgetTester tester,
  ChapterDirection direction,
) async {
  final outcomes = <ReaderSettingsOutcome>[];
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
