import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:patra/src/features/series/series_selection.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/download_badge.dart';

import 'test_support.dart';

/// The list under the hero, in its three orders and its two views, and the
/// selection that saves several of its entries at once.
///
/// The prototype's argument for the screen is that the thing to read is
/// above the fold whatever the series' length: the chapter under way first,
/// then what comes next, the finished ones folded away. The other two orders
/// are the storyline as Kavita sections it, read from either end. Saving is a
/// gesture: a swipe for one entry, a long-press to select several and the
/// bar under the list to save them.

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
      final chapterId = int.parse('${options.queryParameters['chapterId']}');
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
  bool mobileData = false,
  Size size = const Size(1100, 3600),
}) async {
  // Tall enough that every row is built: the list is lazy, and a row below
  // the fold is a row a finder cannot see.
  tester.view.physicalSize = size;
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
        // The one-time hints remember themselves on the device's keychain;
        // handed in so a test can be two visits to one device.
        testKeychain(keychain),
        testNetwork(mobileData: mobileData),
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

    testWidgets('a volume header names its volume and offers nothing', (
      tester,
    ) async {
      // Saving several is the selection's job, in one place for both views;
      // a header offering to fetch its volume's rest was a second way that
      // only one of them had.
      await _pump(tester, _underWay());
      expect(find.byType(OutlinedButton), findsNothing);

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Unfolded, volume 1 heads its two read chapters as well — it says
      // which volume they are.
      expect(find.text('Volume 1'), findsNWidgets(2));
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
      expect(
        find.text(
          'Appui long pour en sélectionner plusieurs à enregistrer. '
          'Balayez vers la gauche pour un seul.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Liste'), findsOneWidget);
      expect(find.byTooltip('Grille'), findsOneWidget);

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

  group('the two views', () {
    /// A volume with no chapter breakdown: the reading unit, drawn by the
    /// volume's own cover.
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

    Finder selectedSegment(IconData icon) => find.ancestor(
      of: find.byIcon(icon),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.selected ?? false),
      ),
    );

    testWidgets('chapters open as rows', (tester) async {
      await _pump(tester, _underWay());
      expect(selectedSegment(Icons.view_list), findsOneWidget);
      expect(selectedSegment(Icons.grid_view), findsNothing);
    });

    testWidgets('whole volumes open as a grid of covers, with their badges', (
      tester,
    ) async {
      await _pump(
        tester,
        [
          whole(1, '1', read: 10),
          whole(2, '2', read: 4),
          whole(3, '3'),
          whole(4, '4'),
        ],
        saved: [203],
      );
      expect(selectedSegment(Icons.grid_view), findsOneWidget);
      // Three covers across a phone: volume 3 and volume 4 share a row.
      expect(
        tester.getTopLeft(find.text('Volume 3')).dy,
        tester.getTopLeft(find.text('Volume 4')).dy,
      );
      // The one on the device says so on its cover; the rest wear nothing.
      expect(find.byTooltip('Saved'), findsOneWidget);
      // The line teaching the swipe is the list's, which has one.
      expect(find.textContaining('Long-press'), findsNothing);
    });

    testWidgets('the view chosen is the reader\'s, for this series', (
      tester,
    ) async {
      await _pump(tester, _underWay());
      await tester.tap(find.byTooltip('Grid'));
      await tester.pumpAndSettle();

      expect(selectedSegment(Icons.grid_view), findsOneWidget);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(SeriesDetailScreen)),
        ).read(seriesViewsProvider),
        {7: SeriesView.grid},
      );
      // The groups are the same in either view.
      expect(find.text('READING NOW'), findsOneWidget);
      expect(find.text('UP NEXT'), findsOneWidget);
    });
  });

  group('the trailing swipe', () {
    testWidgets('saves one, pauses it, and sends it on', (tester) async {
      final gate = Completer<void>();
      await _pump(tester, _underWay(), imageGate: gate.future);
      ProviderContainer container() => ProviderScope.containerOf(
        tester.element(find.byType(SeriesDetailScreen)),
      );
      Future<void> swipe() async {
        // Let the pane the last action closed finish closing first. Pumped,
        // not settled: a fetch held open is a fetch dio times out.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.drag(find.text('Chapter 4'), const Offset(-200, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await swipe();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      expect(container().read(downloadsProvider).value!.inFlight.keys, [104]);
      // Its cover carries the ring from here on.
      expect(
        find.descendant(
          of: find.byType(DownloadBadge),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await swipe();
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump();
      expect(
        container().read(downloadMembershipProvider).paused,
        contains(104),
      );

      await swipe();
      expect(find.text('Resume'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a saved copy is removed, after asking', (tester) async {
      await _pump(tester, _underWay(), saved: [104]);
      await tester.drag(find.text('Chapter 4'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Saved'), findsNothing);
    });
  });

  group('selecting', () {
    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(SeriesDetailScreen)),
        );
    Set<int>? selection(WidgetTester tester) =>
        container(tester).read(seriesSelectionProvider);

    testWidgets('a long-press enters it, a tap adds, the cross leaves', (
      tester,
    ) async {
      await _pump(tester, _underWay());
      await tester.longPress(find.text('Chapter 4'));
      await tester.pumpAndSettle();

      expect(selection(tester), {104});
      // The bar over the list and the bar under it both count.
      expect(find.text('1 selected'), findsNWidgets(2));
      expect(find.text('All unread'), findsOneWidget);
      expect(find.text('1 to download'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

      // A tap is a toggle now, not a way into the reader.
      await tester.tap(find.text('Chapter 5'));
      await tester.pumpAndSettle();
      expect(selection(tester), {104, 105});
      await tester.tap(find.text('Chapter 4'));
      await tester.pumpAndSettle();
      expect(selection(tester), {105});

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(selection(tester), isNull);
      expect(find.text('Berserk'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    });

    testWidgets('back leaves the selection before the screen', (tester) async {
      await _pump(tester, _underWay());
      await tester.longPress(find.text('Chapter 4'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(selection(tester), isNull);
      expect(find.byType(SeriesDetailScreen), findsOneWidget);
    });

    testWidgets('All unread selects everything left', (tester) async {
      await _pump(tester, _underWay());
      await tester.longPress(find.text('Chapter 7'));
      await tester.pumpAndSettle();

      // Replaced, not added to: the shortcut says what the selection is.
      await tester.tap(find.text('All unread'));
      await tester.pumpAndSettle();
      expect(selection(tester), {103, 104, 105, 106, 107, 108});
      // The batch-size shortcut is gone with the setting behind it.
      expect(find.textContaining('Next'), findsNothing);
    });

    testWidgets('Save queues only what is not here, and leaves selecting', (
      tester,
    ) async {
      // Two of the three are already on the device, and the gate keeps the
      // one that is not from finishing while the screen is looked at.
      final gate = Completer<void>();
      await _pump(
        tester,
        _underWay(),
        saved: [103, 104],
        imageGate: gate.future,
      );
      await tester.longPress(find.text('Chapter 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter 4'));
      await tester.tap(find.text('Chapter 5'));
      await tester.pumpAndSettle();
      expect(find.text('1 to download'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump();

      final downloads = container(tester).read(downloadsProvider).value!;
      expect(downloads.inFlight.keys.toSet(), {105});
      expect(downloads.saved.keys.toSet(), {103, 104});
      expect(selection(tester), isNull);
      // The covers take the report over: two checks and one ring.
      expect(find.byTooltip('Saved'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(DownloadBadge),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      // Let go of the fetch, or its timeout outlives the test. Not awaited:
      // a cancel resolves when its download has wound down, which takes the
      // pumps below.
      unawaited(container(tester).read(downloadsProvider.notifier).cancel(105));
      gate.complete();
      await tester.pumpAndSettle();
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

      await tester.longPress(find.text('Chapter 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All unread'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump();

      // What is queued is what the copy is made from: the downloader writes
      // the request's language into the copy (`downloads_service_test`).
      final records = container(tester).read(downloadsProvider).value!.records;
      expect(records.keys.toSet(), {101, 102, 103});
      expect(records[101]!.request.language, 'fr');
      expect(records[102]!.request.language, 'fr');
      expect(
        records[103]!.request.language,
        isNull,
        reason: 'the server gave none',
      );
      // Filed under the volume it belongs to.
      expect(records[101]!.request.volumeId, 10);

      // Let go of the fetches, or their timeouts outlive the test.
      final notifier = container(tester).read(downloadsProvider.notifier);
      for (final id in records.keys) {
        unawaited(notifier.cancel(id));
      }
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('on mobile data, asks first and fetches nothing unless told', (
      tester,
    ) async {
      final gate = Completer<void>();
      await _pump(
        tester,
        _underWay(),
        saved: [103, 104],
        imageGate: gate.future,
        mobileData: true,
      );
      await tester.longPress(find.text('Chapter 5'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump();
      expect(find.text("You're on mobile data"), findsOneWidget);

      // Cancelled: the question goes, nothing was asked of the server, and
      // the selection is still there to be saved later.
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();
      expect(find.text("You're on mobile data"), findsNothing);
      expect(container(tester).read(downloadsProvider).value!.inFlight, {});
      expect(selection(tester), {105});

      // Asked again, and agreed to.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(
        container(tester).read(downloadsProvider).value!.inFlight.keys.toSet(),
        {105},
      );

      unawaited(container(tester).read(downloadsProvider.notifier).cancel(105));
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('everything here is removed, after asking', (tester) async {
      await _pump(tester, _underWay(), saved: [103, 104]);
      await tester.longPress(find.text('Chapter 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter 4'));
      await tester.pumpAndSettle();

      expect(find.text('All on this device'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove 2 saved copies?'), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      expect(container(tester).read(downloadsProvider).value!.saved, isEmpty);
      expect(selection(tester), isNull);
    });

    testWidgets('a mixed selection is one to save, never to remove', (
      tester,
    ) async {
      // A long-press meant for saving must not be one tap from deleting.
      await _pump(tester, _underWay(), saved: [103]);
      await tester.longPress(find.text('Chapter 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter 4'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Remove'), findsNothing);
    });

    testWidgets('offline, nothing is offered for fetching', (tester) async {
      await _pump(tester, _underWay(), saved: [103]);
      container(tester).read(offlineProvider.notifier).set(true);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Chapter 4'));
      await tester.pumpAndSettle();

      expect(find.text('Offline — reconnect to save these'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    });

    testWidgets('survives a switch between the two views', (tester) async {
      await _pump(tester, _underWay());
      await tester.longPress(find.text('Chapter 4'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Grid'));
      await tester.pumpAndSettle();
      expect(selection(tester), {104});
      expect(find.text('1 selected'), findsNWidgets(2));
      // Each cover carries its mark, the selected one ticked.
      expect(find.byType(SelectionMark), findsNWidgets(6));
    });

    testWidgets('the line teaching it goes once it is used, for good', (
      tester,
    ) async {
      const hint =
          'Long-press to select several to save. Swipe left for just one.';
      final keychain = MemoryKeychain();
      await _pump(tester, _underWay(), keychain: keychain);
      expect(find.text(hint), findsOneWidget);

      await tester.longPress(find.text('Chapter 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsNothing);

      await _pump(tester, _underWay(), keychain: keychain);
      expect(find.text(hint), findsNothing);
    });

    testWidgets('the bars hold together on a small phone in French', (
      tester,
    ) async {
      await _pump(
        tester,
        _underWay(),
        locale: const Locale('fr'),
        // 320pt, the narrowest phone this app is drawn on.
        size: const Size(640, 2400),
      );
      await tester.longPress(find.text('Chapitre 4'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('1 sélectionné'), findsNWidgets(2));
      expect(find.text('Tous les non lus'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });
  });
}
