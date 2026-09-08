import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/catalogue/catalogue_provider.dart';
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/features/library/library_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/cover.dart';
import 'package:patra/src/widgets/offline_indicator.dart';

import 'test_support.dart';

Series _series(int id, String name) => Series(
  id: id,
  name: name,
  libraryId: 7,
  libraryName: 'Mangas',
  pages: 100,
  pagesRead: 40,
  format: MangaFormat.archive,
  latestReadDate: null,
);

/// The Library tab, offline, reading through a catalogue built by [fill].
///
/// The catalogue is written **through the store**, as every fixture here has
/// to be: what a screen reads back is a real spine, filed and parsed the way
/// the device would have done it.
Future<void> _pumpOffline(
  WidgetTester tester, {
  required Future<void> Function(CatalogueStore store) fill,
}) async {
  mockPathProvider();
  final root = Directory.systemTemp.createTempSync('patra-library-offline');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = UnreachableServer();
  client.bareHttpClient.httpClientAdapter = UnreachableServer();

  final profile = Profile(
    baseUrl: 'http://kavita.test',
    accountId: 1,
    username: 'romain',
    token: 'token',
    apiKey: 'key',
  );

  final store = CatalogueStore(root: root, profileId: profile.id);
  await fill(store);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [profile], activeId: profile.id),
        ),
        kavitaClientProvider.overrideWithValue(client),
        catalogueStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LibraryScreen(),
      ),
    ),
  );
  // The assertion as much as the wait: `serverRetry` bounds the attempts, so
  // this returns only once every one of them has failed and nothing is left
  // shimmering.
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline, the tab draws the shelves the device remembers', (
    tester,
  ) async {
    await _pumpOffline(
      tester,
      fill: (store) async {
        await store.putLibraries(const [
          Library(id: 7, name: 'Mangas', type: LibraryType.manga),
        ]);
        await store.putSeriesList(7, [
          _series(1, 'Blame!'),
          _series(2, 'Vinland Saga'),
        ]);
      },
    );

    // The library pill and the grid, with no server to have asked.
    expect(find.text('Mangas'), findsWidgets);
    expect(find.text('Blame!'), findsOneWidget);
    expect(find.text('Vinland Saga'), findsOneWidget);
    expect(find.byType(CoverTile), findsNWidgets(2));

    // And the failure is not *also* drawn: a screen with something on it is
    // not in an error state, whatever the request did.
    expect(find.textContaining('Could not reach'), findsNothing);

    // What says why instead. Its presence, not its icon: whether the cloud is
    // struck through depends on `offlineProvider`, which only moves for a
    // client built by the real provider — that is
    // `test/offline_indicator_test.dart`'s subject, not this one's.
    expect(find.byType(OfflineIndicator), findsOneWidget);
  });

  testWidgets('offline with nothing remembered, the failure still shows', (
    tester,
  ) async {
    // The other half of the precedence rule, and the one that keeps today's
    // screens: an empty catalogue must not swallow the error into a
    // permanent skeleton.
    await _pumpOffline(tester, fill: (store) => store.loadSpine());

    expect(find.byType(CoverTile), findsNothing);
    // The retry affordance the error state is made of, rather than its exact
    // wording, which belongs to the l10n test.
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('a library remembered as empty keeps its own empty state', (
    tester,
  ) async {
    // An empty library is a state with copy of its own, and the overlay has
    // to hand it through rather than fall past it to the failure.
    await _pumpOffline(
      tester,
      fill: (store) async {
        await store.putLibraries(const [
          Library(id: 7, name: 'Mangas', type: LibraryType.manga),
        ]);
        await store.putSeriesList(7, const []);
      },
    );

    expect(find.text('This library is empty'), findsOneWidget);
    expect(find.byType(CoverTile), findsNothing);
  });
}
