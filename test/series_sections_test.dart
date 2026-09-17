import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/series/series_detail_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/cover.dart';
import 'package:patra/src/widgets/read_mark.dart';
import 'package:patra/src/widgets/save_pill.dart';

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

/// What a finished row says, in the words it says it in.
///
/// The mark used to be a `READ` tag pinned beside the title and a check badge
/// on the cover; it is now the row's own metadata line, in the accent. Every
/// chapter of these fixtures is 100 pages long.
const _read = 'Read · 100 pages';

class _Adapter implements HttpClientAdapter {
  _Adapter(
    this.volumes,
    this.libraryType, {
    this.onPost,
    this.postGate,
    this.postStatus = 200,
  });

  /// What the server says the series is made of. Mutable, so a test can
  /// change what reading did to it while the reader was open.
  List<Map<String, dynamic>> volumes;

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

/// Mounts the series screen and answers for it, handing back the adapter so a
/// test can change what the server says while the screen is up.
///
/// [routed] puts it under a router with the reader on it, so a row's tap can
/// be followed and *come back* — which is what the screen asks the server
/// again for.
Future<_Adapter> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> volumes, {
  LibraryType type = LibraryType.manga,
  Locale locale = const Locale('en'),
  void Function(RequestOptions options)? onPost,
  Future<void>? postGate,
  int postStatus = 200,
  bool underNavigator = false,
  int? savedChapter,
  bool tablet = false,
  bool routed = false,
}) async {
  // The size belongs to `_pump`: setting it in a caller before this ran was
  // silently overwritten, which left every "tablet" test on a 550pt phone.
  // An iPad in portrait is 820x1180 logical points; the default is a phone.
  tester.view.physicalSize = tablet
      ? const Size(1640, 2360)
      : const Size(1100, 2600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final cacheDir = mockPathProvider();
  if (savedChapter != null) {
    // A stored copy, which is what puts the remove action on the row's
    // trailing edge — written through the service, so it lands under the
    // profile that saved it.
    await saveChapterFixture(
      Directory('${cacheDir.path}/downloads'),
      _profileId,
      chapterId: savedChapter,
      seriesId: 7,
      volumeId: 10,
      seriesName: 'Berserk',
      pages: 1,
      bytes: 1,
    );
  }
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
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
  client.bareHttpClient.httpClientAdapter = adapter;
  final theme = patraTheme();
  final delegates = AppLocalizations.localizationsDelegates;
  final locales = AppLocalizations.supportedLocales;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(
            root: Directory('${cacheDir.path}/downloads'),
            profileId: _profileId,
          ),
        ),
        testCatalogue(profileId: _profileId),
      ],
      child: routed
          ? MaterialApp.router(
              theme: theme,
              locale: locale,
              localizationsDelegates: delegates,
              supportedLocales: locales,
              routerConfig: _readerRouter(),
            )
          : MaterialApp(
              theme: theme,
              locale: locale,
              localizationsDelegates: delegates,
              supportedLocales: locales,
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
  return adapter;
}

/// The reader as a route, so a row can be tapped into it and back.
GoRouter _readerRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const SeriesDetailScreen(
        seriesId: 7,
        seriesName: 'Berserk',
        libraryId: 1,
      ),
    ),
    GoRoute(
      path: '/reader/:chapterId',
      builder: (_, state) =>
          Text('reader ${state.pathParameters['chapterId']}'),
    ),
  ],
);

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

/// Whose store the fixtures go in: the service is handed to the provider
/// directly here, so the profile it belongs to is named rather than resolved
/// from a session.
const _profileId = 'https://kavita.test#1';

/// The copy that promised EPUB support is going away: the key the screen read
/// it from, and the sentence itself.
const _retiredCopy = ['formatNotSupported', 'EPUB support'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('volumes and volumeless chapters read as one storyline', (
    tester,
  ) async {
    // The sections are the sectioned view's: the screen opens grouped by
    // reading position, and `showSections` is the pill that asks for them.
    await _pump(tester, _mixedSeries);
    await showSections(tester);

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
    await showSections(tester);

    expect(find.text('VOLUMES'), findsOneWidget);
    expect(find.text('STORYLINE'), findsNothing);
  });

  testWidgets('a comic has issues and never a storyline', (tester) async {
    await _pump(tester, _mixedSeries, type: LibraryType.comic);
    await showSections(tester);

    expect(find.text('STORYLINE'), findsNothing);
    expect(find.text('VOLUMES'), findsOneWidget);
    expect(find.text('ISSUES'), findsOneWidget);
    expect(find.text('Issue #12'), findsOneWidget);
  });

  testWidgets('a book library counts books', (tester) async {
    await _pump(tester, _volumesOnly, type: LibraryType.book);
    await showSections(tester);

    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('Volume 1'), findsNothing);
  });

  testWidgets('the French glossary reaches the screen', (tester) async {
    await _pump(tester, _mixedSeries, locale: const Locale('fr'));
    await showSections(tester);

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
    await showSections(tester);

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

    final row = tester.widget<InkWell>(
      find.ancestor(of: find.text('Chapter 1'), matching: find.byType(InkWell)),
    );
    expect(row.onTap, isNotNull);
  });

  testWidgets('a book opens like any other chapter', (tester) async {
    // In a Book library, which is where a book lives: the reader asks the
    // server for the pages it made of the file's words.
    await _pump(
      tester,
      [
        {
          'id': 10,
          'name': '-100000',
          'minNumber': -100000,
          'pages': 100,
          'chapters': [_chapter(101, '1', format: 3)],
        },
      ],
      type: LibraryType.book,
      routed: true,
    );

    // Neither dimmed: 0.4 is what this screen draws over a row it will not
    // open. What says the format cannot be read is guarded over `lib/`
    // rather than here, since a sentence that exists nowhere is one this
    // test could never catch.
    expect(rowOpacity(tester, 'Book 1'), 1);

    await tester.tap(find.text('Book 1'));
    await tester.pumpAndSettle();
    expect(find.text('reader 101'), findsOneWidget);
  });

  // How far through a book is, is the same arithmetic as a chapter: the
  // pages the server counted, and the ones read of them.
  testWidgets('a book under way carries the bar of its progress', (
    tester,
  ) async {
    await _pump(tester, [
      {
        'id': 10,
        'name': '-100000',
        'minNumber': -100000,
        'pages': 100,
        'chapters': [_chapter(101, '1', format: 3, pagesRead: 40)],
      },
    ], type: LibraryType.book);

    expect(find.text('Page 40 / 100'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.4, 0.001));
    // Reading progress, which is the accent's job everywhere in this app.
    expect(bar.valueColor?.value, patraAccent);
  });

  // The last page posts the whole book, which is what the server counts as
  // read — so coming back has to ask: the rows and the hero are drawn from
  // what it says, and a screen that kept its own copy would keep a finished
  // book under way.
  testWidgets('a book read through is read on the way back', (tester) async {
    final adapter = await _pump(
      tester,
      [
        {
          'id': 10,
          'name': '-100000',
          'minNumber': -100000,
          'pages': 100,
          'chapters': [_chapter(101, '1', format: 3, pagesRead: 40)],
        },
      ],
      type: LibraryType.book,
      routed: true,
    );
    expect(find.text('Page 40 / 100'), findsOneWidget);

    // The book was finished while the reader was open.
    adapter.volumes = [
      {
        'id': 10,
        'name': '-100000',
        'minNumber': -100000,
        'pages': 100,
        'chapters': [_chapter(101, '1', format: 3, pagesRead: 100)],
      },
    ];
    await tester.tap(find.text('Book 1'));
    await tester.pumpAndSettle();
    expect(find.text('reader 101'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    // Read, without a second visit: the bar that was there is gone, and the
    // row says so in its own words.
    expect(find.text(_read), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  // A book is one reading unit the server paginates itself (ADR-0008), and
  // nothing about the row changes because of it: the same swipe marks it, and
  // the same vocabulary names it.
  group('a book behaves like any other row', () {
    /// One book in a Book library: a volume of its own holding the single
    /// placeholder chapter Kavita stands in for a file that is a whole book.
    List<Map<String, dynamic>> book(int pagesRead) => [
      {
        'id': 10,
        'name': '1',
        'minNumber': 1,
        'pages': 100,
        'chapters': [_chapter(101, '-100000', format: 3, pagesRead: pagesRead)],
      },
    ];

    testWidgets('the leading swipe marks it read before the server answers', (
      tester,
    ) async {
      final gate = Completer<void>();
      await _pump(
        tester,
        book(0),
        type: LibraryType.book,
        postGate: gate.future,
      );

      // The leading edge carries progress, as it does on a chapter.
      await tester.drag(find.text('Book 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Mark read'), findsOneWidget);

      await tester.tap(find.text('Mark read'));
      await tester.pump();

      // The server has not answered — and will not until the gate opens.
      expect(find.text(_read), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(_read), findsOneWidget);
    });

    testWidgets('and posts the book to the server, both ways', (tester) async {
      final posted = <String>[];
      RequestOptions? last;
      await _pump(
        tester,
        book(0),
        type: LibraryType.book,
        // Every POST the screen makes lands here, the series listing among
        // them: only the write is what this test is about.
        onPost: (options) {
          if (!options.path.startsWith('/api/Reader/mark-multiple')) return;
          posted.add(options.path);
          last = options;
        },
      );

      await tester.drag(find.text('Book 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();

      expect(posted, ['/api/Reader/mark-multiple-read']);
      // The book is one chapter to the server, and it is that chapter's id
      // that goes up — there is no book of its own to mark.
      expect((last!.data as Map<String, dynamic>)['chapterIds'], [101]);

      // Read now, so the same edge offers the other direction.
      await tester.drag(find.text('Book 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark unread'));
      await tester.pumpAndSettle();

      expect(posted, [
        '/api/Reader/mark-multiple-read',
        '/api/Reader/mark-multiple-unread',
      ]);
    });

    testWidgets('the trailing swipe still removes a saved copy', (
      tester,
    ) async {
      // The pane keys on a copy being here and never on the format, so a
      // book already on the device is removed like anything else.
      await _pump(tester, book(0), type: LibraryType.book, savedChapter: 101);

      await tester.drag(find.text('Book 1'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('the row offers to save the book', (tester) async {
      // A book is saved the way any other chapter is: what is stored is a
      // copy of the pages the server rendered, and the pill asks for one.
      await _pump(tester, book(0), type: LibraryType.book);

      expect(find.byType(SavePill), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('offline a book that is not here cannot be opened', (
      tester,
    ) async {
      // Reading a book is reading the server's pages, so a copy that is not
      // on the device is a book there is nothing to open — and offering to
      // fetch one is offering what cannot be done.
      await _pump(tester, book(0), type: LibraryType.book);
      ProviderScope.containerOf(tester.element(find.byType(SeriesDetailScreen)))
          .read(offlineProvider.notifier)
          .set(true);
      await tester.pumpAndSettle();

      expect(rowOpacity(tester, 'Book 1'), 0.4);
      expect(find.byType(SavePill), findsNothing);
    });

    testWidgets('offline there is nothing to swipe for', (tester) async {
      // Marking read is a write to the server, and a book is no exception:
      // the pane is not drawn at all rather than drawn and refused.
      await _pump(tester, book(0), type: LibraryType.book);
      ProviderScope.containerOf(tester.element(find.byType(SeriesDetailScreen)))
          .read(offlineProvider.notifier)
          .set(true);
      await tester.pumpAndSettle();

      await tester.drag(find.text('Book 1'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Mark read'), findsNothing);
    });

    testWidgets('the row names it in the library\'s own word', (tester) async {
      await _pump(
        tester,
        book(40),
        type: LibraryType.book,
        locale: const Locale('fr'),
      );

      // A bare "chapitre" over a book is the server's vocabulary spoken
      // wrong, which is the mistake `LibraryTypeNaming` exists to prevent.
      expect(find.text('Livre 1'), findsOneWidget);
      expect(find.textContaining('Chapitre'), findsNothing);
    });

    test('nothing in the app still promises EPUB support', () {
      // The row used to be dimmed and labelled "Format not supported yet",
      // and the series screen told the reader EPUB support was on the way.
      // A row that opens has said all of that: what is guarded here is that
      // neither sentence can come back, in the tree or in the copy.
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File) continue;
        if (!file.path.endsWith('.dart') && !file.path.endsWith('.arb')) {
          continue;
        }
        final source = file.readAsStringSync();
        if (_retiredCopy.any(source.contains)) offenders.add(file.path);
      }
      expect(offenders, isEmpty);
    });
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

    testWidgets('the remove pane takes its width out of the row', (
      tester,
    ) async {
      // Sliding the row aside to uncover the pane hides the cover and the
      // title — the swipe covers up the very thing it is about to act on. The
      // pane takes its width from the row instead, so the row keeps its
      // origin and every part of itself.
      await _pump(tester, series(0), savedChapter: 101);

      final before = tester.getRect(find.text('Chapter 1'));
      await tester.drag(find.text('Chapter 1'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsOneWidget);

      expect(
        tester.getRect(find.text('Chapter 1')).left,
        moreOrLessEquals(before.left, epsilon: 0.5),
      );
      // And the row stops where the pane starts rather than running under it:
      // the save pill is still whole, and still on the row's side of it.
      expect(
        tester.getRect(find.byType(SavePill)).right,
        lessThanOrEqualTo(tester.getRect(find.text('Remove')).left),
      );
    });

    testWidgets('an open pane is a drawer, not half a tablet row', (
      tester,
    ) async {
      await _pump(tester, series(0), tablet: true);

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

  // Read is a positive signal here, in the accent that already means reading
  // progress: a rail on the row's leading edge and the word in the row's own
  // metadata. Nothing is added to the row and nothing recedes — a lowered
  // opacity already means *unavailable* in this app, which says the opposite.
  group('a finished row is marked, not erased', () {
    final mixed = <Map<String, dynamic>>[
      {
        'id': 10,
        'name': '1',
        'minNumber': 1,
        'pages': 100,
        'chapters': [_chapter(101, '1', pagesRead: 100)],
      },
      {
        'id': 11,
        'name': '2',
        'minNumber': 2,
        'pages': 100,
        'chapters': [_chapter(102, '2', pagesRead: 0)],
      },
    ];

    Finder rails() =>
        find.byWidgetPredicate((widget) => widget is ReadRail && widget.read);

    testWidgets('the read row carries the rail, and only it', (tester) async {
      await _pump(tester, mixed);
      await showSections(tester);

      expect(find.text(_read), findsOneWidget);
      expect(rails(), findsOneWidget);
      // The mark the rail replaces, on the cover and beside the title.
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('READ'), findsNothing);
    });

    // The word is inside the sentence rather than concatenated onto the
    // count, so French orders it its own way rather than English's.
    testWidgets('and says it in French too', (tester) async {
      await _pump(tester, mixed, locale: const Locale('fr'));
      await showSections(tester);

      expect(find.text('Lu · 100 pages'), findsOneWidget);
      expect(find.text('LU'), findsNothing);
    });

    testWidgets('its title is not muted, and its cover has not moved', (
      tester,
    ) async {
      await _pump(tester, mixed);
      await showSections(tester);

      final read = tester.widget<Text>(find.text('Chapter 1'));
      expect(read.style?.color, patraText);

      // The rail is taken out of the gutter: the two rows line up.
      expect(
        tester.getTopLeft(find.text('Chapter 1')).dx,
        tester.getTopLeft(find.text('Chapter 2')).dx,
      );
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

      expect(find.text(_read), findsNothing);
      await swipeAndMark(tester);
      await tester.pump();

      // The server has not answered — and will not until the gate opens.
      expect(find.text(_read), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(_read), findsOneWidget);
    });

    testWidgets('a refused write puts the row back', (tester) async {
      final gate = Completer<void>();
      await _pump(tester, unread, postGate: gate.future, postStatus: 400);

      await swipeAndMark(tester);
      await tester.pump();
      expect(find.text(_read), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      // The server refused, so the screen goes back to what it knows.
      expect(find.text(_read), findsNothing);
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
      await showSections(tester);

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
      await showSections(tester);

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

  group('a tablet row runs the width it is given', () {
    List<Map<String, dynamic>> oneChapter() => [
      {
        'id': 10,
        'name': '1',
        'minNumber': 1,
        'pages': 100,
        'chapters': [_chapter(101, '1')],
      },
    ];

    // The hero's cover is the first; the row's is the one under it.
    Rect rowCover(WidgetTester tester) =>
        tester.getRect(find.byType(CoverImage).at(1));

    testWidgets('the cover is the size it is drawn at', (tester) async {
      await _pump(tester, oneChapter(), tablet: true);

      // These numbers were once justified as ~13% of a *capped* column — the
      // share a phone gives the cover. The cap is gone, so the cover is about
      // 10% of its row again and the sizes now stand on how they read at
      // arm's length rather than on a proportion. The answer to a tablet's
      // width is a grid, not a narrower column.
      expect(
        rowCover(tester).size,
        const Size(rowCoverWidthTablet, rowCoverHeightTablet),
      );
    });

    testWidgets('the column is not capped and centred', (tester) async {
      await _pump(tester, oneChapter(), tablet: true);

      // A cap put a narrow column between two wide empty bands — about 150pt
      // of nothing down each side of an 820pt screen — which read as more
      // wrong than the gap it closed inside the row. The row starts and ends
      // one gutter from the screen edge, like every other screen.
      expect(rowCover(tester).left, gutter);
      expect(tester.getRect(find.byType(SavePill)).right, 820 - gutter);
    });
  });
}
