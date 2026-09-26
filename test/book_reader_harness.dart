/// The book reader on a fake Kavita: what the reader asked the server for,
/// what it posted back, and a copy saved the way the downloader saves one.
///
/// Shared by `book_reader_test.dart`, which asks about what a reader sees and
/// what the server is told, and `development_book_page_test.dart`, which asks
/// about the development renderer that is not shipped (#131). Nothing here
/// is about either renderer: [pumpBook] says which one draws.
library;

import 'dart:convert';
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
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/book_web_page.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// How much of the book the server says there is.
const bookPages = 12;

/// The title Kavita read out of the file, which is what the bar names.
const bookTitle = 'Dune Messiah';

/// What the server hands back for a page: the HTML it laid out. No assertion
/// here is about that HTML — it is the server's output, and what is asked of
/// the app is which page it asked for and what it did with the answer.
String _pageHtml(int page) =>
    '<h1>Book two</h1>'
    '<p>The spice must flow, &amp; the worm <b>follows</b>.</p>'
    '<p><img src="OEBPS/images/worm$page.jpg"/></p>';

/// What Kavita really writes for a page's pictures: a whole address of its
/// own making — no scheme, its own guess at its host, its own key — rather
/// than a path inside the book.
const addressedPicture =
    '<p><img src="//kavita.test/api/book/7/book-resources'
    '?apiKey=key&file=OEBPS/images/cover.jpg"/></p>';

/// What the server says a book is made of: a part with two chapters under it,
/// and a second part after them.
///
/// The nesting is the point — which chapter belongs to which part is the
/// whole of what a contents is for, and a reader that flattened it would
/// lose the one thing the server knows about the shape of the book.
const _contents = [
  {
    'title': 'Part one',
    'page': 0,
    'children': [
      {'title': 'The desert', 'page': 2, 'children': <Object>[]},
      {'title': 'The worm', 'page': 5, 'children': <Object>[]},
    ],
  },
  {'title': 'Part two', 'page': 8, 'children': <Object>[]},
];

/// A one-pixel PNG, base64: the smallest picture the decoder will take, which
/// is what makes the picture in a stored page a picture rather than a fault.
const carriedPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=';

/// A Kavita holding one book, in a Book library.
class BookAdapter implements HttpClientAdapter {
  BookAdapter({
    required this.requested,
    required this.posted,
    this.unavailable,
    this.html,
    this.progressPage = 0,
    this.bookScrollId,
    this.contents = _contents,
    this.language = 'en',
  });

  /// Every page the reader asked the server for, in order.
  final List<int> requested;

  /// Every progress post: the page number, and the anchor sent with it.
  final List<({int pageNum, String? anchor})> posted;

  /// A page the server cannot produce.
  final int? unavailable;

  /// What every page is made of, where a test has a page of its own: the
  /// server's HTML is not what any assertion here is about, but the address
  /// a picture is named by is.
  final String? html;

  /// Where the server says the reader was: what `get-progress` answers.
  ///
  /// Moved by a progress post, because that is what a post is — so one test
  /// can read a book, close it, and open it again through the same server,
  /// which is the round trip rather than its two halves apart.
  int progressPage;
  String? bookScrollId;

  /// What the server says the book is made of: a tree of parts and the
  /// chapters under them, each with the page it begins on.
  ///
  /// Empty for a book the server listed nothing for, which is a book the
  /// reader offers no contents for.
  final List<Object>? contents;

  /// The language the server says the book is written in — `ChapterDto`'s
  /// BCP-47 code — or null for a book nobody recorded one for.
  final String? language;

  /// How many times the reader asked the server about the chapter itself,
  /// which is the one call a language can cost (#125).
  var chapterAsked = 0;

  /// Every picture or font a page named that the app fetched from the book,
  /// as it was asked for.
  final resources = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    switch (options.path) {
      case '/api/Reader/progress':
        final body = options.data as Map<String, dynamic>;
        progressPage = body['pageNum'] as int;
        bookScrollId = body['bookScrollId'] as String?;
        posted.add((pageNum: progressPage, anchor: bookScrollId));
        return _answer('{}', json: true);
      case '/api/Reader/get-progress':
        return _answer({
          'volumeId': 4,
          'chapterId': 7,
          'seriesId': 3,
          'libraryId': 1,
          'pageNum': progressPage,
          'bookScrollId': bookScrollId,
        }, json: true);
      case '/api/Reader/chapter-info':
        // A book has no image pages for this endpoint to count, so it says
        // none: how long the book is has to be asked of the book.
        //
        // **And it mislabels the library, on every server there is.**
        // `GetChapterInfo` never assigns `LibraryType`, so what it sends is
        // the enum's default — manga — for every chapter of every library:
        // measured on all 53 epubs of the demo server's *Books* library and
        // on its comics too, then read in Kavita's own source (#120). The
        // fixture therefore states what the server really states, and the app
        // reads the field nowhere.
        return _answer({
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'libraryType': LibraryType.manga.id,
          'pages': 0,
          'seriesName': 'Dune',
          'title': 'Dune',
          'seriesFormat': MangaFormat.epub.id,
        }, json: true);
      case '/api/Book/7/book-info':
        return _answer({
          'bookTitle': bookTitle,
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'pages': bookPages,
          'seriesName': 'Dune',
          'seriesFormat': MangaFormat.epub.id,
        }, json: true);
      case '/api/Book/7/book-page':
        final page = options.queryParameters['page'] as int;
        requested.add(page);
        if (page == unavailable) {
          throw DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 500),
            type: DioExceptionType.badResponse,
          );
        }
        return _answer(html ?? _pageHtml(page));
      case '/api/Chapter':
        chapterAsked++;
        return _answer({
          'id': 7,
          'minNumber': 1,
          'pages': 0,
          'format': MangaFormat.epub.id,
          'language': ?language,
        }, json: true);
      case '/api/Book/7/chapters':
        return _answer(contents ?? const <Object>[], json: true);
    }
    // Asked for by a whole address, which is what dio then calls its path.
    if (options.uri.path == '/api/Book/7/book-resources') {
      resources.add(options);
      return ResponseBody.fromBytes(base64Decode(carriedPng), 200);
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
          if (json) Headers.jsonContentType else 'text/plain',
        ],
      },
    );

/// A progress post: the page number, and the anchor it carried.
typedef BookPost = ({int pageNum, String? anchor});

/// What the reader posted, as page numbers alone.
List<int> postedPages(List<BookPost> posted) => [
  for (final post in posted) post.pageNum,
];

/// What the reader posted, as anchors alone.
List<String?> postedAnchors(List<BookPost> posted) => [
  for (final post in posted) post.anchor,
];

/// What the reader asked for, sorted: which of a page and a neighbour beside
/// it is fetched first is an implementation detail, and nothing here is
/// asserted about the order they are asked in.
List<int> askedPages(List<int> requested) => requested.toList()..sort();

/// The reader on a book, and what it asked the server for.
///
/// [initialPage] is the page the route named, which is what the series screen
/// passes and what a link does not; [progressPage] and [bookScrollId] are what
/// the server says about where the reader was, which is what a book opens at.
/// [server] is that server, where a test needs the same one twice — a book
/// closed and opened again, which is the round trip.
///
/// [saved] seeds the device's store before the reader opens, for a copy that
/// has already been saved for the train: it is handed the downloads root, and
/// every fixture here goes through the service (`saveChapterFixture`).
Future<(List<int> requested, List<BookPost> posted)> pumpBook(
  WidgetTester tester, {
  bool webEngine = false,
  void Function(BookAdapter server)? onServer,
  int initialPage = 0,
  int? unavailable,
  String? html,
  int progressPage = 0,
  String? bookScrollId,
  BookAdapter? server,
  List<Object>? contents,
  Future<void> Function(Directory root)? saved,
  List<Volume>? held,
  bool offline = false,
  Locale? locale,
}) async {
  final dir = mockPathProvider();
  final root = Directory('${dir.path}/downloads')..createSync();
  final downloads = DownloadsService(root: root, profileId: bookProfileId);
  if (saved != null) await saved(root);
  // What the device already holds of the series, where a test says it holds
  // anything: what the series screen writes when it draws the series, which
  // is the screen a book is normally opened from.
  final catalogue = CatalogueStore(
    root: Directory('${dir.path}/catalogue')..createSync(),
    profileId: bookProfileId,
  );
  if (held != null) await catalogue.putVolumes(3, held);
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  final adapter =
      server ??
      BookAdapter(
        requested: <int>[],
        posted: <BookPost>[],
        unavailable: unavailable,
        html: html,
        progressPage: progressPage,
        bookScrollId: bookScrollId,
        contents: contents ?? _contents,
      );
  onServer?.call(adapter);
  // No server at all, where a test says so: the train, with only the copy.
  final HttpClientAdapter wire = offline ? UnreachableServer() : adapter;
  client.httpClient.httpClientAdapter = wire;
  client.bareHttpClient.httpClientAdapter = wire;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(),
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(downloads),
        catalogueStoreProvider.overrideWithValue(catalogue),
        // Which renderer draws: the development renderer, which is what a
        // test binding has, unless a test says the platform has an engine —
        // which is what ships.
        bookWebEngineProvider.overrideWithValue(webEngine),
        // Somebody reading, whose catalogue that is: a device with nobody
        // signed in holds nothing, whatever is on its disk.
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [_reader], activeId: _reader.id),
        ),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: ReaderScreen(chapterId: 7, initialPage: initialPage),
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (adapter.requested, adapter.posted);
}

/// Whose store the reader reads: the profile its downloads were saved under.
const bookProfileId = 'https://kavita.test#1';

/// Saves the book [server] holds the way the app does — through the
/// downloader, into the store under [root] — for a copy that is exactly what
/// saving this book makes of it, rather than a fixture's idea of one.
Future<void> saveThroughDownloader(
  WidgetTester tester,
  Directory root,
  BookAdapter server, {
  String? language,
}) async {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = server;
  client.bareHttpClient.httpClientAdapter = server;
  // Real requests and real files, which a test's clock does not move.
  await tester.runAsync(
    () => DownloadsService(root: root, profileId: bookProfileId).download(
      client: client,
      chapter: SavedChapter(
        chapterId: 7,
        seriesId: 3,
        volumeId: 4,
        libraryId: 1,
        seriesName: 'Dune',
        title: bookTitle,
        pages: 0,
        bytes: 0,
        format: MangaFormat.epub,
        language: language,
      ),
      onProgress: (_, _) {},
    ),
  );
}

/// Who is reading: the profile [bookProfileId] names.
final _reader = Profile(
  baseUrl: 'http://kavita.test',
  accountId: 1,
  username: 'romain',
  apiKey: 'key',
  token: signedToken(1),
);

/// The reader's chrome: a tap in the middle of the screen.
Future<void> showBookChrome(WidgetTester tester) async {
  final size = tester.getSize(find.byType(Scaffold));
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// One sideways drag, far enough to turn a page, and long enough for a
/// request the server refuses to give up on (`serverRetry`).
Future<void> swipeBookPage(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-600, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

/// Lets the files a page is written into for the web engine land: real I/O,
/// which a test's clock does not move.
Future<void> settleBookFiles(WidgetTester tester) async {
  // Each step of a write is a round trip the clock does not move, and a page
  // is several: its pictures, the app's face, the document.
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
