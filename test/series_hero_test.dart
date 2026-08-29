import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
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
  _SeriesAdapter(this.volumes);

  final List<Map<String, dynamic>> volumes;

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
    return switch (options.path) {
      '/api/Series/5' => json({
        'id': 5,
        'name': 'Vinland Saga',
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
  List<Map<String, dynamic>> volumes,
) async {
  final cacheDir = mockPathProvider();
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _SeriesAdapter(volumes);
  client.refreshHttpClient.httpClientAdapter = _SeriesAdapter(volumes);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: cacheDir),
        ),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SeriesDetailScreen(
          seriesId: 5,
          seriesName: 'Vinland Saga',
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
    // Chapter 3 is started but unfinished: that is where reading resumes.
    expect(find.text('Continue — Ch. 3'), findsOneWidget);
    expect(find.text('VOLUMES'), findsOneWidget);
  });

  testWidgets('a volume with no chapters is named, never numbered -100000', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpSeries(tester, _volumesWithoutChapters);

    expect(find.text('Continue — Vol. 1'), findsOneWidget);
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

    // The screen is a column, not a canvas: it stops growing well short of
    // the iPad's width.
    final hero = tester.getSize(find.byType(ListView));
    expect(hero.width, lessThanOrEqualTo(contentMaxWidth));

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
}
