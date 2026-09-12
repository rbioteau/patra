import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/widgets/reader_settings_sheet.dart';
import 'test_support.dart';

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
                            direction: ReadingDirection.verticalScroll,
                            onDirectionChanged: (_) {},
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
}
