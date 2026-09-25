import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/series/series_detail_screen.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// The list under the hero, in its three orders, and the batch card over it.
///
/// The prototype's argument for the screen is that the thing to read is
/// above the fold whatever the series' length: the chapter under way first,
/// then what comes next, the finished ones folded away. The other two orders
/// are the storyline as Kavita sections it, read from either end. The card
/// is the row's save pill writ large, counting what is really left.

Map<String, dynamic> _chapter(
  int id,
  String range, {
  int pages = 10,
  int pagesRead = 0,
  bool isSpecial = false,
  String title = '',
  String? language,
}) => {
  'id': id,
  'language': ?language,
  'range': range,
  'title': title,
  'titleName': title,
  'minNumber': num.tryParse(range) ?? 0,
  'sortOrder': num.tryParse(range) ?? 0,
  'isSpecial': isSpecial,
  'format': 1,
  'pages': pages,
  'pagesRead': pagesRead,
};

Map<String, dynamic> _volume(
  int id,
  String name,
  List<Map<String, dynamic>> chapters,
) => {
  'id': id,
  'name': name,
  'minNumber': num.parse(name),
  'pages': chapters.fold<int>(0, (n, c) => n + (c['pages'] as int)),
  'chapters': chapters,
};

Map<String, dynamic> _specials(List<Map<String, dynamic>> chapters) => {
  'id': 90,
  'name': '100000',
  'minNumber': 100000,
  'pages': 10,
  'chapters': chapters,
};

/// Two volumes of chapters and a special. Chapters 1 and 2 are read, 3 is
/// under way, 4 to 7 and the special are untouched: the next three unread
/// from the resume point — the default batch — are 3 to 5.
List<Map<String, dynamic>> _underWay() => [
  _volume(10, '1', [
    _chapter(101, '1', pagesRead: 10),
    _chapter(102, '2', pagesRead: 10),
    _chapter(103, '3', pagesRead: 4),
  ]),
  _volume(11, '2', [
    _chapter(104, '4'),
    _chapter(105, '5'),
    _chapter(106, '6'),
    _chapter(107, '7'),
  ]),
  _specials([_chapter(108, '', isSpecial: true, title: 'Omake')]),
];

/// A series that holds all three kinds at once: a volume with a chapter
/// breakdown, chapters that belong to no volume, and a special. Chapter 1 is
/// read, chapter 2 is under way, the rest is untouched.
List<Map<String, dynamic>> _mixed() => [
  _volume(10, '1', [
    _chapter(101, '1', pagesRead: 10),
    _chapter(102, '2', pagesRead: 4),
    _chapter(103, '3'),
  ]),
  _loose([_chapter(104, '12'), _chapter(105, '13')]),
  _specials([_chapter(106, '', isSpecial: true, title: 'Omake')]),
];

Map<String, dynamic> _loose(List<Map<String, dynamic>> chapters) => {
  'id': 80,
  'name': '-100000',
  'minNumber': -100000,
  'pages': chapters.fold<int>(0, (n, c) => n + (c['pages'] as int)),
  'chapters': chapters,
};

List<Map<String, dynamic>> _untouched() => [
  _volume(10, '1', [_chapter(101, '1'), _chapter(102, '2')]),
  _volume(11, '2', [_chapter(103, '3')]),
];

List<Map<String, dynamic>> _finished() => [
  _volume(10, '1', [
    _chapter(101, '1', pagesRead: 10),
    _chapter(102, '2', pagesRead: 10),
  ]),
  _volume(11, '2', [_chapter(103, '3', pagesRead: 10)]),
];

class _Adapter implements HttpClientAdapter {
  _Adapter(this.volumes, {this.imageGate});

  final List<Map<String, dynamic>> volumes;

  /// Holds every page fetch open, so a test can look at the card while the
  /// batch is running rather than after it.
  final Future<void>? imageGate;

  /// The chapters whose pages were asked for, in order of first request.
  final List<int> fetched = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    if (options.method == 'POST') return json(const <String, dynamic>{});
    if (options.path == '/api/Reader/image') {
      final chapterId = int.parse(options.queryParameters['chapterId']!);
      if (!fetched.contains(chapterId)) fetched.add(chapterId);
      if (imageGate != null) await imageGate;
      return ResponseBody.fromBytes(const [0], 200);
    }
    return switch (options.path) {
      '/api/Library/libraries' => json([
        {'id': 1, 'name': 'Shelf', 'type': 0},
      ]),
      '/api/Series/7' => json({
        'id': 7,
        'name': 'Berserk',
        'libraryId': 1,
        'libraryName': 'Shelf',
        'pages': 80,
        'pagesRead': 24,
      }),
      '/api/Series/metadata' => json({'id': 7}),
      '/api/Series/volumes' => json(volumes),
      _ => ResponseBody.fromBytes(const [], 404),
    };
  }

  @override
  void close({bool force = false}) {}
}

const _profileId = 'https://kavita.test#1';

Future<_Adapter> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> volumes, {
  List<int> saved = const [],
  Locale locale = const Locale('en'),
  Future<void>? imageGate,
  MemoryKeychain? keychain,
}) async {
  // Tall enough that every row is built: the list is lazy, and a row below
  // the fold is a row a finder cannot see.
  tester.view.physicalSize = const Size(1100, 3600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final cacheDir = mockPathProvider();
  final root = Directory('${cacheDir.path}/downloads');
  for (final chapterId in saved) {
    await saveChapterFixture(
      root,
      _profileId,
      chapterId: chapterId,
      seriesId: 7,
      volumeId: 10,
      seriesName: 'Berserk',
      pages: 10,
      bytes: 10,
    );
  }
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  final adapter = _Adapter(volumes, imageGate: imageGate);
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: root, profileId: _profileId),
        ),
        testCatalogue(profileId: _profileId),
        // The batch card's first-tap hint remembers itself on the device's
        // keychain; handed in so a test can be two visits to one device.
        testKeychain(keychain),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SeriesDetailScreen(
          seriesId: 7,
          seriesName: 'Berserk',
          libraryId: 1,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Matcher above(WidgetTester tester, String other) => predicate<String>(
    (text) =>
        tester.getTopLeft(find.text(text)).dy <
        tester.getTopLeft(find.text(other)).dy,
    'is drawn above "$other"',
  );

  group('the reading-position view', () {
    testWidgets('opens on where you are, with the read folded away', (
      tester,
    ) async {
      await _pump(tester, _underWay());

      // The one under way, in the accent; then what follows, in order.
      expect(find.text('READING NOW'), findsOneWidget);
      expect(find.text('UP NEXT'), findsOneWidget);
      expect('Chapter 3', above(tester, 'Chapter 4'));
      expect('Chapter 4', above(tester, 'Chapter 7'));
      expect('Chapter 7', above(tester, 'Omake'));
      // The finished ones are counted and folded, not listed.
      expect(find.text('ALREADY READ · 2'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Chapter 1'), findsNothing);
      expect(find.text('Chapter 2'), findsNothing);
      // Where the rows change container they say so: a volume over its
      // chapters, the specials over the special. The storyline header is
      // the sectioned view's and is not drawn here.
      expect(find.text('Volume 1'), findsOneWidget);
      expect(find.text('Volume 2'), findsOneWidget);
      expect(find.text('Specials'), findsOneWidget);
      expect(find.text('STORYLINE'), findsNothing);
      expect(find.text('VOLUMES'), findsNothing);
    });

    testWidgets('the orders are in a sheet, not in the header row', (
      tester,
    ) async {
      await _pump(tester, _underWay());

      // Nothing of the three names is on the row: what the header carries is
      // the unit and one control, so no translation can break it.
      expect(find.text('Reading position'), findsNothing);
      expect(find.text('Newest'), findsNothing);
      expect(find.text('Oldest'), findsNothing);

      // The control is the 44pt target the app asks of every control, and
      // says which order is in force where a name would have.
      final trigger = find.byIcon(Icons.swap_vert);
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: trigger, matching: find.byType(Tooltip)).first,
            )
            .message,
        'Sort: Reading position',
      );
      expect(
        tester
            .getSize(
              find.ancestor(of: trigger, matching: find.byType(InkWell)).first,
            )
            .height,
        minHitTarget,
      );

      await tester.tap(trigger);
      await tester.pumpAndSettle();

      // In the sheet each order gets its name and the rule behind it, and
      // the one in force is ticked.
      expect(find.text('SORT'), findsOneWidget);
      expect(find.text('Reading position'), findsOneWidget);
      expect(
        find.text('Where you are first, then what comes next'),
        findsOneWidget,
      );
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Latest first'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);
      expect(find.text('From the beginning'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Reading position')).style?.color,
        patraAccent,
      );

      // Picking closes it and takes the list with it.
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      expect(find.text('SORT'), findsNothing);
      expect(find.text('VOLUMES'), findsOneWidget);
    });

    testWidgets('a series of all three kinds groups all three', (tester) async {
      // Volumes with a chapter breakdown, chapters belonging to no volume,
      // and a special — the reading-position view is built over
      // `orderedChapters`, which flattens exactly that, so the grouping is
      // by what is left to read and never by what kind of row it is.
      await _pump(tester, _mixed());

      expect(find.text('READING NOW'), findsOneWidget);
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('ALREADY READ · 1'), findsOneWidget);

      // Nothing is lost between the kinds: the volume's remaining chapter,
      // both loose chapters and the special are all under "Up next", in
      // reading order, with the special last.
      expect('Chapter 3', above(tester, 'Chapter 12'));
      expect('Chapter 12', above(tester, 'Chapter 13'));
      expect('Chapter 13', above(tester, 'Omake'));

      // The sub-headers name the container the rows are in: the volume over
      // its chapters in each group it has rows in, and the specials over the
      // special — which in this view takes part in the grouping rather than
      // closing the screen.
      expect(find.text('Volume 1'), findsNWidgets(2));
      expect(find.text('Specials'), findsOneWidget);
      // The read one is folded away with everything else read, whichever
      // kind it was.
      expect(find.text('Chapter 1'), findsNothing);
    });

    testWidgets('the row under way is tinted, and only it', (tester) async {
      await _pump(tester, _underWay());

      Color tint(String label) => tester
          .widget<ColoredBox>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      expect(tint('Chapter 3'), patraAccent.withValues(alpha: .06));
      expect(tint('Chapter 4'), Colors.transparent);
    });

    testWidgets('Show unfolds the finished chapters, latest first', (
      tester,
    ) async {
      await _pump(tester, _underWay());

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // The row just closed is the first one under the fold.
      expect('Chapter 2', above(tester, 'Chapter 1'));
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Show'), findsNothing);

      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 1'), findsNothing);
    });

    testWidgets('a volume header over read rows carries no action', (
      tester,
    ) async {
      await _pump(tester, _underWay());
      // Volume 1 heads the chapter under way, volume 2 what follows: two
      // headers, each offering the rest of its volume.
      expect(find.text('Download remaining'), findsNWidgets(2));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Unfolded, volume 1 heads its two read chapters as well — it says
      // which volume they are, and offers nothing over what is done with.
      expect(find.text('Volume 1'), findsNWidgets(2));
      expect(find.text('Download remaining'), findsNWidgets(2));
    });

    testWidgets('a volume whose rest is already saved offers nothing', (
      tester,
    ) async {
      // Everything unread in volume 1 (chapter 3) is on the device; volume 2
      // still has chapters to fetch.
      await _pump(tester, _underWay(), saved: [103]);
      expect(find.text('Download remaining'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Download remaining')).dy,
        greaterThan(tester.getTopLeft(find.text('Volume 2')).dy - 1),
      );
    });

    testWidgets('an untouched series starts here', (tester) async {
      await _pump(tester, _untouched());

      expect(find.text('START HERE'), findsOneWidget);
      expect(find.text('READING NOW'), findsNothing);
      expect(find.text('UP NEXT'), findsNothing);
      expect(find.textContaining('ALREADY READ'), findsNothing);
      expect('Chapter 1', above(tester, 'Chapter 3'));
    });

    testWidgets('a finished series is one open list with no fold', (
      tester,
    ) async {
      await _pump(tester, _finished());

      // That group is the whole list, so it stays open and its header is a
      // divider rather than a control that could only fold the screen away.
      expect(find.text('ALREADY READ · 3'), findsOneWidget);
      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 3'), findsOneWidget);
      expect(find.text('Show'), findsNothing);
      expect(find.text('Hide'), findsNothing);
      expect(find.text('READING NOW'), findsNothing);
    });

    testWidgets('speaks French', (tester) async {
      await _pump(tester, _underWay(), locale: const Locale('fr'));

      expect(find.text('EN COURS'), findsOneWidget);
      expect(find.text('À SUIVRE'), findsOneWidget);
      expect(find.text('DÉJÀ LUS · 2'), findsOneWidget);
      expect(find.text('Afficher'), findsOneWidget);
      expect(find.text('Télécharger la suite'), findsOneWidget);
      expect(find.text('Chapitres 3 à 5'), findsOneWidget);

      // And the orders speak it too, in the sheet the header row's one
      // control opens.
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      expect(find.text('TRIER'), findsOneWidget);
      expect(find.text('Position de lecture'), findsOneWidget);
      expect(find.text('Plus récents'), findsOneWidget);
      expect(find.text('Plus anciens'), findsOneWidget);
    });
  });

  group('the sectioned views', () {
    testWidgets('Oldest is the storyline in reading order', (tester) async {
      await _pump(tester, _underWay());

      await showSections(tester);

      expect(find.text('VOLUMES'), findsOneWidget);
      expect(find.text('SPECIALS'), findsOneWidget);
      expect(find.text('READING NOW'), findsNothing);
      // Nothing is folded: a read chapter has its row.
      expect(find.text('Chapter 1'), findsOneWidget);
      expect('Volume 1', above(tester, 'Volume 2'));
      expect('Chapter 1', above(tester, 'Chapter 7'));
    });

    testWidgets('Newest is the same sections read backwards', (tester) async {
      await _pump(tester, _underWay());

      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();

      expect(find.text('VOLUMES'), findsOneWidget);
      expect('Volume 2', above(tester, 'Volume 1'));
      expect('Chapter 7', above(tester, 'Chapter 4'));
      expect('Chapter 4', above(tester, 'Chapter 1'));
      // The specials still close the screen.
      expect('Chapter 1', above(tester, 'Omake'));
    });
  });

  group('the batch card', () {
    testWidgets('counts what is really left, never the setting', (
      tester,
    ) async {
      // Six unread from the resume point, so the default three: 3 to 5. The
      // title carries no number — that is a setting — and the line under it
      // names the run a tap fetches, the unit said once.
      await _pump(tester, _underWay());
      expect(find.text("Download what's next"), findsOneWidget);
      expect(find.text('Chapters 3 to 5'), findsOneWidget);
    });

    testWidgets('a run of whole volumes is named in volumes', (tester) async {
      Map<String, dynamic> whole(int id, String name, {int read = 0}) => {
        'id': id,
        'name': name,
        'minNumber': num.parse(name),
        'pages': 10,
        'chapters': [
          {
            'id': 200 + id,
            'range': '-100000',
            'minNumber': -100000,
            'pages': 10,
            'pagesRead': read,
          },
        ],
      };
      await _pump(tester, [
        whole(1, '1', read: 4),
        whole(2, '2'),
        whole(3, '3'),
        whole(4, '4'),
      ]);
      expect(find.text('Volumes 1 to 3'), findsOneWidget);
    });

    testWidgets('a run ending on a special names both ends', (tester) async {
      // Chapter 7 and the special are all that is left: two kinds of thing,
      // so no single word covers them.
      await _pump(tester, [
        _volume(11, '2', [
          _chapter(106, '6', pagesRead: 10),
          _chapter(107, '7'),
        ]),
        _specials([_chapter(108, '', isSpecial: true, title: 'Omake')]),
      ]);
      expect(find.text('Chapter 7 – Omake'), findsOneWidget);
    });

    testWidgets('a short series says how many it has', (tester) async {
      // Two unread, under a setting of three: the card says two.
      await _pump(tester, [
        _volume(10, '1', [
          _chapter(101, '1', pagesRead: 10),
          _chapter(102, '2'),
          _chapter(103, '3'),
        ]),
      ]);
      expect(find.text("Download what's next"), findsOneWidget);
      expect(find.text('Chapters 2 to 3'), findsOneWidget);
    });

    testWidgets('one chapter left is the row\'s pill\'s job', (tester) async {
      await _pump(tester, [
        _volume(10, '1', [
          _chapter(101, '1', pagesRead: 10),
          _chapter(102, '2'),
        ]),
      ]);
      expect(find.text("Download what's next"), findsNothing);
    });

    testWidgets('a copy is saved in the language its chapter is written in', (
      tester,
    ) async {
      // The series screen's volumes carry each chapter's language, and a copy
      // records the one it was made with (ADR-0009, #125) — or a book read on
      // a train is hyphenated in nothing.
      final gate = Completer<void>();
      await _pump(tester, [
        _volume(10, '1', [
          _chapter(101, '1', pagesRead: 4, language: 'fr'),
          _chapter(102, '2', language: 'fr'),
          _chapter(103, '3'),
        ]),
      ], imageGate: gate.future);

      await tester.tap(find.text("Download what's next"));
      await tester.pump();
      await tester.pump();

      // What is queued is what the copy is made from: the downloader writes
      // the request's language into the copy (`downloads_service_test`).
      final records = ProviderScope.containerOf(
        tester.element(find.byType(SeriesDetailScreen)),
      ).read(downloadsProvider).value!.records;
      expect(records.keys.toSet(), {101, 102, 103});
      expect(records[101]!.request.language, 'fr');
      expect(records[102]!.request.language, 'fr');
      expect(
        records[103]!.request.language,
        isNull,
        reason: 'the server gave none',
      );

      // Let go of the fetches, or their timeouts outlive the test.
      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(SeriesDetailScreen)),
      ).read(downloadsProvider.notifier);
      for (final id in records.keys) {
        unawaited(notifier.cancel(id));
      }
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('saves only what is not here, and reports as it goes', (
      tester,
    ) async {
      // Two of the three are already on the device, and the gate keeps the
      // one that is not from finishing while the card is looked at.
      final gate = Completer<void>();
      await _pump(
        tester,
        _underWay(),
        saved: [103, 104],
        imageGate: gate.future,
      );
      expect(find.text("Download what's next"), findsOneWidget);
      expect(find.text('Chapters 3 to 5 · 2 already saved'), findsOneWidget);

      await tester.tap(find.text("Download what's next"));
      // Pumped, not settled: settling runs the fake clock for minutes, and a
      // page fetch held open that long is a fetch dio times out.
      await tester.pump();
      await tester.pump();

      // The one that was missing is queued, and nothing that was here.
      final downloads = ProviderScope.containerOf(
        tester.element(find.byType(SeriesDetailScreen)),
      ).read(downloadsProvider).value!;
      expect(downloads.inFlight.keys.toSet(), {105});
      expect(downloads.saved.keys.toSet(), {103, 104});

      expect(find.text('Downloading next 3…'), findsOneWidget);
      expect(find.text('2 of 3 saved'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          // The nearest Material is the card's own; the chapter under way
          // has a bar of its own further down.
          of: find
              .ancestor(
                of: find.text('Downloading next 3…'),
                matching: find.byType(Material),
              )
              .first,
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      // Downloads, in the offline blue, never the accent.
      expect(bar.valueColor?.value, patraOffline);
      // Two of three on the device and one at nought: the bar says so.
      expect(bar.value, closeTo(2 / 3, 0.001));

      // The setting moves to ten while the one is still on its way. What is
      // running is still the three that were asked for, and the card says
      // so — not "ten under way" for a queue holding one.
      ProviderScope.containerOf(tester.element(find.byType(SeriesDetailScreen)))
          .read(batchDownloadSizeProvider.notifier)
          .set(BatchDownloadSize.ten);
      await tester.pump();
      expect(find.text('Downloading next 3…'), findsOneWidget);
      expect(find.text('2 of 3 saved'), findsOneWidget);
      expect(find.text('Downloading next 6…'), findsNothing);

      // Let go of the fetch, or its timeout outlives the test. Not awaited:
      // a cancel resolves when its download has wound down, which takes the
      // pumps below.
      unawaited(
        ProviderScope.containerOf(
          tester.element(find.byType(SeriesDetailScreen)),
        ).read(downloadsProvider.notifier).cancel(105),
      );
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the first tap says the number is a setting, once', (
      tester,
    ) async {
      // One device, two visits: the keychain is what remembers.
      final keychain = MemoryKeychain();
      final first = Completer<void>();
      await _pump(
        tester,
        _underWay(),
        keychain: keychain,
        imageGate: first.future,
      );
      await tester.tap(find.text("Download what's next"));
      await tester.pump();
      await tester.pump();

      // Worded, with the way to the setting as the action.
      expect(
        find.text(
          'Downloading the next 3. That number is yours to choose in '
          'Settings › Storage.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(SnackBarAction, 'Settings'), findsOneWidget);
      // Legible: the accent, not Material's darkened default.
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Settings'))
            .text
            .style
            ?.color,
        patraAccent,
      );

      unawaited(
        ProviderScope.containerOf(
          tester.element(find.byType(SeriesDetailScreen)),
        ).read(downloadsProvider.notifier).cancel(103),
      );
      first.complete();
      await tester.pumpAndSettle();
      // Put the sentence away: `pumpWidget` below keeps the messenger, since
      // the root widgets match, and a SnackBar still up would be mistaken
      // for a second one. Dismissed by hand because the test binding does
      // not run a SnackBar's own clock down.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // The same device, another series: the hint has been given.
      final second = Completer<void>();
      await _pump(
        tester,
        _untouched(),
        keychain: keychain,
        imageGate: second.future,
      );
      await tester.tap(find.text("Download what's next"));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);

      unawaited(
        ProviderScope.containerOf(
          tester.element(find.byType(SeriesDetailScreen)),
        ).read(downloadsProvider.notifier).cancel(101),
      );
      second.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('once every one is here it says so', (tester) async {
      await _pump(tester, _underWay(), saved: [103, 104, 105]);

      expect(find.text('Next 3 saved'), findsOneWidget);
      expect(find.text('Ready to read offline'), findsOneWidget);
      expect(find.text("Download what's next"), findsNothing);
    });

    testWidgets('finishing one of a saved batch offers the newcomer', (
      tester,
    ) async {
      await _pump(tester, _underWay(), saved: [103, 104, 105]);
      expect(find.text('Next 3 saved'), findsOneWidget);

      // Chapter 3 is marked read: the window is the next three *unread*, so
      // it moves on by one and chapter 6 is the one not yet here.
      await tester.drag(find.text('Chapter 3'), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();

      expect(find.text("Download what's next"), findsOneWidget);
      expect(find.text('Chapters 4 to 6 · 2 already saved'), findsOneWidget);
    });

    testWidgets('offline it is drawn only when everything is here', (
      tester,
    ) async {
      await _pump(tester, _underWay(), saved: [103, 104]);
      ProviderScope.containerOf(tester.element(find.byType(SeriesDetailScreen)))
          .read(offlineProvider.notifier)
          .set(true);
      await tester.pumpAndSettle();

      // Offering a fetch that cannot be made is the screen disagreeing
      // with itself.
      expect(find.text("Download what's next"), findsNothing);
    });

    testWidgets('and offline a saved batch still says it is ready', (
      tester,
    ) async {
      await _pump(tester, _underWay(), saved: [103, 104, 105]);
      ProviderScope.containerOf(tester.element(find.byType(SeriesDetailScreen)))
          .read(offlineProvider.notifier)
          .set(true);
      await tester.pumpAndSettle();

      expect(find.text('Next 3 saved'), findsOneWidget);
      expect(find.text('Ready to read offline'), findsOneWidget);
    });
  });
}
