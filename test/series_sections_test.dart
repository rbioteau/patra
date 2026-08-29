import 'dart:async';
import 'dart:convert';

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

import 'test_support.dart';

Map<String, dynamic> _chapter(
  int id,
  String range, {
  num? sortOrder,
  bool isSpecial = false,
  String title = '',
  String titleName = '',
  int pagesRead = 0,
  int format = 1,
}) => {
  'id': id,
  'range': range,
  'title': title,
  'titleName': titleName,
  'minNumber': num.tryParse(range) ?? 0,
  'sortOrder': sortOrder ?? num.tryParse(range) ?? 0,
  'isSpecial': isSpecial,
  'format': format,
  'pages': 100,
  'pagesRead': pagesRead,
};

/// A volume, a chapter with no volume, and a special: the three shapes a
/// Kavita series is made of, told apart by the sign of the pseudo-volumes.
final _mixedSeries = <Map<String, dynamic>>[
  {
    'id': 10,
    'name': '1',
    'minNumber': 1,
    'pages': 200,
    'chapters': [_chapter(101, '2'), _chapter(102, '1')],
  },
  {
    'id': 11,
    'name': '-100000',
    'minNumber': -100000,
    'pages': 100,
    'chapters': [_chapter(103, '12')],
  },
  {
    'id': 12,
    'name': '100000',
    'minNumber': 100000,
    'pages': 40,
    'chapters': [_chapter(104, '', isSpecial: true, title: 'Omake')],
  },
];

final _volumesOnly = <Map<String, dynamic>>[
  {
    'id': 10,
    'name': '1',
    'minNumber': 1,
    'pages': 200,
    'chapters': [_chapter(101, '1')],
  },
];

class _Adapter implements HttpClientAdapter {
  _Adapter(
    this.volumes,
    this.libraryType, {
    this.onPost,
    this.postGate,
    this.postStatus = 200,
  });

  final List<Map<String, dynamic>> volumes;
  final LibraryType libraryType;
  final void Function(RequestOptions options)? onPost;

  /// Holds the write open, so a test can look at the screen while the server
  /// has not answered yet.
  final Future<void>? postGate;
  final int postStatus;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    if (options.method == 'POST') {
      onPost?.call(options);
      if (postGate != null) await postGate;
      if (postStatus != 200) {
        return ResponseBody.fromBytes(const [], postStatus);
      }
      return json(const <String, dynamic>{});
    }
    return switch (options.path) {
      '/api/Library/libraries' => json([
        {'id': 1, 'name': 'Shelf', 'type': libraryType.id},
      ]),
      '/api/Series/7' => json({
        'id': 7,
        'name': 'Berserk',
        'libraryId': 1,
        'libraryName': 'Shelf',
        'pages': 340,
        'pagesRead': 0,
      }),
      '/api/Series/metadata' => json({'id': 7}),
      '/api/Series/volumes' => json(volumes),
      _ => ResponseBody.fromBytes(const [], 404),
    };
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> volumes, {
  LibraryType type = LibraryType.manga,
  Locale locale = const Locale('en'),
  void Function(RequestOptions options)? onPost,
  Future<void>? postGate,
  int postStatus = 200,
  bool underNavigator = false,
}) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final cacheDir = mockPathProvider();
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
  );
  final adapter = _Adapter(
    volumes,
    type,
    onPost: onPost,
    postGate: postGate,
    postStatus: postStatus,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;

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
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: underNavigator
            ? const _PushHost()
            : const SeriesDetailScreen(
                seriesId: 7,
                seriesName: 'Berserk',
                libraryId: 1,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (underNavigator) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

/// Puts the screen on a route that can be popped, so a test can leave it.
class _PushHost extends StatelessWidget {
  const _PushHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SeriesDetailScreen(
              seriesId: 7,
              seriesName: 'Berserk',
              libraryId: 1,
            ),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('volumes and volumeless chapters read as one storyline', (
    tester,
  ) async {
    await _pump(tester, _mixedSeries);

    // Volumes plus loose chapters is exactly what Kavita calls the storyline,
    // so the block takes that name and the chapters need no header of theirs.
    expect(find.text('STORYLINE'), findsOneWidget);
    expect(find.text('VOLUMES'), findsNothing);
    expect(find.text('CHAPTERS'), findsNothing);
    expect(find.text('SPECIALS'), findsOneWidget);
    // The specials pseudo-volume is never a volume of the series.
    expect(find.textContaining('100000'), findsNothing);
    expect(find.text('Omake'), findsOneWidget);
  });

  testWidgets('chapters follow sortOrder, not the order of the array', (
    tester,
  ) async {
    // Volume 1 is served chapter 2 first: Kavita orders every list it builds
    // on sortOrder, and the array is not it.
    await _pump(tester, _mixedSeries);

    expect(
      tester.getTopLeft(find.text('Chapter 1')).dy,
      lessThan(tester.getTopLeft(find.text('Chapter 2')).dy),
    );
  });

  testWidgets('a run of volumes alone stays a run of volumes', (tester) async {
    await _pump(tester, _volumesOnly);

    expect(find.text('VOLUMES'), findsOneWidget);
    expect(find.text('STORYLINE'), findsNothing);
  });

  testWidgets('a comic has issues and never a storyline', (tester) async {
    await _pump(tester, _mixedSeries, type: LibraryType.comic);

    expect(find.text('STORYLINE'), findsNothing);
    expect(find.text('VOLUMES'), findsOneWidget);
    expect(find.text('ISSUES'), findsOneWidget);
    expect(find.text('Issue #12'), findsOneWidget);
  });

  testWidgets('a book library counts books', (tester) async {
    await _pump(tester, _volumesOnly, type: LibraryType.book);

    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('Volume 1'), findsNothing);
  });

  testWidgets('the French glossary reaches the screen', (tester) async {
    await _pump(tester, _mixedSeries, locale: const Locale('fr'));

    expect(find.text('ARC NARRATIF'), findsOneWidget);
    expect(find.text('HORS-SÉRIE'), findsOneWidget);
    expect(find.text('Tome 1'), findsOneWidget);
    expect(find.text('Chapitre 12'), findsOneWidget);
  });

  testWidgets('a comic in French counts numéros', (tester) async {
    await _pump(
      tester,
      _mixedSeries,
      type: LibraryType.comicVine,
      locale: const Locale('fr'),
    );

    expect(find.text('NUMÉROS'), findsOneWidget);
    expect(find.text('Numéro #12'), findsOneWidget);
    expect(find.text('ARC NARRATIF'), findsNothing);
  });

  testWidgets('a PDF reads like any other chapter', (tester) async {
    // Kavita rasterises it into page images on demand, so nothing about the
    // row changes: it opens, and it can be saved.
    await _pump(tester, [
      {
        'id': 10,
        'name': '-100000',
        'minNumber': -100000,
        'pages': 100,
        'chapters': [_chapter(101, '1', format: 4)],
      },
    ]);

    expect(find.text('Format not supported yet'), findsNothing);
    final row = tester.widget<InkWell>(
      find.ancestor(of: find.text('Chapter 1'), matching: find.byType(InkWell)),
    );
    expect(row.onTap, isNotNull);
  });

  testWidgets('an EPUB chapter says so instead of opening a broken reader', (
    tester,
  ) async {
    await _pump(tester, [
      {
        'id': 10,
        'name': '-100000',
        'minNumber': -100000,
        'pages': 100,
        'chapters': [_chapter(101, '1', format: 3)],
      },
    ]);

    expect(find.text('Format not supported yet'), findsOneWidget);
    final row = tester.widget<InkWell>(
      find.ancestor(of: find.text('Chapter 1'), matching: find.byType(InkWell)),
    );
    expect(row.onTap, isNull);
  });

  group('the resume button names only what is numbered', () {
    // A book library's files often carry a title and no number at all: this
    // is the case that has nothing short to show.
    final startedSpecial = <Map<String, dynamic>>[
      {
        'id': 12,
        'name': '100000',
        'minNumber': 100000,
        'pages': 100,
        'chapters': [
          _chapter(
            104,
            '',
            isSpecial: true,
            titleName: 'The Winter Soldier',
            pagesRead: 40,
          ),
        ],
      },
    ];

    testWidgets('a title never reaches the button', (tester) async {
      // A book title is free text and would stretch the button across the
      // hero; it is already on the row the button opens.
      await _pump(tester, startedSpecial, type: LibraryType.book);

      expect(find.text('Continue'), findsOneWidget);
      expect(find.textContaining('The Winter Soldier'), findsOneWidget);
      expect(find.text('Continue — The Winter Soldier'), findsNothing);
    });

    testWidgets('and no title in French either', (tester) async {
      await _pump(
        tester,
        startedSpecial,
        type: LibraryType.book,
        locale: const Locale('fr'),
      );

      expect(find.text('Reprendre'), findsOneWidget);
      expect(find.textContaining('Reprendre —'), findsNothing);
    });

    testWidgets('a numbered chapter is named by its number, not its title', (
      tester,
    ) async {
      // Kavita does the same: the title only stands in where there is no
      // number to show.
      await _pump(tester, [
        {
          'id': 10,
          'name': '-100000',
          'minNumber': -100000,
          'pages': 100,
          'chapters': [
            _chapter(101, '3', titleName: 'The Duel', pagesRead: 40),
          ],
        },
      ]);

      expect(find.text('Continue — Ch. 3'), findsOneWidget);
    });
  });

  group('swiping a row marks it read', () {
    Map<String, dynamic> chapterRead(int pagesRead) =>
        _chapter(101, '1', pagesRead: pagesRead);

    List<Map<String, dynamic>> series(int pagesRead) => [
      {
        'id': 10,
        'name': '1',
        'minNumber': 1,
        'pages': 100,
        'chapters': [chapterRead(pagesRead)],
      },
    ];

    testWidgets('an unread chapter offers to be marked read', (tester) async {
      RequestOptions? posted;
      await _pump(tester, series(0), onPost: (options) => posted = options);

      // The leading edge carries progress; the trailing one carries removal.
      await tester.drag(find.text('Chapter 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Mark read'), findsOneWidget);

      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();

      expect(posted!.path, '/api/Reader/mark-multiple-read');
      final body = posted!.data as Map<String, dynamic>;
      expect(body['seriesId'], 7);
      expect(body['chapterIds'], [101]);
      // The server reads it unconditionally, so it must be there.
      expect(body['volumeIds'], isEmpty);
    });

    testWidgets('a read chapter offers the other direction', (tester) async {
      RequestOptions? posted;
      await _pump(tester, series(100), onPost: (options) => posted = options);

      await tester.drag(find.text('Chapter 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Mark unread'), findsOneWidget);

      await tester.tap(find.text('Mark unread'));
      await tester.pumpAndSettle();

      expect(posted!.path, '/api/Reader/mark-multiple-unread');
      expect((posted!.data as Map<String, dynamic>)['chapterIds'], [101]);
    });

    testWidgets('the action speaks French too', (tester) async {
      await _pump(tester, series(0), locale: const Locale('fr'));

      await tester.drag(find.text('Chapitre 1'), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Marquer lu'), findsOneWidget);
    });

    testWidgets('an open pane is a drawer, not half a tablet row', (
      tester,
    ) async {
      // An iPad in portrait: 820x1180 logical points.
      tester.view.physicalSize = const Size(1640, 2360);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, series(0));

      final before = tester.getTopLeft(find.text('Chapter 1')).dx;
      await tester.drag(find.text('Chapter 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Mark read'), findsOneWidget);

      // Sized as a share of the row, the pane would carry the row a quarter
      // of the screen away and take the cover and the title with it — the
      // swipe would hide the very thing it is about to act on.
      final shift = tester.getTopLeft(find.text('Chapter 1')).dx - before;
      expect(shift, greaterThan(0));
      expect(shift, lessThan(160));
    });
  });

  group('the row does not wait for the server', () {
    Future<void> swipeAndMark(WidgetTester tester) async {
      await tester.drag(find.text('Chapter 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark read'));
    }

    final unread = <Map<String, dynamic>>[
      {
        'id': 10,
        'name': '1',
        'minNumber': 1,
        'pages': 100,
        'chapters': [_chapter(101, '1', pagesRead: 0)],
      },
    ];

    testWidgets('the row reads as read while the write is still in flight', (
      tester,
    ) async {
      final gate = Completer<void>();
      await _pump(tester, unread, postGate: gate.future);

      expect(find.text('READ'), findsNothing);
      await swipeAndMark(tester);
      await tester.pump();

      // The server has not answered — and will not until the gate opens.
      expect(find.text('READ'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('READ'), findsOneWidget);
    });

    testWidgets('a refused write puts the row back', (tester) async {
      final gate = Completer<void>();
      await _pump(tester, unread, postGate: gate.future, postStatus: 400);

      await swipeAndMark(tester);
      await tester.pump();
      expect(find.text('READ'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      // The server refused, so the screen goes back to what it knows.
      expect(find.text('READ'), findsNothing);
    });
  });

  group('the button knows the series is under way', () {
    Map<String, dynamic> volume(
      int id,
      String name,
      int pages,
      int pagesRead,
    ) => {
      'id': id,
      'name': name,
      'minNumber': int.parse(name),
      'pages': pages,
      'pagesRead': pagesRead,
      // One file per volume: Kavita fills it with a single placeholder
      // chapter, and the volume itself is the reading unit.
      'chapters': [
        {
          'id': 100 + id,
          'range': '-100000',
          'minNumber': -100000,
          'pages': pages,
          'pagesRead': pagesRead,
        },
      ],
    };

    testWidgets('a finished volume hands over to the next one', (tester) async {
      // The next volume is untouched, but the series is plainly under way:
      // asking the target chapter alone said "Start reading" to someone
      // halfway through a series.
      await _pump(tester, [volume(1, '1', 200, 200), volume(2, '2', 180, 0)]);

      expect(find.text('Continue — Vol. 2'), findsOneWidget);
      expect(find.text('Start reading'), findsNothing);
    });

    testWidgets('an untouched series still starts', (tester) async {
      await _pump(tester, [volume(1, '1', 200, 0), volume(2, '2', 180, 0)]);

      expect(find.text('Start reading'), findsOneWidget);
    });

    testWidgets('a finished series offers to be read again', (tester) async {
      await _pump(tester, [volume(1, '1', 200, 200), volume(2, '2', 180, 180)]);

      expect(find.text('Read again'), findsOneWidget);
    });
  });

  group('no chapter is unreachable', () {
    testWidgets('a chapter filed under specials without the flag still shows', (
      tester,
    ) async {
      // Kavita flags everything it files there, but a chapter that arrives
      // without the flag must still have a row — otherwise it can be neither
      // opened nor saved, and nothing on screen says it exists.
      await _pump(tester, [
        {
          'id': 12,
          'name': '100000',
          'minNumber': 100000,
          'pages': 100,
          'chapters': [_chapter(104, '7')],
        },
      ]);

      expect(find.text('Chapter 7'), findsOneWidget);
      expect(find.text('CHAPTERS'), findsOneWidget);
    });

    testWidgets('a special inside a numbered volume is listed once', (
      tester,
    ) async {
      await _pump(tester, [
        {
          'id': 10,
          'name': '1',
          'minNumber': 1,
          'pages': 200,
          'chapters': [
            _chapter(101, '1'),
            _chapter(102, '', isSpecial: true, title: 'Omake'),
          ],
        },
      ]);

      expect(find.text('SPECIALS'), findsOneWidget);
      expect(find.text('Omake'), findsOneWidget);
      expect(find.text('Chapter 1'), findsOneWidget);
    });
  });

  testWidgets('leaving before the server answers is not an error', (
    tester,
  ) async {
    // The override lives with the screen; writing to it after the screen is
    // gone would throw where nothing is left to catch it.
    final gate = Completer<void>();
    await _pump(
      tester,
      [
        {
          'id': 10,
          'name': '1',
          'minNumber': 1,
          'pages': 100,
          'chapters': [_chapter(101, '1')],
        },
      ],
      postGate: gate.future,
      postStatus: 400,
      underNavigator: true,
    );

    await tester.drag(find.text('Chapter 1'), const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark read'));
    await tester.pump();

    // Back out while the write is still in flight, then let it fail.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
