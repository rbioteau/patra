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
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/home/continue_hero.dart';
import 'package:patra/src/features/home/home_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/offline_indicator.dart';

import 'test_support.dart';

/// Home is where the app opens, and an offline Home that says "nothing here,
/// try Downloads" while the device knows perfectly well what was being read is
/// the inconsistency the catalogue exists to remove. So every test here runs
/// against a server that is **not there at all** — `UnreachableServer`, the
/// same adapter the overlay's own suite uses — and what differs between them
/// is only what the device happens to remember.

Series _series(int id, String name, {String? lastRead}) => Series(
  id: id,
  name: name,
  libraryId: 1,
  libraryName: 'Manga',
  pages: 100,
  pagesRead: 40,
  format: MangaFormat.archive,
  latestReadDate: lastRead == null ? null : DateTime.parse(lastRead),
);

/// What the app already says when it has nothing whatever to draw and the
/// server is out of reach — `_OfflineHome`, which this feature is about
/// *keeping* for the cases it is still right for.
const _offlineHomeWithSaved =
    'The server is out of reach. What you saved is still here.';
const _offlineHomeNothingSaved =
    'The server is out of reach, and nothing is saved on this device yet.';

/// A catalogue root with whatever [seed] writes into it, seeded through a
/// store of its own.
///
/// The container below gets a **fresh** store on the same root, so what the
/// screen draws has to come off the disk exactly as it does on a cold start.
/// Handing it the seeding instance would leave the spine and the On deck
/// ranking already in memory and skip the one-shot read the overlays hang on.
Future<Directory> _catalogue(
  Future<void> Function(CatalogueStore store) seed,
) async {
  final root = Directory.systemTemp.createTempSync('patra-home-offline');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  await seed(CatalogueStore(root: root, profileId: 'test'));
  return root;
}

/// Home, offline, reading through the catalogue at [root].
///
/// The client is built by an `overrideWith` rather than handed in ready-made,
/// because `offlineProvider` only ever moves through
/// `onReachabilityChanged` — which the real provider wires and a
/// `overrideWithValue` leaves dead. Without it `_OfflineHome` could never
/// draw, and half of what is asserted here would be vacuously true.
Future<UnreachableServer> _pumpHome(
  WidgetTester tester,
  Directory root, {
  bool somethingSaved = false,
}) async {
  mockPathProvider();
  // A phone, 390x844: the default 800x600 test window is short enough that
  // the libraries section under the shelf never gets built, so a screen with
  // three things on it could only ever be asserted two-thirds of.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final adapter = UnreachableServer();
  final downloads = Directory.systemTemp.createTempSync('patra-home-saved');
  addTearDown(() {
    if (downloads.existsSync()) downloads.deleteSync(recursive: true);
  });
  if (somethingSaved) {
    await saveChapterFixture(downloads, 'test', chapterId: 42);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kavitaClientProvider.overrideWith((ref) {
          final client = KavitaClient(
            baseUrl: 'http://kavita.test',
            token: 'token',
            username: 'romain',
            apiKey: 'key',
            onReachabilityChanged: (reachable) =>
                ref.read(offlineProvider.notifier).set(!reachable),
          );
          client.httpClient.httpClientAdapter = adapter;
          client.bareHttpClient.httpClientAdapter = adapter;
          return client;
        }),
        catalogueStoreProvider.overrideWithValue(
          CatalogueStore(root: root, profileId: 'test'),
        ),
        // There is no session here, and the two session-scoped stores would
        // both throw a `StateError` without one. What is under test is the
        // screen, not the scoping — `test/saved_chapters_per_profile_test.dart`
        // is where that lives.
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: downloads, profileId: 'test'),
        ),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  return adapter;
}

/// Pumps until [until] holds, rather than for a fixed number of frames.
///
/// Reading the catalogue is **real filesystem IO**, which `pumpAndSettle`
/// knows nothing about: it settles the frames in front of it and returns
/// before a `spine.json` has been opened. A fixed number of pumps is the same
/// race with a different number on it — so every wait here is on a condition,
/// and `pumpAndSettle` is what finishes the job once the disk has answered:
/// `serverRetry`'s three attempts are ordinary timers, which it does advance,
/// and it returns only when nothing is animating.
Future<void> _pumpUntil(WidgetTester tester, FinderBase<Element> until) async {
  for (var frame = 0; frame < 80; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (until.evaluate().isNotEmpty) return;
  }
  fail('gave up waiting for $until');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline, the shelf and the card are what the device remembers', (
    tester,
  ) async {
    final root = await _catalogue((store) async {
      await store.putLibraries(const [
        Library(id: 1, name: 'Manga', type: LibraryType.manga),
      ]);
      await store.putOnDeck([
        _series(5, 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
        _series(6, 'Berserk'),
      ]);
      await store.putVolumes(5, catalogueVolumesFixture);
    });

    final adapter = await _pumpHome(tester, root);
    // The spine, the ranking and the volumes are three separate reads off the
    // device, and the card can be drawn before the last of them lands.
    await _pumpUntil(tester, find.byType(ContinueHero));
    await _pumpUntil(tester, find.text('Manga'));
    await tester.pumpAndSettle();

    // The card: promoted out of the stored ranking, resuming from the stored
    // volumes. Nothing answered, so there is nowhere else either could have
    // come from.
    expect(
      find.descendant(
        of: find.byType(ContinueHero),
        matching: find.text('Vinland Saga'),
      ),
      findsOneWidget,
    );
    // The shelf under it keeps the rest of the ranking, and the library the
    // spine remembers is drawn too — `librariesProvider` is one question both
    // tabs ask, so Home has read the catalogue for that since #32.
    expect(find.text('Berserk'), findsOneWidget);
    expect(find.text('Manga'), findsOneWidget);

    // And `_OfflineHome` has stood down: the device has plenty to say.
    expect(find.text(_offlineHomeWithSaved), findsNothing);
    expect(find.text(_offlineHomeNothingSaved), findsNothing);

    // A stored ranking carries **no decoration of any kind** (ADR-0005): the
    // status in the bar is what says the answer may be old, and the sentence
    // behind it must not reappear over the content.
    expect(find.byType(OfflineIndicator), findsOneWidget);
    expect(
      find.text(
        'Server unreachable — offline mode. Saved chapters remain readable.',
      ),
      findsNothing,
    );

    expect(adapter.requests, greaterThan(0), reason: 'it really did try');
    // The hero's candidates are the shelf's own, offline as online.
    expect(
      adapter.paths,
      isNot(contains('/api/Series/currently-reading')),
      reason: 'the stale pile is not the question the hero asks',
    );
  });

  testWidgets('offline with an empty catalogue, _OfflineHome is unchanged', (
    tester,
  ) async {
    // Where the catalogue has nothing — a first launch offline — today's
    // screen stands untouched. That is what makes the change additive.
    final root = await _catalogue((store) async {
      // Asked and answered with nothing, as a screen's own first frame does.
      await store.loadSpine();
    });

    await _pumpHome(tester, root, somethingSaved: true);
    await _pumpUntil(tester, find.text(_offlineHomeWithSaved));

    expect(find.byType(ContinueHero), findsNothing);
    // The way out is still gated on something really being saved.
    expect(find.text('See your downloads'), findsOneWidget);
    // And nothing is still shimmering for an answer that is never coming.
    expect(find.byType(Skeleton), findsNothing);
  });

  testWidgets('offline with nothing saved either, and no way out offered', (
    tester,
  ) async {
    final root = await _catalogue((store) async => store.loadSpine());

    await _pumpHome(tester, root);
    await _pumpUntil(tester, find.text(_offlineHomeNothingSaved));

    expect(find.text('See your downloads'), findsNothing);
  });

  testWidgets('a stored ranking whose volumes were never opened keeps its '
      'series in the shelf', (tester) async {
    // The rule that makes the card a promotion and never an obligation, and
    // it needed nothing new: the volumes overlay resolves into its fetch's
    // failure, and the removal from the shelf is keyed on the card being
    // there. A series browsed but never opened is exactly this case — the
    // spine holds it, no `series/<id>.json` does.
    final root = await _catalogue(
      (store) => store.putOnDeck([
        _series(5, 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
      ]),
    );

    await _pumpHome(tester, root);
    // The shelf drawing the series is the ranking's own read landing; the
    // card's verdict then rests on the volumes, which is a timer away.
    //
    // **This absence cannot pass vacuously**, which is what makes waiting on
    // quiescence honest here: while the volumes are merely unknown the hero
    // is drawn anyway, with its button disabled — so a `findsNothing` that
    // ran too early would fail rather than pass.
    await _pumpUntil(tester, find.text('Vinland Saga'));
    await tester.pumpAndSettle();

    expect(find.byType(ContinueHero), findsNothing);
    expect(
      find.text('Vinland Saga'),
      findsOneWidget,
      reason: 'a hero that cannot be drawn must not take its series with it',
    );
    // Not `_OfflineHome` either: something did come back.
    expect(find.text(_offlineHomeNothingSaved), findsNothing);
  });
}
