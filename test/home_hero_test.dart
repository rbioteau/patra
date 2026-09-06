import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/home/continue_hero.dart';
import 'package:patra/src/features/home/home_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/cover.dart';

import 'test_support.dart';

Series _series(
  int id, {
  int pages = 100,
  int read = 40,
  String? lastRead,
  int format = 1,
}) => Series.fromJson({
  'id': id,
  'name': 'Series $id',
  'libraryId': 1,
  'libraryName': 'Manga',
  'pages': pages,
  'pagesRead': read,
  'format': format,
  'latestReadDate': ?lastRead,
});

Map<String, dynamic> _json(
  int id, {
  String name = 'Vinland Saga',
  int pages = 100,
  int read = 40,
  String? lastRead,
  int format = 1,
}) => {
  'id': id,
  'name': name,
  'libraryId': 1,
  'libraryName': 'Manga',
  'pages': pages,
  'pagesRead': read,
  'format': format,
  'latestReadDate': ?lastRead,
};

Map<String, dynamic> _chapter(
  int id,
  num number, {
  int pages = 20,
  int read = 0,
  String title = '',
}) => {
  'id': id,
  'range': '$number',
  'minNumber': number,
  'pages': pages,
  'pagesRead': read,
  'sortOrder': number,
  'title': title,
  'titleName': title,
};

class _HomeAdapter implements HttpClientAdapter {
  _HomeAdapter({
    this.continueReading = const [],
    this.onDeck = const [],
    this.volumes = const [],
  });

  List<Map<String, dynamic>> continueReading;
  List<Map<String, dynamic>> onDeck;
  List<Map<String, dynamic>> volumes;

  /// Fails only the featured series' chapter fetch, which is the one call the
  /// hero cannot do without.
  bool volumesFail = false;

  /// Holds the chapter fetch open, so the window where the hero knows its
  /// series but not yet its chapter can actually be rendered.
  Completer<void>? volumesGate;

  /// Holds the shelf fetch open, so the window where nothing is known yet can
  /// be rendered.
  Completer<void>? readingGate;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    return switch (options.path) {
      '/api/Library/libraries' => json([
        {'id': 1, 'name': 'Manga', 'type': 0},
      ]),
      // Kavita answers 400 unless the caller names its own account, which
      // is what emptied this shelf on a real server.
      '/api/Series/currently-reading' => await () async {
        await readingGate?.future;
        return options.queryParameters.containsKey('userId')
            ? json(continueReading)
            : ResponseBody.fromBytes(const [], 400);
      }(),
      '/api/Series/on-deck' => json(onDeck),
      '/api/Series/volumes' => await () async {
        await volumesGate?.future;
        return volumesFail
            ? ResponseBody.fromBytes(const [], 500)
            : json(volumes);
      }(),
      _ => ResponseBody.fromBytes(const [], 404),
    };
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pumpHome(WidgetTester tester, _HomeAdapter adapter) async {
  mockPathProvider();
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: _token,
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [kavitaClientProvider.overrideWithValue(client)],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The home screen under a router, so a tap can be followed to where it goes.
Future<void> _pumpRouted(WidgetTester tester, _HomeAdapter adapter) async {
  mockPathProvider();
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: _token,
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/series/:id',
        builder: (_, state) => Text('series ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/reader/:chapterId',
        builder: (_, state) =>
            Text('reader ${state.pathParameters['chapterId']}'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [kavitaClientProvider.overrideWithValue(client)],
      child: MaterialApp.router(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

_HomeAdapter _oneInProgress() => _HomeAdapter(
  continueReading: [
    _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
  ],
  volumes: [
    {
      'id': 1,
      'name': '1',
      'minNumber': 1,
      'chapters': [_chapter(101, 12, pages: 30, read: 12)],
    },
  ],
);

/// An iPad in portrait: 820x1180 logical points.
void _iPad(WidgetTester tester) {
  tester.view.physicalSize = const Size(1640, 2360);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// A desktop window in landscape: wide and, for the hero, short.
void _landscape(WidgetTester tester) {
  tester.view.physicalSize = const Size(1840, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A phone: 390x844 logical points.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// A token shaped like Kavita's: its `nameid` claim is the account id, which
/// `/api/Series/currently-reading` requires as a query parameter.
const _token =
    'eyJhbGciOiAiSFM1MTIifQ.eyJuYW1lIjogInRlc3RlciIsICJuYW1laWQiOiAiMSJ9.sig';

/// The page behind the card — the one image that is not the cover thumbnail.
Finder _backdrop() => find.descendant(
  of: find.byType(ContinueHero),
  matching: find.byKey(const ValueKey('heroBackdrop')),
);

void main() {
  group('the series the hero promotes', () {
    test('there is none when the shelf is empty', () {
      expect(featuredSeries(const []), isNull);
    });

    test('a finished series is not promoted', () {
      expect(featuredSeries([_series(1, pages: 100, read: 100)]), isNull);
    });

    test('it is the one read most recently', () {
      final featured = featuredSeries([
        _series(1, lastRead: '2026-09-01T10:00:00'),
        _series(2, lastRead: '2026-09-05T10:00:00'),
        _series(3, lastRead: '2026-09-03T10:00:00'),
      ]);
      expect(featured!.id, 2);
    });

    // The reader refuses an EPUB outright, so a hero built on one would offer
    // a button that cannot do the only thing the hero is for.
    test('an EPUB is passed over for the next most recent', () {
      final featured = featuredSeries([
        _series(1, lastRead: '2026-09-05T10:00:00', format: 3),
        _series(2, lastRead: '2026-09-03T10:00:00'),
      ]);
      expect(featured!.id, 2);
    });

    test('a shelf of nothing but EPUBs promotes nothing', () {
      expect(
        featuredSeries([
          _series(1, lastRead: '2026-09-05T10:00:00', format: 3),
        ]),
        isNull,
      );
    });

    // A PDF reads through the same image reader, so it is not excluded.
    test('a PDF is promotable', () {
      final featured = featuredSeries([
        _series(1, lastRead: '2026-09-05T10:00:00', format: 4),
      ]);
      expect(featured!.id, 1);
    });

    test('a series with a read date outranks one carrying none', () {
      final featured = featuredSeries([
        _series(1),
        _series(2, lastRead: '2026-09-01T10:00:00'),
      ]);
      expect(featured!.id, 2);
    });

    test('with no dates at all the first still gets promoted', () {
      expect(featuredSeries([_series(7), _series(8)])!.id, 7);
    });

    // What a real server sends: /api/Series/currently-reading answers with
    // SeriesDto and does not populate per-user progress on it, so `pagesRead`
    // arrives as 0 for series that are plainly under way. The endpoint has
    // already decided they are being read; the client must not second-guess
    // that with a field the payload does not carry.
    test('a shelf whose payload carries no progress still promotes', () {
      final featured = featuredSeries([
        Series.fromJson({
          'id': 5,
          'name': 'Vinland Saga',
          'libraryId': 1,
          'libraryName': 'Manga',
          'pages': 300,
        }),
      ]);
      expect(featured?.id, 5);
    });
  });

  group('the hero on the home screen', () {
    testWidgets('is not drawn when nothing is in progress', (tester) async {
      await _pumpHome(tester, _HomeAdapter(onDeck: [_json(9, read: 0)]));
      expect(find.byType(ContinueHero), findsNothing);
    });

    testWidgets('promotes the series read most recently', (tester) async {
      await _pumpHome(
        tester,
        _HomeAdapter(
          continueReading: [
            _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
            _json(6, name: 'Berserk', lastRead: '2026-09-01T10:00:00'),
          ],
          volumes: [
            {
              'id': 1,
              'name': '1',
              'minNumber': 1,
              'chapters': [_chapter(100, 12, pages: 30, read: 12)],
            },
          ],
        ),
      );
      expect(find.byType(ContinueHero), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ContinueHero),
          matching: find.text('Vinland Saga'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('names the chapter it would resume, and what is left of it', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _HomeAdapter(
          continueReading: [_json(5, lastRead: '2026-09-05T10:00:00')],
          volumes: [
            {
              'id': 1,
              'name': '1',
              'minNumber': 1,
              'chapters': [
                _chapter(100, 11, pages: 20, read: 20),
                _chapter(101, 12, pages: 30, read: 12, title: 'Le duel'),
              ],
            },
          ],
        ),
      );
      Finder inHero(Finder f) =>
          find.descendant(of: find.byType(ContinueHero), matching: f);

      // A title is appended to the number, never swapped for it.
      expect(inHero(find.text('Chapter 12 - Le duel')), findsOneWidget);
      expect(inHero(find.text('18 pages left')), findsOneWidget);
    });

    // The bar is the percentage; printing it too would be one fact twice.
    testWidgets('does not print a percentage beside its bar', (tester) async {
      await _pumpHome(
        tester,
        _HomeAdapter(
          continueReading: [_json(5, lastRead: '2026-09-05T10:00:00')],
          volumes: [
            {
              'id': 1,
              'name': '1',
              'minNumber': 1,
              'chapters': [_chapter(101, 12, pages: 30, read: 12)],
            },
          ],
        ),
      );
      expect(find.textContaining('%'), findsNothing);
    });

    // Everything it could name is already on the card.
    testWidgets('the button says only Continue', (tester) async {
      await _pumpHome(
        tester,
        _HomeAdapter(
          continueReading: [_json(5, lastRead: '2026-09-05T10:00:00')],
          volumes: [
            {
              'id': 1,
              'name': '1',
              'minNumber': 1,
              'chapters': [_chapter(101, 12, pages: 30, read: 12)],
            },
          ],
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Continue'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Continue — '), findsNothing);
    });

    testWidgets('its series is not repeated in the list below it', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _HomeAdapter(
          continueReading: [
            _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
          ],
          onDeck: [
            _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
            _json(6, name: 'Berserk', lastRead: '2026-09-01T10:00:00'),
          ],
          volumes: [
            {
              'id': 1,
              'name': '1',
              'minNumber': 1,
              'chapters': [_chapter(101, 12, pages: 30, read: 12)],
            },
          ],
        ),
      );
      // Once on the screen, and it is the hero's.
      expect(find.text('Vinland Saga'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ContinueHero),
          matching: find.text('Vinland Saga'),
        ),
        findsOneWidget,
      );
      // The rest of the list is untouched.
      expect(find.text('Berserk'), findsOneWidget);
    });

    testWidgets('is taken out of On deck, which is the same set', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _HomeAdapter(
          continueReading: [
            _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
          ],
          onDeck: [
            _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
          ],
          volumes: [
            {
              'id': 1,
              'name': '1',
              'minNumber': 1,
              'chapters': [_chapter(101, 12, pages: 30, read: 12)],
            },
          ],
        ),
      );
      expect(find.text('Vinland Saga'), findsOneWidget);
    });

    // A hero that cannot be completed is worse than no hero, and its series
    // must not disappear from the screen with it.
    testWidgets('collapses when the chapter cannot be fetched, and leaves the '
        'series in the list', (tester) async {
      final adapter = _HomeAdapter(
        continueReading: [
          _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
        ],
        onDeck: [
          _json(5, name: 'Vinland Saga', lastRead: '2026-09-05T10:00:00'),
        ],
      )..volumesFail = true;
      await _pumpHome(tester, adapter);

      expect(find.byType(ContinueHero), findsNothing);
      expect(find.text('Vinland Saga'), findsOneWidget);
    });

    testWidgets('the title opens the series, not the reader', (tester) async {
      await _pumpRouted(tester, _oneInProgress());
      await tester.tap(
        find.descendant(
          of: find.byType(ContinueHero),
          matching: find.text('Vinland Saga'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('series 5'), findsOneWidget);
    });

    testWidgets('the button opens the chapter it named', (tester) async {
      await _pumpRouted(tester, _oneInProgress());
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('reader 101'), findsOneWidget);
    });

    // The hero is a promotion, and offline there is nothing to promote into.
    testWidgets('is not drawn offline', (tester) async {
      mockPathProvider();
      final adapter = _oneInProgress();
      final client = KavitaClient(
        baseUrl: 'http://kavita.test',
        token: _token,
        username: 'romain',
        apiKey: 'key',
      );
      client.httpClient.httpClientAdapter = adapter;
      client.bareHttpClient.httpClientAdapter = adapter;

      final container = ProviderContainer(
        overrides: [kavitaClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      container.read(offlineProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: patraTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ContinueHero), findsNothing);
    });

    // The hero's chapter is a fourth request, and a pull has to reach it too.
    testWidgets('a pull to refresh asks about the chapter again', (
      tester,
    ) async {
      final adapter = _oneInProgress();
      await _pumpHome(tester, adapter);
      expect(find.text('Chapter 12'), findsOneWidget);

      adapter.volumes = [
        {
          'id': 1,
          'name': '1',
          'minNumber': 1,
          'chapters': [
            _chapter(101, 12, pages: 30, read: 30),
            _chapter(102, 13, pages: 30, read: 0),
          ],
        },
      ];
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 13'), findsOneWidget);
    });

    // A volume with no chapter breakdown must never be announced by Kavita's
    // -100000 placeholder.
    testWidgets('names a chapterless volume by the volume', (tester) async {
      await _pumpHome(
        tester,
        _HomeAdapter(
          continueReading: [_json(5, lastRead: '2026-09-05T10:00:00')],
          volumes: [
            {
              'id': 1,
              'name': '2',
              'minNumber': 2,
              'chapters': [
                {
                  'id': 200,
                  'range': '-100000',
                  'minNumber': -100000,
                  'pages': 180,
                  'pagesRead': 20,
                },
              ],
            },
          ],
        ),
      );
      expect(find.text('Volume 2'), findsOneWidget);
      expect(find.textContaining('100000'), findsNothing);
    });

    // Reading is what changes progress, so coming back has to re-ask.
    testWidgets('asks about the chapter again on the way back from reading', (
      tester,
    ) async {
      final adapter = _oneInProgress();
      await _pumpRouted(tester, adapter);
      expect(find.text('Chapter 12'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('reader 101'), findsOneWidget);

      // The chapter was finished while the reader was open.
      adapter.volumes = [
        {
          'id': 1,
          'name': '1',
          'minNumber': 1,
          'chapters': [
            _chapter(101, 12, pages: 30, read: 30),
            _chapter(102, 13, pages: 30, read: 0),
          ],
        },
      ];
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.text('Chapter 13'), findsOneWidget);
    });

    // The backdrop is where you actually are in the book, not its cover — and
    // it is the same URL the reader uses, so a page just read is already on
    // disk rather than fetched again.
    testWidgets('the backdrop is the page reading resumes at', (tester) async {
      await _pumpHome(tester, _oneInProgress());
      final urls = tester
          .widgetList<CachedNetworkImage>(
            find.descendant(
              of: find.byType(ContinueHero),
              matching: find.byType(CachedNetworkImage),
            ),
          )
          .map((w) => w.imageUrl)
          .toList();
      expect(
        urls,
        contains(
          allOf(
            contains('/api/Reader/image'),
            contains('chapterId=101'),
            contains('page=12'),
          ),
        ),
      );
      // The thumbnail is still the cover.
      expect(urls, contains(contains('/api/Image/series-cover')));
    });

    // Two shelves of nearly the same series was the complaint; there is one.
    testWidgets('there is a single list, headed On deck', (tester) async {
      final adapter = _oneInProgress()
        ..onDeck = [_json(6, name: 'Berserk', lastRead: '2026-09-01T10:00:00')];
      await _pumpHome(tester, adapter);
      expect(find.text('ON DECK'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget); // the hero's eyebrow
      expect(
        find.descendant(
          of: find.byType(ContinueHero),
          matching: find.text('CONTINUE'),
        ),
        findsOneWidget,
      );
    });

    // The row once had a percentage at one end and the pages remaining at the
    // other. With the percentage gone it holds one label, and a lone label
    // right-aligned drifts onto the brightest part of the page behind it.
    testWidgets('the pages remaining sit at the start, over the ink', (
      tester,
    ) async {
      await _pumpHome(tester, _oneInProgress());
      expect(
        tester.getTopLeft(find.text('18 pages left')).dx,
        tester.getTopLeft(find.byType(LinearProgressIndicator)).dx,
      );
    });

    // The card is drawn as soon as the series is known and fills its chapter
    // in behind — so there is a real frame where `point` is null, and
    // everything the card reads has to survive it.
    testWidgets('draws before its chapter is known, then fills it in', (
      tester,
    ) async {
      final gate = Completer<void>();
      final adapter = _oneInProgress()..volumesGate = gate;
      await _pumpHome(tester, adapter);

      expect(tester.takeException(), isNull);
      expect(find.byType(ContinueHero), findsOneWidget);
      expect(find.text('Vinland Saga'), findsOneWidget);
      // No chapter yet, so no chapter line and no page behind it.
      expect(find.textContaining('Chapter'), findsNothing);
      expect(
        tester.widget<CachedNetworkImage>(_backdrop()).imageUrl,
        contains('/api/Image/series-cover'),
      );
      // And nothing to resume yet.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Chapter 12'), findsOneWidget);
      expect(
        tester.widget<CachedNetworkImage>(_backdrop()).imageUrl,
        contains('/api/Reader/image'),
      );
    });

    // "Nothing here" is a statement about the library, not about how far the
    // requests have got. Keying it on the hero being absent said it out loud
    // while the promotion was merely unknown.
    testWidgets('does not say the library is empty while it is still asking', (
      tester,
    ) async {
      final gate = Completer<void>();
      final adapter = _oneInProgress()..readingGate = gate;
      await _pumpHome(tester, adapter);

      // Nothing is known yet: no hero, and no verdict on the library either.
      expect(find.byType(ContinueHero), findsNothing);
      expect(find.textContaining('Nothing to read yet'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ContinueHero), findsOneWidget);
    });
  });

  // A tablet's answer to width is more room for the furniture, never a
  // narrow card floating between two empty bands.
  group('the hero on a tablet', () {
    Finder cover() => find.descendant(
      of: find.byType(ContinueHero),
      matching: find.byType(CoverImage),
    );

    testWidgets('the cover is the phone size on a phone', (tester) async {
      _phone(tester);
      await _pumpHome(tester, _oneInProgress());
      expect(tester.getSize(cover()).width, 92);
    });

    testWidgets('the cover grows on a tablet', (tester) async {
      _iPad(tester);
      await _pumpHome(tester, _oneInProgress());
      expect(tester.getSize(cover()).width, 160);
    });

    testWidgets('the card runs the full width, neither capped nor centred', (
      tester,
    ) async {
      _iPad(tester);
      await _pumpHome(tester, _oneInProgress());
      expect(tester.getSize(find.byType(ContinueHero)).width, 820);
      // One gutter in from the edge, like every other screen.
      expect(tester.getTopLeft(cover()).dx, gutter + 18);
    });

    // Give a button a whole iPad to fill and it reads as a banner.
    testWidgets('the button stops at 280', (tester) async {
      _iPad(tester);
      await _pumpHome(tester, _oneInProgress());
      expect(tester.getSize(find.byType(FilledButton)).width, 280);
    });

    // A bar that runs the whole width of a tablet stops reading as progress
    // and starts reading as a rule across the card.
    testWidgets('the progress bar stops at 280', (tester) async {
      _iPad(tester);
      await _pumpHome(tester, _oneInProgress());
      expect(tester.getSize(find.byType(LinearProgressIndicator)).width, 280);
    });

    testWidgets('and is narrower than that on a phone', (tester) async {
      _phone(tester);
      await _pumpHome(tester, _oneInProgress());
      expect(
        tester.getSize(find.byType(LinearProgressIndicator)).width,
        lessThan(280),
      );
    });

    // A page is portrait and a hero on a wide screen is a letterbox. Covering
    // that box scales the page to the card's width, so what shows is a
    // magnified sliver of one panel. The artwork is capped against its own
    // height instead and hung on the edge the scrim lets it show through.
    testWidgets('the page is not blown up to fill a landscape card', (
      tester,
    ) async {
      _landscape(tester);
      await _pumpHome(tester, _oneInProgress());
      final card = tester.getRect(find.byType(ContinueHero));
      final art = tester.getRect(_backdrop());
      expect(art.width, lessThan(card.width / 2));
      // Hung on the trailing edge, not floating in the middle.
      expect(art.right, closeTo(card.right - gutter, 0.5));
    });

    testWidgets('and still spans the card in portrait', (tester) async {
      _phone(tester);
      await _pumpHome(tester, _oneInProgress());
      final art = tester.getRect(_backdrop());
      final card = tester.getRect(find.byType(ContinueHero));
      expect(art.width, closeTo(card.width - gutter * 2, 0.5));
    });
  });
}
