import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/catalogue/catalogue_provider.dart';
import 'package:patra/src/catalogue/catalogue_reads.dart' as catalogue;
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/series/series_detail_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/save_pill.dart';

import 'test_support.dart';

const _profileId = 'http://kavita.test#1';

Chapter _chapter(
  int id, {
  String range = '',
  int pages = 100,
  int pagesRead = 0,
  bool isSpecial = false,
  String title = '',
}) => Chapter(
  id: id,
  title: title.isEmpty ? range : title,
  titleName: title,
  range: range,
  minNumber: num.tryParse(range) ?? 0,
  pages: pages,
  pagesRead: pagesRead,
  isSpecial: isSpecial,
  sortOrder: id,
  format: MangaFormat.archive,
);

/// One numbered volume of two chapters, plus Kavita's specials pseudo-volume:
/// the three sections the screen has to draw between them.
final _volumes = <Volume>[
  Volume(
    id: 10,
    name: '1',
    minNumber: 1,
    pages: 200,
    pagesRead: 100,
    chapters: [
      _chapter(101, range: '1', pagesRead: 100),
      _chapter(102, range: '2'),
    ],
  ),
  Volume(
    id: 11,
    name: 'Specials',
    minNumber: Volume.specialsNumber,
    pages: 40,
    pagesRead: 0,
    chapters: [
      _chapter(301, pages: 40, isSpecial: true, title: 'Blame! Academy'),
    ],
  ),
];

const _series = Series(
  id: 5,
  name: 'Blame!',
  libraryId: 7,
  libraryName: 'Mangas',
  pages: 240,
  pagesRead: 100,
  format: MangaFormat.archive,
  latestReadDate: null,
);

const _metadata = SeriesMetadata(
  summary: 'Killy walks the city.',
  writers: ['Tsutomu Nihei'],
  genres: ['Seinen'],
);

/// A catalogue and a downloads store on **separate** temp roots: both file by
/// profile, so one root would put a spine where `DownloadsService.scan`
/// sweeps.
({CatalogueStore catalogue, Directory downloads}) _stores() {
  Directory temp(String name) {
    final dir = Directory.systemTemp.createTempSync(name);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return dir;
  }

  return (
    catalogue: CatalogueStore(
      root: temp('patra-series-cat'),
      profileId: _profileId,
    ),
    downloads: temp('patra-series-dl'),
  );
}

/// The series screen with no server at all, reading through a catalogue built
/// by [fill] and a downloads store built by [save].
///
/// Both fixtures go **through their store**, which is the rule for either of
/// them: a hand-built download is swept rather than listed, and a hand-built
/// catalogue file is not what the parser would have written.
Future<void> _pumpOffline(
  WidgetTester tester, {
  Future<void> Function(CatalogueStore store)? fill,
  Future<void> Function(Directory root)? save,
}) async {
  mockPathProvider();
  final stores = _stores();
  if (fill != null) await fill(stores.catalogue);
  if (save != null) await save(stores.downloads);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // `overrideWith` and not `overrideWithValue`: what turns a failed
        // request into the offline state is `onReachabilityChanged`, wired by
        // the real provider — and offline is what dims a row and takes the
        // save pill away. A ready-made client leaves every row openable
        // however unreachable the server is.
        kavitaClientProvider.overrideWith((ref) {
          final client = KavitaClient(
            baseUrl: 'http://kavita.test',
            token: 'token',
            username: 'romain',
            apiKey: 'key',
            onReachabilityChanged: (reachable) =>
                ref.read(offlineProvider.notifier).set(!reachable),
          );
          client.httpClient.httpClientAdapter = UnreachableServer();
          client.bareHttpClient.httpClientAdapter = UnreachableServer();
          return client;
        }),
        catalogueStoreProvider.overrideWithValue(stores.catalogue),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: stores.downloads, profileId: _profileId),
        ),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SeriesDetailScreen(
          seriesId: 5,
          seriesName: 'Blame!',
          libraryId: 7,
        ),
      ),
    ),
  );
  // The assertion as much as the wait: `serverRetry` bounds the attempts, so
  // this can only return once every one of them has failed and nothing is
  // left shimmering.
  await tester.pumpAndSettle();
}

Future<void> _fillAll(CatalogueStore store) async {
  await store.putVolumes(5, _volumes);
  await store.putSeries(_series);
  await store.putSeriesMetadata(5, _metadata);
}

/// The nearest [Opacity] above the row labelled [label] — 0.4 is the
/// dimming that says a row cannot be opened.
double _rowOpacity(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first,
    )
    .opacity;

bool _rowOpens(WidgetTester tester, String label) =>
    tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
        )
        .onTap !=
    null;

/// Whether the hero's resume button can be pressed.
bool _resumeEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline, a series the device remembers opens whole', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpOffline(tester, fill: _fillAll);

    // The hero: the title, who made it, and the tally with the library name —
    // the series' own row, which is a second stored fetch.
    expect(find.text('Blame!'), findsNWidgets(2));
    expect(find.text('Tsutomu Nihei · Seinen'), findsOneWidget);
    expect(find.text('1 volume · Mangas'), findsOneWidget);
    // Chapter 1 is finished and chapter 2 untouched, so reading resumes at 2.
    expect(find.text('Continue — Ch. 2'), findsOneWidget);

    // The sections, and the specials that close the screen.
    expect(find.text('VOLUMES'), findsOneWidget);
    expect(find.text('SPECIALS'), findsOneWidget);
    expect(find.text('Blame! Academy'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Chapter 2'), findsOneWidget);

    // And the failure is not *also* drawn: a screen with the series on it is
    // not in an error state, whatever the request did.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('every row is dimmed and unopenable where nothing is saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpOffline(tester, fill: _fillAll);

    // The screen is informative even where nothing opens: it says what
    // exists and how far through it you are, and the dimming tells the truth
    // about every row.
    for (final row in ['Chapter 1', 'Chapter 2', 'Blame! Academy']) {
      expect(_rowOpacity(tester, row), 0.4, reason: row);
      expect(_rowOpens(tester, row), isFalse, reason: row);
    }
    // The hero says the same thing as the rows: the chapter it would resume
    // is one of them, and it is not here.
    expect(_resumeEnabled(tester), isFalse);
    // Nor is anything offered that offline cannot be done: a chapter that is
    // not already on the device cannot be fetched.
    expect(find.byType(SavePill), findsNothing);
  });

  testWidgets('a saved chapter is openable and shows the saved copy\'s '
      'progress', (tester) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpOffline(
      tester,
      fill: _fillAll,
      // Read on the train: 60 of the 100 pages, where the catalogue holds the
      // server's last word of none of them.
      save: (root) async => saveChapterFixture(
        root,
        _profileId,
        chapterId: 102,
        seriesId: 5,
        title: 'Chapter 2',
        pages: 100,
        pagesRead: 60,
      ),
    );

    // Overlaid, never absorbed: the saved copy is the newer word about its
    // own row, and the catalogue is deliberately never told.
    expect(find.text('Page 60 / 100'), findsOneWidget);
    expect(
      find.text('100 pages'),
      findsOneWidget,
      reason: 'the unsaved chapter, whose row is the catalogue\'s',
    );

    // Its row is the one that opens, and the only one.
    expect(_rowOpens(tester, 'Chapter 2'), isTrue);
    expect(_rowOpacity(tester, 'Chapter 2'), 1);
    expect(_rowOpens(tester, 'Chapter 1'), isFalse);
    expect(_rowOpens(tester, 'Blame! Academy'), isFalse);
    // And the hero resumes into it, which is the whole chain: the saved
    // copy's progress reached the resume point, not only the row.
    expect(find.text('Continue — Ch. 2'), findsOneWidget);
    expect(_resumeEnabled(tester), isTrue);
    // The pill stays for a copy that is already here, since removing one is
    // local.
    expect(find.byType(SavePill), findsOneWidget);
  });

  testWidgets('where neither the fetch nor the catalogue can answer, the '
      'hero stops shimmering', (tester) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // A series never opened, on a device that has been offline since. The
    // `pumpAndSettle` inside `_pumpOffline` is half the assertion: a
    // `Skeleton` repeats forever, so it can only return once they have gone.
    await _pumpOffline(tester, fill: (store) => store.loadSpine());

    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  test(
    'the overlay is three deep: a mark-read wins over the catalogue',
    () async {
      // The order is the whole of it — catalogue, then the fetch, then the
      // optimistic mark-read on top. Driven through the container because the
      // gesture itself is gone offline, while an override made before the
      // connection dropped is not.
      final stores = _stores();
      await stores.catalogue.putVolumes(5, _volumes);
      await saveChapterFixture(
        stores.downloads,
        _profileId,
        chapterId: 102,
        seriesId: 5,
        pages: 100,
        pagesRead: 60,
      );

      final client = KavitaClient(
        baseUrl: 'http://kavita.test',
        token: 'token',
        username: 'romain',
        apiKey: 'key',
      );
      client.httpClient.httpClientAdapter = UnreachableServer();
      client.bareHttpClient.httpClientAdapter = UnreachableServer();
      final container = ProviderContainer(
        overrides: [
          kavitaClientProvider.overrideWithValue(client),
          catalogueStoreProvider.overrideWithValue(stores.catalogue),
          downloadsServiceProvider.overrideWithValue(
            DownloadsService(root: stores.downloads, profileId: _profileId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        seriesVolumesProvider(5),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await expectLater(
        container.read(catalogue.volumes(5).refreshable),
        throwsA(isA<DioException>()),
      );
      await container.read(downloadsProvider.future);

      int pagesRead(int chapterId) => subscription
          .read()
          .value!
          .expand((volume) => volume.chapters)
          .firstWhere((chapter) => chapter.id == chapterId)
          .pagesRead;

      // The catalogue under the saved copy.
      expect(pagesRead(102), 60);
      // And the mark-read over both.
      container.read(readOverridesProvider.notifier).set(102, 100);
      expect(pagesRead(102), 100);
      // A row nothing has overridden and nothing has saved is the catalogue's.
      expect(pagesRead(101), 100);
    },
  );
}
