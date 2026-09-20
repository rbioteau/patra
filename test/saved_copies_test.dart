import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/downloads/downloads_screen.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/download_pill.dart';
import 'package:patra/src/widgets/cover.dart';
import 'package:patra/src/widgets/read_mark.dart';

import 'test_support.dart';

/// How many pages the copy on the device was made with.
const _savedPages = 3;

/// A chapter id the book endpoints are keyed by, as in every other book here.
const _chapterId = 7;

/// What every stored page says: the words the server laid out, which is what a
/// saved book is made of (ADR-0009).
const _pageHtml = '<p>The spice must flow.</p>';

/// A page longer than the screen, which is the only case in which there is a
/// place within a page for anybody to be.
final _longPage = [
  for (var i = 0; i < 40; i++) '<p>Paragraph $i of a long page.</p>',
].join();

/// A Kavita holding one book, which is either there or not — the two halves of
/// a journey.
class _BookServer implements HttpClientAdapter {
  _BookServer({this.pages = _savedPages, this.reachable = true});

  /// How many pages the server says the book is made of, which is its own to
  /// recount: it lays the words out, and nothing asks it not to change its
  /// mind.
  final int pages;

  /// Whether it answers at all. A train is not a refusal: what this turns off
  /// is the connection, not the book.
  bool reachable;

  /// Every book page asked for, in order.
  final requested = <int>[];

  /// Every progress post: the page, and the place within it.
  final posted = <({int pageNum, String? anchor})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    if (!reachable) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route to host',
      );
    }
    switch (options.path) {
      case '/api/Reader/progress':
        final body = options.data as Map<String, dynamic>;
        posted.add((
          pageNum: body['pageNum'] as int,
          anchor: body['bookScrollId'] as String?,
        ));
        return _answer('{}', json: true);
      case '/api/Reader/get-progress':
        return _answer({
          'volumeId': 4,
          'chapterId': _chapterId,
          'seriesId': 3,
          'libraryId': 1,
          'pageNum': 0,
          'bookScrollId': null,
        }, json: true);
      case '/api/Reader/chapter-info':
        // A book has no image pages for this endpoint to count: how long it is
        // has to be asked of the book.
        return _answer({
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'pages': 0,
          'seriesName': 'Dune',
          'title': 'Dune',
          'seriesFormat': MangaFormat.epub.id,
        }, json: true);
      case '/api/Book/$_chapterId/book-info':
        return _answer({
          'bookTitle': 'Dune Messiah',
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'pages': pages,
          'seriesName': 'Dune',
          'seriesFormat': MangaFormat.epub.id,
        }, json: true);
      case '/api/Book/$_chapterId/book-page':
        final page = options.queryParameters['page'] as int;
        requested.add(page);
        return _answer(_pageHtml);
      case '/api/Book/$_chapterId/book-resources':
        return _answer('');
      case '/api/Book/$_chapterId/chapters':
        return _answer(const <Object>[], json: true);
    }
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.unknown,
      error: 'nothing here answers ${options.path}',
    );
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _answer(Object body, {bool json = false}) =>
    ResponseBody.fromString(
      json ? jsonEncode(body) : body as String,
      200,
      headers: {
        Headers.contentTypeHeader: [
          if (json) Headers.jsonContentType else 'text/html',
        ],
      },
    );

class _RefreshRecordingNotifier extends DownloadsNotifier {
  _RefreshRecordingNotifier(this.chapter);

  final SavedChapter chapter;
  final refreshed = Completer<SavedChapter>();

  @override
  Future<DownloadsState> build() async => DownloadsState.fromQueue({
    chapter.chapterId: DownloadQueueRecord.completed(chapter, priority: 0),
  });

  @override
  Future<void> refresh(SavedChapter chapter) async {
    if (!refreshed.isCompleted) refreshed.complete(chapter);
  }
}

SavedChapter _queuedChapter(int id, String title) => SavedChapter(
  chapterId: id,
  seriesId: 3,
  volumeId: 4,
  libraryId: 1,
  seriesName: 'Dune',
  title: title,
  pages: 4,
  bytes: 0,
  format: MangaFormat.epub,
);

class _QueueScreenNotifier extends DownloadsNotifier {
  final paused = Completer<int>();
  final retried = Completer<int>();
  late final Map<int, DownloadQueueRecord> records = {
    7: DownloadQueueRecord.completed(
      _queuedChapter(7, 'Dune Messiah').copyWith(bytes: 40),
      priority: 0,
      batchId: 10,
    ),
    8: DownloadQueueRecord(
      request: _queuedChapter(8, 'Children of Dune'),
      status: DownloadQueueStatus.downloading,
      priority: 1,
      completedPages: 2,
      totalPages: 4,
      batchId: 10,
    ),
    9: DownloadQueueRecord(
      request: _queuedChapter(9, 'God Emperor of Dune'),
      status: DownloadQueueStatus.downloading,
      priority: 2,
      completedPages: 1,
      totalPages: 4,
      batchId: 10,
    ),
    10: DownloadQueueRecord(
      request: _queuedChapter(10, 'Heretics of Dune'),
      status: DownloadQueueStatus.failed,
      priority: 3,
      totalPages: 4,
      batchId: 10,
    ),
  };

  @override
  Future<DownloadsState> build() async => DownloadsState.fromQueue(records);

  @override
  Future<void> pause(int chapterId) async {
    // What the queue does with it, so the row can move to the section that
    // says so: a pause is a status of its own and keeps every page it has.
    records[chapterId] = records[chapterId]!.copyWith(
      status: DownloadQueueStatus.pausedByUser,
    );
    state = AsyncData(DownloadsState.fromQueue(records));
    if (!paused.isCompleted) paused.complete(chapterId);
  }

  @override
  Future<void> retry(int chapterId) async {
    if (!retried.isCompleted) retried.complete(chapterId);
  }
}

/// A queue holding one copy the app paused: it stopped because the app did,
/// which is not the same fact as a failure.
class _PausedScreenNotifier extends DownloadsNotifier {
  final resumed = Completer<int>();

  late final Map<int, DownloadQueueRecord> records = {
    7: DownloadQueueRecord(
      request: _queuedChapter(7, 'Dune Messiah'),
      status: DownloadQueueStatus.paused,
      priority: 0,
      completedPages: 2,
      totalPages: 4,
    ),
  };

  @override
  Future<DownloadsState> build() async => DownloadsState.fromQueue(records);

  @override
  Future<void> retry(int chapterId) async {
    if (!resumed.isCompleted) resumed.complete(chapterId);
  }
}

/// A queue holding one copy whose page count the server has not given yet: the
/// request is out, and there is nothing to be a fraction of.
class _PreparingNotifier extends DownloadsNotifier {
  late final Map<int, DownloadQueueRecord> records = {
    7: DownloadQueueRecord(
      request: _queuedChapter(7, 'Dune Messiah'),
      status: DownloadQueueStatus.downloading,
      priority: 0,
    ),
  };

  @override
  Future<DownloadsState> build() async => DownloadsState.fromQueue(records);
}

/// A queue holding a copy that is **on the device** whose record is doing
/// something else: a refresh runs with the copy it is replacing still intact.
class _RefreshingNotifier extends DownloadsNotifier {
  late final Map<int, DownloadQueueRecord> records = {
    7: DownloadQueueRecord(
      request: _queuedChapter(7, 'Dune Messiah'),
      status: DownloadQueueStatus.downloading,
      priority: 0,
      completedPages: 1,
      totalPages: 4,
      saved: _queuedChapter(7, 'Dune Messiah').copyWith(bytes: 40),
    ),
  };

  @override
  Future<DownloadsState> build() async => DownloadsState.fromQueue(records);
}

/// Whose store the device is holding these copies for.
const _profileId = 'https://kavita.test#1';

/// Where this profile's saved chapters live, under a mocked `path_provider`.
Directory _room() {
  final dir = mockPathProvider();
  return Directory('${dir.path}/downloads')..createSync();
}

/// The book, saved for the train before any of these tests begin.
Future<void> _saved(
  Directory room, {
  int pages = _savedPages,
  String pageHtml = _pageHtml,
}) => saveChapterFixture(
  room,
  _profileId,
  chapterId: _chapterId,
  seriesName: 'Dune',
  title: 'Dune Messiah',
  pages: pages,
  format: MangaFormat.epub,
  pageHtml: pageHtml,
);

/// One run of the app: a screen, the device's store and a server.
///
/// The container is handed back because a test here builds two — a journey is
/// two runs, and what the second one knows of the first is on the disk and
/// nowhere else.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  Directory room,
  _BookServer server,
  Widget home, {
  DownloadsNotifier? downloadsNotifier,
}) async {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = server;
  client.bareHttpClient.httpClientAdapter = server;
  final container = ProviderContainer(
    overrides: [
      testKeychain(),
      kavitaClientProvider.overrideWithValue(client),
      downloadsServiceProvider.overrideWithValue(
        DownloadsService(root: room, profileId: _profileId),
      ),
      if (downloadsNotifier != null)
        downloadsProvider.overrideWith(() => downloadsNotifier),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

Future<ProviderContainer> _pumpReader(
  WidgetTester tester,
  Directory room,
  _BookServer server, {
  int initialPage = 0,
}) => _pump(
  tester,
  room,
  server,
  ReaderScreen(chapterId: _chapterId, initialPage: initialPage),
);

Future<ProviderContainer> _pumpDownloads(
  WidgetTester tester,
  Directory room,
  _BookServer server, {
  DownloadsNotifier? downloadsNotifier,
}) => _pump(
  tester,
  room,
  server,
  const DownloadsScreen(),
  downloadsNotifier: downloadsNotifier,
);

/// What the row says about a copy the server no longer counts the same way.
String get _stale => 'Out of date — the server now counts 12 pages';

/// The progress every pill on screen is showing, as the ring inside it.
List<double?> _rings(WidgetTester tester) => tester
    .widgetList<CircularProgressIndicator>(
      find.descendant(
        of: find.byType(DownloadPill),
        matching: find.byType(CircularProgressIndicator),
      ),
    )
    .map((ring) => ring.value)
    .toList();

void main() {
  testWidgets('the tab shows the batch and controls each queued copy', (
    tester,
  ) async {
    final notifier = _QueueScreenNotifier();
    await _pumpDownloads(
      tester,
      _room(),
      _BookServer(),
      downloadsNotifier: notifier,
    );

    expect(find.text('DOWNLOADING'), findsOneWidget);
    // Where the batch stands is read on the heading's own line, at its
    // trailing edge: an answer about the section, not a row above it.
    expect(find.text('1 of 4 · 44%'), findsOneWidget);
    final heading = tester.getRect(
      find.widgetWithText(SectionLabel, 'DOWNLOADING'),
    );
    final summary = tester.getRect(find.text('1 of 4 · 44%'));
    expect(
      summary.center.dy,
      closeTo(heading.center.dy, 1),
      reason: 'the summary is on the same line as the heading',
    );
    expect(
      summary.right,
      closeTo(heading.right, 1),
      reason: 'and at its trailing edge, not under the title',
    );
    // Each copy on its way is pictured: the cover of what is being fetched,
    // not a spinner where its cover will be. Filed under the shared cache
    // key, so the picture is the one the row will draw when it has landed.
    expect(
      tester
          .widgetList<CoverImage>(find.byType(CoverImage))
          .map((cover) => cover.url),
      [
        contains('/api/Image/chapter-cover?chapterId=8'),
        contains('/api/Image/chapter-cover?chapterId=9'),
        contains('/api/Image/chapter-cover?chapterId=10'),
      ],
    );
    // Each copy on its way carries its own progress, in the ring inside its
    // own pill: a copy's progress is a ring wherever it is drawn, so it can
    // never be read for the reading progress a bar on a cover carries. The
    // third ring is the failed copy's, frozen at the pages it kept — none.
    expect(_rings(tester), [0.5, 0.25, 0.0]);
    expect(find.text('Downloading'), findsNWidgets(2));
    expect(find.text('God Emperor of Dune'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(find.text('Heretics of Dune'), findsOneWidget);

    // The tap on a copy on its way is a pause, not a destruction: it stops
    // where it stands, keeps the pages it has, and moves to the section that
    // says so.
    await tester.tap(find.byTooltip('Pause Dune — Children of Dune'));
    await tester.pump();

    expect(await notifier.paused.future, 8);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Children of Dune'), findsOneWidget);
    expect(find.text('God Emperor of Dune'), findsOneWidget);

    // And the tap on one that stopped is the retry, in the same pill — which
    // sits below the fold now that the tab carries three sections.
    await tester.ensureVisible(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    expect(await notifier.retried.future, 10);

    // And the shelf is the last section, with a heading of its own: below the
    // fold in this viewport, which is exactly what its rows needed one for.
    await tester.scrollUntilVisible(find.text('SAVED'), 200);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('Dune Messiah'), findsOneWidget);
  });

  testWidgets('a paused copy is listed as paused, not as missing', (
    tester,
  ) async {
    final notifier = _PausedScreenNotifier();
    await _pumpDownloads(
      tester,
      _room(),
      _BookServer(),
      downloadsNotifier: notifier,
    );

    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Dune Messiah'), findsOneWidget);
    // Two words for two facts, and not a blank where a copy should be: the row
    // says which stop this was, and the pill says what the tap does.
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    // Two pages of four already on the device are not thrown away by the
    // pause: the ring says how far it got, and the tap that sends it on
    // starts from there.
    expect(_rings(tester), [0.5]);

    await tester.tap(find.byType(DownloadPill));
    expect(await notifier.resumed.future, 7);
  });

  testWidgets('a paused copy’s pill is the tap that sends it on', (
    tester,
  ) async {
    final notifier = _PausedScreenNotifier();
    await _pump(
      tester,
      _room(),
      _BookServer(),
      Scaffold(body: DownloadPill(request: _queuedChapter(7, 'Dune Messiah'))),
      downloadsNotifier: notifier,
    );

    // The pill says what the tap does: a copy that stopped is one tap from
    // going on, and it does not read as something that went wrong.
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.byType(DownloadPill));
    expect(await notifier.resumed.future, 7);
  });

  testWidgets('a copy on the device is the shelf’s, whatever its record is '
      'doing', (tester) async {
    // A refresh runs with the copy it is replacing still intact, and a copy
    // found on disk under a record that says it stopped is still a copy.
    // Either one listed among the ones on their way — or among the ones that
    // stopped — is the same chapter in two sections, one of them about
    // something else.
    await _pumpDownloads(
      tester,
      _room(),
      _BookServer(),
      downloadsNotifier: _RefreshingNotifier(),
    );

    expect(find.text('DOWNLOADING'), findsNothing);
    expect(find.text('PAUSED'), findsNothing);
    expect(find.text('NEEDS ATTENTION'), findsNothing);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('Dune Messiah'), findsOneWidget);
  });

  testWidgets('a copy whose page count has not arrived says so', (
    tester,
  ) async {
    await _pump(
      tester,
      _room(),
      _BookServer(),
      Scaffold(body: DownloadPill(request: _queuedChapter(7, 'Dune Messiah'))),
      downloadsNotifier: _PreparingNotifier(),
    );

    // Not a ring stuck at zero for the seconds the count takes: the request
    // is out, which is a state of its own — the word says which, and the ring
    // **turns** rather than filling.
    expect(find.text('Preparing'), findsOneWidget);
    expect(_rings(tester), [null]);
    expect(find.byTooltip('Pause Dune — Dune Messiah'), findsOneWidget);
  });

  testWidgets('a saved copy’s pill is a mark, not a control', (tester) async {
    await _pump(
      tester,
      _room(),
      _BookServer(),
      Scaffold(body: DownloadPill(request: _queuedChapter(7, 'Dune Messiah'))),
      downloadsNotifier: _QueueScreenNotifier(),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byTooltip('Saved'), findsOneWidget);

    // Taking a copy off the device is a swipe on the row it sits in, and
    // never a tap on the mark whose whole message is that all is well.
    await tester.tap(find.byType(DownloadPill));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the tab’s rows fit a phone', (tester) async {
    // The narrowest surface this app runs on, and the row that carries the
    // most: the cover, the work, the pill — a word, a glyph and a ring — and
    // the bin. A row that cannot be read at 390 is a row that cannot be read,
    // and Flutter throws on an overflow in debug, so the pump is the check.
    //
    // The real face is loaded first, and that is not decoration: the test
    // environment's own font is twice as wide as Space Grotesk — 184pt
    // against 88 for "Could not finish" at 11.5 — so a row measured without
    // it would be failing a width no phone has.
    final spaceGrotesk = FontLoader('Space Grotesk')
      ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Variable.ttf'));
    await spaceGrotesk.load();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _pumpDownloads(
      tester,
      _room(),
      _BookServer(),
      downloadsNotifier: _QueueScreenNotifier(),
    );

    expect(find.byType(DownloadPill), findsNWidgets(3));
    final pill = tester.getRect(find.byType(DownloadPill).first);
    final bin = tester.getRect(find.byIcon(Icons.delete_outline).first);
    expect(pill.right, lessThan(bin.left), reason: 'the pill comes first');
    expect(
      bin.right,
      lessThanOrEqualTo(390 - gutter),
      reason: 'and the bin ends at the gutter, not off the screen',
    );
  });

  testWidgets('the refresh control asks to store the copy again', (
    tester,
  ) async {
    final room = _room();
    await _saved(room);
    final chapter = const SavedChapter(
      chapterId: _chapterId,
      seriesId: 3,
      volumeId: 4,
      libraryId: 1,
      seriesName: 'Dune',
      title: 'Dune Messiah',
      pages: _savedPages,
      bytes: 0,
      format: MangaFormat.epub,
      serverPages: 12,
    );
    final notifier = _RefreshRecordingNotifier(chapter);
    await _pumpDownloads(
      tester,
      room,
      _BookServer(pages: 12),
      downloadsNotifier: notifier,
    );

    await tester.tap(find.text('Refresh'));

    expect((await notifier.refreshed.future).chapterId, _chapterId);
  });

  testWidgets('progress a journey took reaches the server when it answers', (
    tester,
  ) async {
    final room = _room();
    await _saved(room, pageHtml: _longPage);
    final meta = File(
      '${(await DownloadsService(root: room, profileId: _profileId).chapterDir(_chapterId)).path}/meta.json',
    );
    Map<String, dynamic> copy() =>
        jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
    final train = _BookServer(reachable: false);

    await _pumpReader(tester, room, train, initialPage: 1);
    expect(find.text('Paragraph 0 of a long page.'), findsOneWidget);

    // Read on, and down the page: where a reader is in a book is a page and a
    // place within it, and both were recorded with nothing to tell.
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // Kept by the copy, which is the one thing here that outlives the app
    // being closed on the train.
    final kept = copy()['pending'] as Map<String, dynamic>?;
    expect(
      kept,
      isNotNull,
      reason: 'the copy holds what the server was never told',
    );
    expect(kept!['pageNum'], 1);
    // Not the top of the page, which is where a page number on its own would
    // open it again.
    expect(kept['bookScrollId'], isNot('0.0000'));
    expect(
      train.posted,
      isEmpty,
      reason: 'nothing answered, so nothing was told',
    );

    // Home again: the same device, a server that answers, and nothing left
    // running that remembers the journey. Reading the store is what sends it.
    final home = _BookServer();
    await _pumpDownloads(tester, room, home);
    await pumpUntil(tester, () => home.posted.isNotEmpty);

    // The page and the place within it, together: half of it is a reader put
    // back at words they had already read.
    expect(home.posted, [
      (pageNum: kept['pageNum'], anchor: kept['bookScrollId']),
    ]);
    await pumpUntil(tester, () => copy()['pending'] == null);
    expect(copy()['pending'], isNull, reason: 'taken, so nothing is held');
  });

  testWidgets('a copy the server has recounted says so, and is made again', (
    tester,
  ) async {
    // Twelve where the copy was made with three: the server lays a book out
    // and can recount it whenever it likes, and a copy keeps the pagination it
    // was made with (ADR-0009).
    final room = _room();
    await _saved(room);
    final server = _BookServer(pages: 12);

    await _pumpReader(tester, room, server);
    expect(find.text('The spice must flow.'), findsOneWidget);
    expect(
      server.posted,
      isNotEmpty,
      reason: 'an out-of-date copy still opens, and still records progress',
    );

    final recounting = _BookServer(pages: 12);
    final home = await _pumpDownloads(tester, room, recounting);
    await pumpUntil(
      tester,
      () => home.read(savedChapterProvider(_chapterId))?.serverPages == 12,
    );

    // Named rather than silently refetched, and offered rather than left:
    // resuming at the wrong page is the one failure that makes a saved copy
    // look broken.
    expect(find.text(_stale), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);

    final copy = home.read(savedChapterProvider(_chapterId))!;
    await tester.runAsync(
      () => home
          .read(downloadsServiceProvider)
          .download(
            client: home.read(kavitaClientProvider),
            chapter: copy.copyWith(pages: copy.serverPages),
            onProgress: (_, _) {},
          ),
    );
    home.invalidate(downloadsProvider);
    await pumpUntil(
      tester,
      () => home.read(savedChapterProvider(_chapterId))?.pages == 12,
    );

    // Every page the server counts now, and none of the three it counted when
    // this copy was made.
    expect(recounting.requested, [for (var page = 0; page < 12; page++) page]);

    // Counted by what it holds now, and no longer saying otherwise.
    expect(find.textContaining('12 pages'), findsOneWidget);
    expect(find.textContaining('Out of date'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
  });

  testWidgets('a copy the server still counts the same is not marked', (
    tester,
  ) async {
    // The same opening, with a server that has not recounted the book: the two
    // agree, so there is nothing to say and nothing to offer.
    final room = _room();
    await _saved(room);
    final server = _BookServer();

    await _pumpReader(tester, room, server);
    expect(find.text('The spice must flow.'), findsOneWidget);
    await pumpUntil(tester, () => server.posted.isNotEmpty);

    final home = await _pumpDownloads(tester, room, _BookServer());
    await pumpUntil(tester, () => home.read(downloadsProvider).hasValue);
    expect(home.read(savedChapterProvider(_chapterId))?.outOfDate, isFalse);
    expect(find.textContaining('Out of date'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    // What it was made with, still.
    expect(find.textContaining('3 pages'), findsOneWidget);
  });

  // The Downloads row and the series screen's chapter row are the same row,
  // and a finished one is marked the same way on both: a rail on the leading
  // edge and the word inside the metadata line, in the accent. Neither of
  // them dims anything — a lowered opacity means *unavailable* here.
  testWidgets('a finished copy wears the rail and says so in its line', (
    tester,
  ) async {
    final room = _room();
    await saveChapterFixture(
      room,
      _profileId,
      chapterId: _chapterId,
      seriesName: 'Dune',
      title: 'Dune Messiah',
      pages: _savedPages,
      pagesRead: _savedPages,
      format: MangaFormat.epub,
      pageHtml: _pageHtml,
    );

    final home = await _pumpDownloads(tester, room, _BookServer());
    await pumpUntil(tester, () => home.read(downloadsProvider).hasValue);

    expect(
      find.byWidgetPredicate((widget) => widget is ReadRail && widget.read),
      findsOneWidget,
    );
    // The accent stops where the sentence about reading does: how big the
    // copy is says nothing about progress, and gold is spoken for.
    // `Text.rich` nests what it was given under a span carrying the default
    // style, so the two halves of the line are one level down.
    final line = tester.widget<RichText>(
      find.textContaining('Read · 3 pages', findRichText: true),
    );
    final spans =
        ((line.text as TextSpan).children!.single as TextSpan).children!;
    final read = spans.first as TextSpan;
    final size = spans.last as TextSpan;
    expect(read.text, 'Read · 3 pages');
    expect(read.style?.color, patraAccent);
    expect(size.text, contains('·'));
    expect(size.style?.color, isNot(patraAccent));
    expect(find.text('READ'), findsNothing);
  });
}
