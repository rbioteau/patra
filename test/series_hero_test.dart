import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/series/series_detail_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/cover.dart';

import 'test_support.dart';

Map<String, dynamic> _chapter(int id, String range, int pages, int read) => {
  'id': id,
  'range': range,
  'minNumber': int.parse(range),
  'pages': pages,
  'pagesRead': read,
};

class _SeriesAdapter implements HttpClientAdapter {
  _SeriesAdapter(
    this.volumes, {
    this.refuse = false,
    this.libraryType,
    this.seriesName = 'Vinland Saga',
  });

  final List<Map<String, dynamic>> volumes;

  /// A server that answers, and refuses: what a series this account cannot
  /// see looks like, since Kavita scopes the lookup to the account and says
  /// the series does not exist.
  final bool refuse;

  /// What the one library holds, which is what names a series' parts. Absent
  /// where the test does not care: no answer at all leaves the type at its
  /// manga fallback.
  final LibraryType? libraryType;

  /// The series' name, which the hero and the app bar both draw; a long one
  /// is what a title that wraps past the cover's height is made of.
  final String seriesName;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    if (refuse) return ResponseBody.fromString('nope', 400);
    return switch (options.path) {
      '/api/Library/libraries' => switch (libraryType) {
        null => ResponseBody.fromBytes(const [], 404),
        final type => json([
          {'id': 1, 'name': 'Shelf', 'type': type.id},
        ]),
      },
      '/api/Series/5' => json({
        'id': 5,
        'name': seriesName,
        'libraryId': 1,
        'libraryName': 'Manga',
        'pages': 300,
        'pagesRead': 140,
      }),
      '/api/Series/metadata' => json({
        'id': 5,
        'summary': 'Thorfinn seeks revenge.',
        'writers': [
          {'id': 1, 'name': 'Makoto Yukimura'},
        ],
        'genres': [
          {'id': 2, 'title': 'Seinen'},
        ],
      }),
      '/api/Series/volumes' => json(volumes),
      _ => ResponseBody.fromBytes(const [], 404),
    };
  }

  @override
  void close({bool force = false}) {}
}

/// Two volumes, each broken into chapters; chapter 3 is half read.
final _volumesWithChapters = <Map<String, dynamic>>[
  {
    'id': 10,
    'name': '1',
    'minNumber': 1,
    'pages': 200,
    'pagesRead': 200,
    'chapters': [_chapter(101, '1', 100, 100), _chapter(102, '2', 100, 100)],
  },
  {
    'id': 11,
    'name': '2',
    'minNumber': 2,
    'pages': 100,
    'pagesRead': 40,
    'chapters': [_chapter(103, '3', 100, 40)],
  },
];

/// One volume per file, so Kavita fills each with a single placeholder
/// chapter numbered -100000.
final _volumesWithoutChapters = <Map<String, dynamic>>[
  {
    'id': 20,
    'name': '1',
    'minNumber': 1,
    'pages': 225,
    'pagesRead': 80,
    'chapters': [
      {
        'id': 201,
        'range': '-100000',
        'minNumber': -100000,
        'pages': 225,
        'pagesRead': 80,
      },
    ],
  },
  {
    'id': 21,
    'name': '2',
    'minNumber': 2,
    'pages': 185,
    'pagesRead': 0,
    'chapters': [
      {
        'id': 202,
        'range': '-100000',
        'minNumber': -100000,
        'pages': 185,
        'pagesRead': 0,
      },
    ],
  },
];

Future<void> _pumpSeries(
  WidgetTester tester,
  List<Map<String, dynamic>> volumes, {
  bool refuse = false,
  LibraryType? libraryType,
  Locale locale = const Locale('en'),
  String seriesName = 'Vinland Saga',
}) async {
  final cacheDir = mockPathProvider();
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _SeriesAdapter(
    volumes,
    refuse: refuse,
    libraryType: libraryType,
    seriesName: seriesName,
  );
  client.bareHttpClient.httpClientAdapter = _SeriesAdapter(
    volumes,
    refuse: refuse,
    libraryType: libraryType,
    seriesName: seriesName,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: cacheDir, profileId: 'https://kavita.test#1'),
        ),
        testCatalogue(profileId: 'https://kavita.test#1'),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SeriesDetailScreen(
          seriesId: 5,
          seriesName: seriesName,
          libraryId: 1,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the hero shows credits, stats and the resume button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpSeries(tester, _volumesWithChapters);

    // Title in the hero (serif) and in the app bar.
    expect(find.text('Vinland Saga'), findsNWidgets(2));
    expect(find.text('Makoto Yukimura · Seinen'), findsOneWidget);
    // Counted in volumes, because that is how the list below is organised.
    expect(find.text('2 volumes · Manga'), findsOneWidget);
    // Chapter 3 is started but unfinished: that is where reading resumes —
    // and the list under the hero opens on it too. The button says what it
    // does and names nothing; chapter 3 is named by the row.
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('READING NOW'), findsOneWidget);
  });

  testWidgets('a title taller than the cover clips rather than overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // The title is serif and three lines deep, and it shares a column pinned
    // to the cover's height with the resume button below it. A title that
    // needs more than the button leaves it used to spill past the hero onto
    // the list beneath — a RenderFlex overflow, "content that cannot be seen"
    // — until the title was given the shrinking end of the column. The pump
    // settling at all is the assertion for that half; the title remaining
    // visible and the button unmoved is the other.
    await _pumpSeries(
      tester,
      _volumesWithChapters,
      seriesName: 'The Long and Winding Title of a Series That Truly Goes On',
    );

    // In the hero and in the app bar.
    expect(
      find.text('The Long and Winding Title of a Series That Truly Goes On'),
      findsNWidgets(2),
    );
    // The button the title shares the column with is untouched.
    expect(find.text('Continue'), findsOneWidget);
    // And with one chapter left there is no batch card under the hero: that
    // is the row's own pill's job.
    expect(find.text("Download what's next"), findsNothing);
  });

  testWidgets('a refused fetch stops the hero shimmering', (tester) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // A failure is not a slow answer: the credits and the tally are never
    // coming, so their skeletons have to stop rather than shimmer for good.
    // `pumpAndSettle` inside `_pumpSeries` is half the assertion — it can
    // only return once nothing is still animating.
    await _pumpSeries(tester, _volumesWithChapters, refuse: true);

    expect(find.byType(Skeleton), findsNothing);
    // What says why is the screen's own failure state, not a placeholder
    // standing in for an answer.
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a volume with no chapters is named by the volume, never by '
      '-100000', (tester) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpSeries(tester, _volumesWithoutChapters);

    // The volume is the reading unit: its row is named after the volume, and
    // the hero is drawn by the volume's own cover.
    expect(find.text('Volume 1'), findsOneWidget);
    expect(
      tester.widget<CoverImage>(find.byType(CoverImage).first).url,
      contains('volume-cover'),
    );
    expect(find.text('2 volumes · Manga'), findsOneWidget);
    expect(
      find.textContaining('-100000'),
      findsNothing,
      reason: "Kavita's sentinel must never reach the UI",
    );
  });

  testWidgets('on a tablet the hero grows but the button stays a button', (
    tester,
  ) async {
    // An iPad in portrait: 820x1180 logical points.
    tester.view.physicalSize = const Size(1640, 2360);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpSeries(tester, _volumesWithChapters);

    // The column runs at the app's own margin rather than being capped and
    // centred: a cap put a narrow column between two wide empty bands, which
    // read as more wrong than the gap it closed inside a row.
    expect(tester.getSize(find.byType(ListView)).width, 820);

    // Left to itself the button fills the hero, which at this size reads as a
    // banner rather than as something to press.
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      lessThanOrEqualTo(280),
    );

    // The cover takes the room a tablet has.
    final cover = tester.getSize(
      find
          .ancestor(
            of: find.byType(CoverImage).first,
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(cover.width, 160);
  });

  group('the page behind the series hero', () {
    // Chapter 3 is half read, so the button resumes a chapter genuinely under
    // way and the hero can show where you are in it.
    testWidgets('is the page the button would resume', (tester) async {
      await _pumpSeries(tester, _volumesWithChapters);
      final backdrop = find.byKey(const ValueKey('heroBackdrop'));
      expect(backdrop, findsOneWidget);
      expect(
        tester.widget<CachedNetworkImage>(backdrop).imageUrl,
        allOf(
          contains('/api/Reader/image'),
          contains('chapterId=103'),
          contains('page=40'),
        ),
      );
    });

    // Nothing has been opened, so the button starts the series rather than
    // resuming it. The first page of something unread is not a backdrop, it
    // is a spoiler with nothing behind it.
    testWidgets('is absent when no chapter is under way', (tester) async {
      await _pumpSeries(tester, [
        {
          'id': 10,
          'name': '1',
          'minNumber': 1,
          'chapters': [_chapter(101, '1', 100, 0)],
        },
      ]);
      expect(find.byKey(const ValueKey('heroBackdrop')), findsNothing);
    });

    // Every chapter finished: the button offers to read it again, and there
    // is no page you are on.
    testWidgets('is absent when the series is finished', (tester) async {
      await _pumpSeries(tester, [
        {
          'id': 10,
          'name': '1',
          'minNumber': 1,
          'chapters': [_chapter(101, '1', 100, 100)],
        },
      ]);
      expect(find.byKey(const ValueKey('heroBackdrop')), findsNothing);
    });
  });

  // The cover follows the backdrop: where the hero is standing inside a
  // chapter, the picture is that chapter's rather than the series'. A series
  // cover over a page of the chapter you are in names the wrong thing.
  group('the cover on the series hero', () {
    CoverImage hero(WidgetTester tester) =>
        tester.widget<CoverImage>(find.byType(CoverImage).first);

    testWidgets('is the cover of the chapter under way', (tester) async {
      await _pumpSeries(tester, _volumesWithChapters);
      expect(
        hero(tester).url,
        allOf(contains('/api/Image/chapter-cover'), contains('chapterId=103')),
      );
    });

    // The bar under a cover always means "how far through the thing pictured",
    // which is the rule every chapter row and series tile already follows.
    testWidgets('and carries that chapter\'s progress', (tester) async {
      await _pumpSeries(tester, _volumesWithChapters);
      // Chapter 3 is 40 of 100; the series is 140 of 300.
      expect(hero(tester).progress, closeTo(0.4, 0.001));
    });

    // A volume with no chapter breakdown is the reading unit, so it is drawn
    // by its own cover — the same choice the rows below make, which is also
    // what keeps the two on one cached image rather than two.
    testWidgets('is the volume cover where the volume is the unit', (
      tester,
    ) async {
      await _pumpSeries(tester, _volumesWithoutChapters);
      expect(
        hero(tester).url,
        allOf(contains('/api/Image/volume-cover'), contains('volumeId=20')),
      );
    });

    // A whole volume finished and the next untouched: the button resumes at
    // that next volume, and the cover is its — where the backdrop, which
    // refuses an unopened page, still draws nothing.
    testWidgets('is the next volume\'s cover after finishing one', (
      tester,
    ) async {
      await _pumpSeries(tester, [
        {
          'id': 10,
          'name': '1',
          'minNumber': 1,
          'chapters': [_chapter(101, '1', 100, 100)],
        },
        {
          'id': 11,
          'name': '2',
          'minNumber': 2,
          'chapters': [_chapter(102, '2', 100, 0)],
        },
      ]);
      expect(
        hero(tester).url,
        allOf(contains('/api/Image/chapter-cover'), contains('chapterId=102')),
      );
      expect(hero(tester).progress, 0.0);
      expect(find.byKey(const ValueKey('heroBackdrop')), findsNothing);
    });

    testWidgets('stays the series cover when nothing has been read', (
      tester,
    ) async {
      await _pumpSeries(tester, [
        {
          'id': 10,
          'name': '1',
          'minNumber': 1,
          'chapters': [_chapter(101, '1', 100, 0)],
        },
      ]);
      expect(
        hero(tester).url,
        allOf(contains('/api/Image/series-cover'), contains('seriesId=5')),
      );
    });

    testWidgets('and is the series cover again once everything is read', (
      tester,
    ) async {
      await _pumpSeries(tester, [
        {
          'id': 10,
          'name': '1',
          'minNumber': 1,
          'chapters': [_chapter(101, '1', 100, 100)],
        },
      ]);
      expect(hero(tester).url, contains('/api/Image/series-cover'));
    });
  });

  // A book is one reading unit Kavita paginates itself (ADR-0008), and every
  // number on this screen comes off the pages it counted: the ring on the
  // cover is how far through the book is, as it is for a chapter.
  group('a book on the series screen', () {
    /// One book, 120 of 300 pages read, in a Book library — the shape Kavita
    /// gives a file that is a whole book: a volume with a single placeholder
    /// chapter standing in for it, carrying the format that makes its pages
    /// the server's.
    final bookVolumes = [
      {
        'id': 30,
        'name': '1',
        'minNumber': 1,
        'pages': 300,
        'pagesRead': 120,
        'chapters': [
          {
            'id': 301,
            'range': '-100000',
            'minNumber': -100000,
            'pages': 300,
            'pagesRead': 120,
            'format': MangaFormat.epub.id,
          },
        ],
      },
    ];

    testWidgets('the cover carries the book\'s progress', (tester) async {
      await _pumpSeries(tester, bookVolumes, libraryType: LibraryType.book);

      final cover = tester.widget<CoverImage>(find.byType(CoverImage).first);
      // The book is 120 of 300, and the series' own tally is a different
      // number (the adapter's 140 of 300): the bar follows the picture,
      // which is the book's.
      expect(cover.progress, closeTo(0.4, 0.001));
    });
    // A book has no page picture to draw, so what stands behind the hero is
    // the cover rather than a request that can only come back empty.
    testWidgets('draws the cover behind the hero, not a page', (tester) async {
      await _pumpSeries(tester, bookVolumes, libraryType: LibraryType.book);

      expect(
        tester
            .widget<CachedNetworkImage>(
              find.byKey(const ValueKey('heroBackdrop')),
            )
            .imageUrl,
        contains('/api/Image/series-cover'),
      );
    });

    // The button names nothing; what the book is called comes from the
    // library's own vocabulary, on the row below it — a Book library's is
    // "livre" in French, never a chapter, which is the word a manga shelf
    // uses for the same thing.
    testWidgets('is named by the row, in the library\'s own unit', (
      tester,
    ) async {
      await _pumpSeries(tester, bookVolumes, libraryType: LibraryType.book);

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Book 1'), findsOneWidget);
      expect(find.textContaining('-100000'), findsNothing);
    });

    testWidgets('and in French calls it a livre', (tester) async {
      await _pumpSeries(
        tester,
        bookVolumes,
        libraryType: LibraryType.book,
        locale: const Locale('fr'),
      );

      expect(find.text('Reprendre'), findsOneWidget);
      expect(find.text('Livre 1'), findsOneWidget);
    });
  });
}
