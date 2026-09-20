import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/book_page.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// How much of the book the server says there is.
const _pages = 12;

/// The title Kavita read out of the file, which is what the bar names.
const _title = 'Dune Messiah';

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
const _addressedPicture =
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
const _carried =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=';

/// A Kavita holding one book, in a Book library.
class _BookAdapter implements HttpClientAdapter {
  _BookAdapter({
    required this.requested,
    required this.posted,
    this.unavailable,
    this.html,
    this.progressPage = 0,
    this.bookScrollId,
    this.contents = _contents,
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
        // **And it mislabels the library.** Measured against the demo server
        // (Kavita 0.9.1.4, `demo.kavitareader.com`): all 53 epubs of a
        // library whose type is *Books* are reported `libraryType: 0` —
        // manga — and so is every comic of a *Comics* library. The type this
        // endpoint states is not the library's, so the fixture states what
        // the server really states rather than what the shelf really is.
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
          'bookTitle': _title,
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'pages': _pages,
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
      case '/api/Book/7/chapters':
        return _answer(contents ?? const <Object>[], json: true);
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
typedef _Post = ({int pageNum, String? anchor});

/// What the reader posted, as page numbers alone.
List<int> _postedPages(List<_Post> posted) => [
  for (final post in posted) post.pageNum,
];

/// What the reader posted, as anchors alone.
List<String?> _postedAnchors(List<_Post> posted) => [
  for (final post in posted) post.anchor,
];

/// What the reader asked for, sorted: which of a page and a neighbour beside
/// it is fetched first is an implementation detail, and nothing here is
/// asserted about the order they are asked in.
List<int> _asked(List<int> requested) => requested.toList()..sort();

/// Whether the reader is waiting on a page, where the reader can see it: the
/// spinner a page draws while it is being fetched.
///
/// Off screen does not count. A page beside the one being read is fetched out
/// of sight, which is the whole point of fetching it early — a spinner there
/// is a spinner nobody is looking at, and what flickers is one over the words.
bool _waiting(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final element in find.byType(CircularProgressIndicator).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final at = box.localToGlobal(Offset.zero);
    if (at.dx < size.width && at.dy < size.height) return true;
  }
  return false;
}

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
Future<(List<int> requested, List<_Post> posted)> _pumpBook(
  WidgetTester tester, {
  int initialPage = 0,
  int? unavailable,
  String? html,
  int progressPage = 0,
  String? bookScrollId,
  _BookAdapter? server,
  List<Object>? contents,
  Future<void> Function(Directory root)? saved,
}) async {
  final dir = mockPathProvider();
  final root = Directory('${dir.path}/downloads')..createSync();
  final downloads = DownloadsService(root: root, profileId: _profileId);
  if (saved != null) await saved(root);
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  final adapter =
      server ??
      _BookAdapter(
        requested: <int>[],
        posted: <_Post>[],
        unavailable: unavailable,
        html: html,
        progressPage: progressPage,
        bookScrollId: bookScrollId,
        contents: contents ?? _contents,
      );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(),
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(downloads),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
const _profileId = 'https://kavita.test#1';

/// Where the page on screen is scrolled to, read out of the render tree
/// rather than off anything the reader said about it.
///
/// Asked for inside the page itself, because a sheet open over the reader
/// scrolls too.
ScrollPosition _pagePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(BookPageBody),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// The style every run of words in [paragraphs] is set in.
///
/// A run, and not the `Text` that draws it: `Text` wraps the span it is
/// given in one of its own carrying the app's default face, so what is being
/// asked about here is the style on the words themselves.
List<TextStyle> _runs(WidgetTester tester, Finder paragraphs) => [
  for (final paragraph in tester.widgetList<RichText>(paragraphs))
    ..._spanRuns(paragraph.text),
];

Iterable<TextStyle> _spanRuns(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  if (span.text != null) {
    if (span.style case final TextStyle style) yield style;
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _spanRuns(child);
  }
}

/// A page longer than the screen it is read on, which is the only case in
/// which there is a place within a page to be asked about.
///
/// Words rather than a picture: a picture fetched from a server a test does
/// not have is a picture with no height at all, and a page of nothing is not
/// a page that scrolls.
final String _longPage = [
  for (var i = 0; i < 40; i++) '<p>Paragraph $i of a long page.</p>',
].join();

/// One of every kind of block a page is made of, which is what "the whole
/// page is set in the chosen face" has to mean.
const _everyBlock = '<h2>Book two</h2>'
    '<p>The spice must flow, and the worm <b>follows</b>.</p>'
    '<blockquote>A beginning is a very delicate time.</blockquote>'
    '<ul><li>First.</li><li>Second.</li></ul>';

/// The reader's chrome: a tap in the middle of the screen.
Future<void> _showChrome(WidgetTester tester) async {
  final size = tester.getSize(find.byType(Scaffold));
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// One sideways drag, far enough to turn a page, and long enough for a
/// request the server refuses to give up on (`serverRetry`).
Future<void> _swipe(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-600, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('a book opens on its first page', (tester) async {
    final (requested, posted) = await _pumpBook(tester);

    expect(_asked(requested), [
      0,
      1,
    ], reason: 'the page it opens on, and the one beside it');
    expect(_postedPages(posted), [
      0,
    ], reason: 'opening a book says where it was opened');
    await _showChrome(tester);
    // Twelve, which is what the book says: `chapter-info` counted no pages
    // at all, so a reader that asked it instead would show nothing.
    expect(find.text('1 / $_pages'), findsOneWidget);
  });

  testWidgets('a book opens where reading left off', (tester) async {
    final (requested, posted) = await _pumpBook(tester, progressPage: 4);

    expect(_asked(requested), [3, 4, 5]);
    expect(_postedPages(posted), [4]);
    await _showChrome(tester);
    expect(find.text('5 / $_pages'), findsOneWidget);
  });

  testWidgets('a book opened from a link lands in the same place', (
    tester,
  ) async {
    // What a link carries is a chapter and nothing else: no page, and no
    // place within one. The series screen does name a page, and it is not the
    // one that counts — so the two ways in are made to disagree here, and
    // both have to land on the server's.
    final (fromLink, linkPosted) = await _pumpBook(tester, progressPage: 4);
    final (fromSeries, _) = await _pumpBook(
      tester,
      initialPage: 7,
      progressPage: 4,
    );

    expect(_asked(fromLink), [3, 4, 5], reason: 'a link names no page at all');
    expect(_asked(fromSeries), [
      3,
      4,
      5,
    ], reason: 'the page the route named is not the one a book opens at');
    expect(_postedPages(linkPosted), [4]);
  });

  testWidgets('a book opens again where in the page it was left', (
    tester,
  ) async {
    await _pumpBook(
      tester,
      progressPage: 4,
      bookScrollId: '0.5000',
      html: _longPage,
    );

    final position = _pagePosition(tester);
    // Half way down a page longer than the screen, and not at the top of it:
    // that is the whole of what an anchor is for, and a page number on its
    // own is a page opened again at words already read.
    expect(position.pixels, closeTo(position.maxScrollExtent / 2, 1));
  });

  testWidgets('a book closed and opened again is put back where it was', (
    tester,
  ) async {
    // The round trip, rather than its two halves apart: the same server is
    // asked to restore what the first reader posted to it, so an anchor
    // written by one arithmetic and read back by another cannot pass.
    final server = _BookAdapter(
      requested: <int>[],
      posted: <_Post>[],
      html: _longPage,
    );
    await _pumpBook(tester, server: server);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final left = _pagePosition(tester).pixels;
    expect(left, greaterThan(0), reason: 'the reader did scroll the page');

    await _pumpBook(tester, server: server);

    final reopened = _pagePosition(tester);
    expect(reopened.pixels, closeTo(left, 1));
  });

  testWidgets('a page the reader comes back to is where they left it', (
    tester,
  ) async {
    await _pumpBook(tester, html: _longPage);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final left = _pagePosition(tester).pixels;

    await _swipe(tester);
    // The page turned to is arrived at at its beginning.
    expect(_pagePosition(tester).pixels, 0);

    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    // Coming back is not: the place in the page is kept per page, so the
    // reader is put back down it rather than at its top.
    expect(_pagePosition(tester).pixels, closeTo(left, 1));
  });

  testWidgets('reading a long page posts where in it the reader is', (
    tester,
  ) async {
    final (_, posted) = await _pumpBook(tester, html: _longPage);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    final position = _pagePosition(tester);
    expect(position.pixels, greaterThan(0), reason: 'the page did scroll');
    // What was posted is where the page is, as a fraction of the room there
    // was to scroll — a number of points would be a place in a page laid out
    // at another size, and no anchor at all is a page reopened at its top.
    expect(
      double.parse(_postedAnchors(posted).last!),
      closeTo(position.pixels / position.maxScrollExtent, .01),
    );
  });

  testWidgets('a book with nothing recorded opens at the top of its page', (
    tester,
  ) async {
    await _pumpBook(tester, progressPage: 4, html: _longPage);

    expect(_pagePosition(tester).pixels, 0);
  });

  testWidgets('a marker another reader wrote is not a place', (tester) async {
    // Kavita's own web client fills `bookScrollId` with the id of an element
    // in the page, and there is no element in a page this app draws: a book
    // whose place was last saved there opens at the top of its page rather
    // than nowhere at all.
    await _pumpBook(
      tester,
      progressPage: 4,
      bookScrollId: 'body-h2-17',
      html: _longPage,
    );

    expect(_pagePosition(tester).pixels, 0);
  });

  testWidgets('a swipe turns the page, and the counter follows', (
    tester,
  ) async {
    final (requested, posted) = await _pumpBook(tester);

    await _swipe(tester);

    expect(_asked(requested), [0, 1, 2]);
    expect(_postedPages(posted), [0, 1]);
    await _showChrome(tester);
    expect(find.text('2 / $_pages'), findsOneWidget);
  });

  testWidgets('a page turned to is already in hand', (tester) async {
    final (requested, _) = await _pumpBook(tester);

    // The next page is fetched while the reader is at rest on this one, not
    // when it is turned to: `PageView.builder` mounts a page as late as it
    // can, so a page asked for only then is a page fetched under the
    // reader's finger.
    expect(_asked(requested), [0, 1]);

    // The turn itself, frame by frame. What is drawn while a page is coming
    // is a spinner over the whole screen, and that is the flicker: one frame
    // of it here, where the fake server answers at once, and as long as the
    // request takes on a real one.
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_waiting(tester), isFalse, reason: 'frame $i of the turn waits');
    }
  });

  testWidgets('a page turned back to is not asked for again', (tester) async {
    final (requested, _) = await _pumpBook(tester);

    await _swipe(tester);
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    // Three pages, each asked for once. A page the pager unmounts is a page
    // an autoDispose provider forgets, and reading back used to re-fetch it —
    // and to draw the spinner again while it came.
    expect(_asked(requested), [0, 1, 2]);
  });

  testWidgets('the sides of the screen turn the page', (tester) async {
    final (requested, posted) = await _pumpBook(tester);
    final size = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(size.width * .85, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_postedPages(posted), [
      0,
      1,
    ], reason: 'the right-hand side reads on');
    // The page it turned to is the page it asked the server for.
    expect(requested, contains(1));

    await tester.tapAt(Offset(size.width * .15, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_postedPages(posted), [
      0,
      1,
      0,
    ], reason: 'the left-hand side reads back');
  });

  testWidgets('the last page reports the whole book', (tester) async {
    final (_, posted) = await _pumpBook(
      tester,
      initialPage: _pages - 1,
      progressPage: _pages - 1,
    );

    // Kavita marks a chapter read at `pagesRead >= pages`, so the last page
    // is posted as the total rather than as its own number.
    expect(_postedPages(posted), [_pages]);
  });

  testWidgets('the bar names the book', (tester) async {
    await _pumpBook(tester);

    await _showChrome(tester);
    // The title Kavita read out of the file, not the series it belongs to.
    expect(find.text(_title), findsOneWidget);
    expect(find.text('Dune'), findsNothing);
  });

  testWidgets('the cog offers how the book is set, and nothing else', (
    tester,
  ) async {
    await _pumpBook(tester);
    await _showChrome(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // How a book is set is a question about words, and the only one there
    // is: which way pages turn is a question about pictures. The face is
    // the third of the three, and the last.
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Line spacing'), findsOneWidget);
    expect(find.text('Reading face'), findsOneWidget);
    expect(find.text('READING DIRECTION'), findsNothing);
    expect(find.text('Drag to magnify'), findsNothing);
    expect(find.text('Page width'), findsNothing);
  });

  testWidgets('a book set at another size keeps the place in the page', (
    tester,
  ) async {
    await _pumpBook(tester, html: _longPage);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final scrolled = _pagePosition(tester);
    // Read as numbers, not held as a position: the page is about to be laid
    // out again, and a position is a live thing that would answer with the
    // new page.
    final extent = scrolled.maxScrollExtent;
    final read = scrolled.pixels / extent;
    expect(read, greaterThan(0), reason: 'the reader did scroll the page');

    await _showChrome(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(400, 0));
    await tester.pumpAndSettle();

    final after = _pagePosition(tester);
    expect(
      after.maxScrollExtent,
      greaterThan(extent),
      reason: 'the words are set larger, so there is more page to scroll',
    );
    // Where the reader is, and not where in the pixels they are: the page
    // grew under them, and a page that sends them back to its top is a page
    // that has made them read the words above again.
    expect(after.pixels / after.maxScrollExtent, closeTo(read, .02));
  });

  testWidgets('a page the server cannot produce says so', (tester) async {
    await _pumpBook(tester, unavailable: 1);

    await _swipe(tester);

    // Rather than an empty screen, which reads as a book with no words in it.
    expect(find.text('This page could not be loaded.'), findsOneWidget);
  });

  testWidgets('a picture the page refers to is drawn', (tester) async {
    await _pumpBook(tester);

    final pictures = tester.widgetList<Image>(find.byType(Image));
    expect(pictures, hasLength(1));
    final provider = pictures.single.image;
    expect(provider, isA<CachedNetworkImageProvider>());
    final cached = provider as CachedNetworkImageProvider;
    // The file the page named, resolved against the server: a page's HTML
    // points inside the book, which is not something the app can fetch.
    expect(cached.url, contains('worm0.jpg'));
    // And fetched with the session, which is the only way a book's pictures
    // are served at all: `book-resources` takes no key in the query, so a
    // request without the header is a picture that never arrives.
    expect(cached.headers, containsPair('Authorization', isNotNull));
    // Filed under the shared key, as every image in the app is: a URL of its
    // own would keep one copy per profile that looked at the page.
    expect(cached.cacheKey, imageCacheKey(cached.url));
  });

  testWidgets('a picture the page addresses for itself is drawn', (
    tester,
  ) async {
    await _pumpBook(tester, html: _addressedPicture);

    final pictures = tester.widgetList<Image>(find.byType(Image));
    expect(pictures, hasLength(1));
    final cached = pictures.single.image as CachedNetworkImageProvider;
    // Asked for on the address this session was built with rather than the
    // one the page carried: only the file it named survives. The server
    // writes that address out of its own idea of where it lives, which a
    // proxy is free to get wrong, and the page that carried it — a cover's,
    // which has no words — is then drawn as nothing at all.
    expect(
      cached.url,
      startsWith('http://kavita.test/api/Book/7/book-resources'),
    );
    expect(cached.url, contains('file=OEBPS%2Fimages%2Fcover.jpg'));
    expect(cached.url, isNot(contains('%2F%2F')));
    expect(cached.cacheKey, imageCacheKey(cached.url));
  });

  // A book saved for the train is read from the copy: the pages the server
  // rendered the day it was saved are the only pages there are once there is
  // no server, and they are the better answer even while there is one — the
  // copy is what the reader asked for by saving it.
  testWidgets('a saved book is read from the copy, and drawn whole', (
    tester,
  ) async {
    final (requested, _) = await _pumpBook(
      tester,
      saved: (root) => saveChapterFixture(
        root,
        _profileId,
        chapterId: 7,
        title: 'Dune Messiah',
        pages: 3,
        format: MangaFormat.epub,
        pageHtml:
            '<p>The spice must flow.</p>'
            '<p><img src="data:;base64,$_carried"/></p>',
      ),
    );

    // Nothing was asked of the server for the page: the copy is the page.
    expect(requested, isEmpty);
    expect(find.text('The spice must flow.'), findsOneWidget);
    // And the picture the copy carries is drawn from it, rather than fetched.
    final pictures = tester.widgetList<Image>(find.byType(Image));
    expect(pictures, hasLength(1));
    expect(pictures.single.image, isA<MemoryImage>());
  });

  group('the contents of a book', () {
    /// Choosing an entry in the contents, and waiting for the page it names
    /// to have been asked for and reported.
    Future<void> choose(WidgetTester tester, String entry) async {
      await tester.tap(find.text('Contents'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('the parts and their children are what is offered', (
      tester,
    ) async {
      await _pumpBook(tester);
      await _showChrome(tester);

      await tester.tap(find.text('Contents'));
      await tester.pumpAndSettle();

      expect(find.text('Part one'), findsOneWidget);
      expect(find.text('The desert'), findsOneWidget);
      expect(find.text('The worm'), findsOneWidget);
      expect(find.text('Part two'), findsOneWidget);
      // Hierarchical on the screen and not only in the parsing: a child is
      // set in from the part it belongs to, which a sheet that walked the
      // tree into one flat list would not do however it ordered it.
      final part = tester.getRect(find.text('Part one'));
      final child = tester.getRect(find.text('The desert'));
      expect(child.left, greaterThan(part.left));
      expect(child.top, greaterThan(part.top));
      // The page an entry begins on, counted the way the reader's own
      // counter counts: the server numbers a book's pages from zero.
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('choosing an entry moves the reader to its page', (
      tester,
    ) async {
      final (requested, posted) = await _pumpBook(tester);
      await _showChrome(tester);

      await choose(tester, 'The worm');

      // Page 5 is the one the server named for that chapter, and it is both
      // the page asked for and the progress reported for it: a reader who
      // has chosen a chapter has read their way to where it begins.
      expect(requested.last, 5);
      expect(_postedPages(posted).last, 5);
    });

    testWidgets('choosing a part moves the reader to the page it begins on', (
      tester,
    ) async {
      final (requested, posted) = await _pumpBook(tester);
      await _showChrome(tester);

      await choose(tester, 'Part two');

      expect(requested.last, 8);
      expect(_postedPages(posted).last, 8);
    });

    testWidgets('a book the server listed nothing for offers none', (
      tester,
    ) async {
      await _pumpBook(tester, contents: const []);
      await _showChrome(tester);

      // No control, and nothing anywhere saying there is no contents: the
      // absence is not itself a message.
      expect(find.text('Contents'), findsNothing);
    });
  });

  group('what a page is made of', () {
    test('words are kept, and the tags around them are not', () {
      final page = BookPage.fromHtml('<p>One.</p><p>Two.</p>');

      expect(page.blocks, hasLength(2));
      final first = page.blocks.first as BookWords;
      expect(first.style, BookBlockStyle.paragraph);
      expect(first.spans.single.text, 'One.');
    });

    test('a run set in bold or italic is its own run', () {
      final page = BookPage.fromHtml('The <b>spice</b> must <i>flow</i>.');

      final runs = (page.blocks.single as BookWords).spans;
      expect(runs.map((span) => span.text).toList(), [
        'The ',
        'spice',
        ' must ',
        'flow',
        '.',
      ]);
      expect(runs[1].bold, isTrue);
      expect(runs[3].italic, isTrue);
    });

    test('a heading is not a paragraph', () {
      final page = BookPage.fromHtml('<h2>Book two</h2><p>One.</p>');

      final heading = page.blocks.first as BookWords;
      expect(heading.style, BookBlockStyle.heading);
      expect(heading.spans.single.text, 'Book two');
      expect((page.blocks.last as BookWords).style, BookBlockStyle.paragraph);
    });

    test('an entity is the character it stands for', () {
      final page = BookPage.fromHtml(
        '<p>Caf&#233; &amp; &#x2014; the worm&rsquo;s</p>',
      );

      expect(
        (page.blocks.single as BookWords).spans.single.text,
        'Café & — the worm’s',
      );
    });

    test('a soft hyphen is where a word may break, and not a word', () {
      // The character an author or an editing tool puts where a word may be
      // broken: invisible, and a break opportunity. &#173; — the same
      // character written numerically — has always been decoded, so what
      // the named spelling has to land on is exactly what that one lands
      // on. A German book is full of it, so a page that read well in one
      // library read broken in another, with nothing to say why.
      String words(String html) {
        final page = BookPage.fromHtml(html);
        return (page.blocks.single as BookWords).spans.single.text;
      }

      final text = words('<p>Donaudampf&shy;schifffahrt</p>');
      // The same character the numeric spelling has always decoded to, and
      // not the five characters of its own name in the middle of the word.
      expect(text, words('<p>Donaudampf&#173;schifffahrt</p>'));
      // U+00AD itself, written as a code point: a character nobody can see
      // should not be pasted into a test either.
      expect(text.codeUnits, contains(0xAD));
    });

    test('a picture is kept by the name the page gave it', () {
      final page = BookPage.fromHtml(
        '<p><img src="OEBPS/images/worm.jpg"/></p>',
      );

      expect(
        page.blocks.whereType<BookPicture>().single.src,
        'OEBPS/images/worm.jpg',
      );
    });

    test('a picture inside a paragraph keeps the page in its order', () {
      // The common case in an illustrated book: the figure is not alone in
      // its block, and hoisting it above the words it sits among is a page
      // read out of order.
      final page = BookPage.fromHtml(
        '<p>The worm <img src="a.jpg"/> rises.</p>',
      );

      expect(page.blocks, [
        isA<BookWords>(),
        isA<BookPicture>(),
        isA<BookWords>(),
      ]);
      expect((page.blocks[0] as BookWords).spans.single.text, 'The worm');
      expect((page.blocks[2] as BookWords).spans.single.text, 'rises.');
    });

    test('a script and a stylesheet are not words', () {
      final page = BookPage.fromHtml(
        '<style>p { color: red }</style><p>One.</p>'
        '<script>var spice = "must flow";</script>',
      );

      expect(page.blocks, hasLength(1));
      expect((page.blocks.single as BookWords).spans.single.text, 'One.');
    });

    test('a line break is kept, and the file’s own indentation is not', () {
      final page = BookPage.fromHtml('<p>One.\n      <br/>\n Two.</p>');

      expect((page.blocks.single as BookWords).spans.single.text, 'One.\nTwo.');
    });

    test('a page of nothing is not a page', () {
      expect(BookPage.fromHtml('').isEmpty, isTrue);
      expect(BookPage.fromHtml('<p>  </p>').isEmpty, isTrue);
    });
  });

  // What makes a page storable: the picture a page names has to be able to
  // travel inside it, because there is no server left to fetch one from
  // (ADR-0009).
  group('what a stored page carries', () {
    const carried = 'data:;base64,QUJD';

    test('a picture is named by its bytes instead', () {
      final renamed = renameBookPictures(
        '<p>Words.</p><img class="worm" src="OEBPS/worm.jpg"/>',
        (src) => carried,
      );

      expect(renamed, '<p>Words.</p><img class="worm" src="$carried"/>');
      // And it parses back to the picture the copy is carrying.
      expect(BookPage.fromHtml(renamed).pictureSources, [carried]);
    });

    test('a picture the copy does not carry keeps the name it had', () {
      // A picture the server would not hand over is not a reason to lose the
      // page: it stays a name, and a server that can answer it still can.
      expect(
        renameBookPictures('<img src="OEBPS/worm.jpg"/>', (_) => null),
        '<img src="OEBPS/worm.jpg"/>',
      );
    });

    test('a picture named by an href is renamed by its href', () {
      // Otherwise a page that named it that way would carry a second `src`
      // beside the first, and the copy would fetch a name that is not there.
      final renamed = renameBookPictures(
        '<image href="a.jpg"/>',
        (_) => carried,
      );

      expect(renamed, '<image href="$carried"/>');
      expect(renamed, isNot(contains('src=')));
    });

    test('the bytes a name carries, and nothing else', () {
      expect(carriedPictureBytes(carried), [65, 66, 67]);
      // A name that is a path, and one that is a damaged copy: neither is
      // something this device already has.
      expect(carriedPictureBytes('OEBPS/worm.jpg'), isNull);
      expect(carriedPictureBytes('data:;base64,!!!'), isNull);
    });
  });

  group('where a page sits in the screen', () {
    /// A phone's screen, and a page in it whose one picture is
    /// [pictureHeight] tall — which is what a test can say about a picture it
    /// cannot fetch.
    Future<void> pumpPage(WidgetTester tester, double pictureHeight) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: patraTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox(
              child: BookPageBody(
                textSize: defaultBookTextSize,
                lineHeight: defaultBookLineHeight,
                face: (family: fontAtkinsonHyperlegibleNext, canSetItalic: false),
                page: BookPage.fromHtml('<p><img src="cover.jpg"/></p>'),
                picture: (_) =>
                    SizedBox(key: const Key('picture'), height: pictureHeight),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('content that fits is set in the middle of the page', (
      tester,
    ) async {
      await pumpPage(tester, 300);

      final page = tester.getRect(find.byType(BookPageBody));
      final content = tester.getRect(find.byType(Column));
      // The room the counter leaves is not the page's: the top of it is a
      // gutter, the bottom four, and what fits is equidistant from the two.
      expect(
        content.top - page.top - gutter,
        closeTo(page.bottom - 4 * gutter - content.bottom, 1),
      );
    });

    testWidgets('a page taller than the screen still starts at the top', (
      tester,
    ) async {
      await pumpPage(tester, 2000);

      // Centring is not something that can be done to a page one has to
      // scroll: it would begin off the top edge, with no way back to it.
      final page = tester.getRect(find.byType(BookPageBody));
      final content = tester.getRect(find.byType(Column));
      expect(content.top - page.top, closeTo(gutter, 1));
    });
  });

  group('how a page is set', () {
    Future<void> pumpWords(
      WidgetTester tester,
      String html, {
      BookType face = (family: fontAtkinsonHyperlegibleNext, canSetItalic: false),
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: patraTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: BookPageBody(
                textSize: defaultBookTextSize,
                lineHeight: defaultBookLineHeight,
                face: face,
                page: BookPage.fromHtml(html),
                picture: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('prose is set ragged right, and not justified', (tester) async {
      await pumpWords(
        tester,
        '<h2>Book two</h2><p>One.</p>'
        '<blockquote>Two.</blockquote><ul><li>Three.</li></ul>',
      );

      final aligns = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.textAlign ?? TextAlign.start)
          .toList();
      expect(aligns, [
        // Not one line of it justified. Measured on this engine: U+00AD is
        // honoured as a break opportunity but the hyphen is not drawn at the
        // break, so a narrow column has nothing to justify with and opens
        // gaps instead — which reads as a rendering fault rather than as
        // typography. The measurement is written down in the reader's rules,
        // so this is not put back.
        TextAlign.start, // the title
        TextAlign.start, // the paragraph
        TextAlign.start, // the quotation
        TextAlign.start, // the bullet
        TextAlign.start, // the item
      ]);
    });

    testWidgets('a page is set in the face chosen, and the counter is not', (
      tester,
    ) async {
      // Tall enough for the whole sheet to be on screen: a face is picked
      // from a list of four, and a sheet that has to be scrolled to reach
      // one is a sheet that hides half of what it offers.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (requested, _) = await _pumpBook(tester, html: _everyBlock);
      await _showChrome(tester);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serif'));
      await tester.pumpAndSettle();
      // Every block of words on the page is set in it — prose, headings,
      // quotations and list items alike — because a book set in a serif with
      // sans intertitres reads as an interface rather than as a book.
      final set = _runs(
        tester,
        find.descendant(
          of: find.byType(BookPageBody),
          matching: find.byType(RichText),
        ),
      );
      expect(set, isNotEmpty, reason: 'the page is made of words');
      expect(set.map((style) => style.fontFamily), everyElement(fontLiterata));
      expect(
        set.where((style) => style.fontSize == defaultBookTextSize + 3),
        isNotEmpty,
        reason: 'the heading is set in it too, and not left in the sans',
      );

      // The counter is the app's own furniture and stays in the serif: the
      // choice is a book's and nothing else's, and a page of a book has been
      // a mixture by design since the counter was first drawn.
      expect(
        tester.widget<Text>(find.text('1 / $_pages')).style?.fontFamily,
        fontLiterata,
      );

      // Nothing was asked of the server: a page set in another face is the
      // page the reader is already holding, laid out again.
      expect(_asked(requested), [0, 1]);
    });

    testWidgets('a page set in another face keeps the place in it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpBook(tester, html: _longPage);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final scrolled = _pagePosition(tester);
      final read = scrolled.pixels / scrolled.maxScrollExtent;
      expect(read, greaterThan(0), reason: 'the reader did scroll the page');

      await _showChrome(tester);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serif'));
      await tester.pumpAndSettle();

      // A face is a reflow like a size is: the words break somewhere else,
      // so the page is longer or shorter and the reader must not be sent
      // back to the top of it.
      final after = _pagePosition(tester);
      expect(
        after.pixels / after.maxScrollExtent,
        closeTo(read, .02),
        reason: 'the reader is still where they were in the page',
      );
    });

    testWidgets('emphasis is set in the italic the face ships', (tester) async {
      Future<List<FontStyle?>> styles(BookType face) async {
        await pumpWords(
          tester,
          '<p>The worm <i>follows</i>.</p>',
          face: face,
        );
        return [
          for (final run in _runs(
            tester,
            find.descendant(
              of: find.byType(BookPageBody),
              matching: find.byType(RichText),
            ),
          ))
            run.fontStyle,
        ];
      }
      // The app's serif (Literata) ships an italic.
      expect(
        await styles(ReadingFace.serif.resolve()),
        contains(FontStyle.italic),
        reason: "Literata ships an italic, so a book's emphasis is set in it",
      );
      // The app's sans (Atkinson Hyperlegible Next) also ships an italic.
      expect(
        await styles(ReadingFace.sans.resolve()),
        contains(FontStyle.italic),
        reason: 'Atkinson Hyperlegible Next ships an italic',
      );
      // The default (book's own, falling back to app sans) has no italic.
      expect(
        await styles(ReadingFace.book.resolve()),
        everyElement(FontStyle.normal),
        reason: 'the fallback sans has no italic when the book has none',
      );
    });
  });

  group('the direction a book declares', () {
    /// A page in the shape the server hands one over: the wrapper Kavita
    /// scopes a book into, the book's own CSS inlined at the top of it, and
    /// some words.
    String page(String css) =>
        '<div class="book-content"><style>$css</style>'
        '<h1>الفصل الأول</h1><p>مرحبا بالعالم.</p>'
        '<blockquote>قال الرجل.</blockquote></div>';

    /// Which way the pager itself runs, read off the scroll position rather
    /// than off the `Directionality` that set it: a stray `reverse:` on top
    /// of that `Directionality` would undo the flip and nothing about the
    /// words would show it.
    AxisDirection pager(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(PageView),
            matching: find.byType(Scrollable),
          ).first,
        )
        .position
        .axisDirection;

    /// Where the rule down the side of a quotation is drawn, as the room it
    /// leaves between itself and the words: a quotation in a book that reads
    /// from the right is indented from the right.
    ({double start, double end}) quotationInset(WidgetTester tester) {
      final rule = find.ancestor(
        of: find.textContaining('قال الرجل'),
        matching: find.byType(Container),
      );
      final box = tester.getRect(rule.first);
      final words = tester.getRect(
        find.descendant(of: rule.first, matching: find.byType(RichText)).first,
      );
      return (start: words.left - box.left, end: box.right - words.right);
    }

    /// Which direction the page's own prose is laid out in, read off the
    /// render tree: `TextAlign.start` is the right *form* and resolves
    /// against this, so it is the whole of whether a book reads from the
    /// right.
    TextDirection prose(WidgetTester tester) => tester
        .renderObjectList<RenderParagraph>(
          find.descendant(
            of: find.byType(BookPageBody),
            matching: find.byType(RichText),
          ),
        )
        .first
        .textDirection;

    /// The direction the page itself is laid out in, which is what the pager
    /// turns on.
    TextDirection laidOut(WidgetTester tester) => Directionality.of(
      tester.element(find.byType(BookPageBody).first),
    );

    testWidgets('a book that declares itself is laid out that way', (
      tester,
    ) async {
      await _pumpBook(
        tester,
        html: page('.book-content { direction: rtl; }'),
      );

      expect(laidOut(tester), TextDirection.rtl);
      expect(
        prose(tester),
        TextDirection.rtl,
        reason: 'the prose resolves `start` to the right',
      );
      expect(
        pager(tester),
        AxisDirection.left,
        reason: 'the pages turn the way the words run, and only once',
      );

      // The rule down the side of a quotation is directional too, like the
      // bullet of a list item: in a book that reads from the right it
      // belongs on the right.
      final inset = quotationInset(tester);
      expect(inset.end, greaterThan(inset.start));
    });

    testWidgets('and its pages turn the way it reads', (tester) async {
      // Doing only the text half would produce a book that reads
      // right-to-left while its pages turn left-to-right — worse than
      // leaving it as it is. The pager is inside the book's own
      // `Directionality`, so it mirrors with the words.
      final (requested, posted) = await _pumpBook(
        tester,
        html: page('.book-content { direction: rtl; }'),
      );
      final size = tester.getSize(find.byType(Scaffold));

      await tester.tapAt(Offset(size.width * .15, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_postedPages(posted), [
        0,
        1,
      ], reason: 'the left-hand side reads on in a book that reads that way');
      expect(requested, contains(1));

      await tester.tapAt(Offset(size.width * .85, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_postedPages(posted), [0, 1, 0]);
    });

    testWidgets('the library the server names cannot turn a book', (
      tester,
    ) async {
      // The regression #118 shipped with, at the level a reader meets it.
      // `chapter-info` reports `libraryType: 0` for a book — measured on all
      // 53 epubs of the demo server's *Books* library — so wiring the book
      // reader into the chain let the manga convention answer for every book
      // on every server, not merely for one shelved oddly. Nothing is
      // measured of a book now, so the type it names says nothing.
      await _pumpBook(tester, html: page('.book-content { font-size: 1em; }'));

      expect(laidOut(tester), TextDirection.ltr);
      expect(pager(tester), AxisDirection.right);
    });

    testWidgets('a book that declares nothing is laid out as it always was', (
      tester,
    ) async {
      await _pumpBook(tester, html: page('.book-content { font-size: 1em; }'));

      expect(laidOut(tester), TextDirection.ltr);
      expect(prose(tester), TextDirection.ltr);
      expect(pager(tester), AxisDirection.right);
      final inset = quotationInset(tester);
      expect(
        inset.start,
        greaterThan(inset.end),
        reason: 'the rule stays on the left where the book reads that way',
      );
    });

    testWidgets('an inert declaration is not a declaration', (tester) async {
      // `PrepareFinalHtml` keeps no `<html>`, so this rule applies to
      // nothing: a book saying the opposite of what the reader would read
      // out of a text search.
      await _pumpBook(
        tester,
        html: page('.book-content html[dir=rtl] { direction: rtl; }'),
      );

      expect(laidOut(tester), TextDirection.ltr);
    });

    testWidgets('a saved book reads the way the streamed one does', (
      tester,
    ) async {
      // A copy is the pages the server rendered (ADR-0009), stylesheet and
      // all, so the app is what reads the direction in both cases and a
      // reader on a train gets the same book. Nothing here asks the server.
      final (requested, _) = await _pumpBook(
        tester,
        saved: (root) => saveChapterFixture(
          root,
          _profileId,
          chapterId: 7,
          title: _title,
          pages: 3,
          format: MangaFormat.epub,
          pageHtml: page('.book-content { direction: rtl; }'),
        ),
      );

      expect(requested, isEmpty, reason: 'the copy is the page');
      expect(laidOut(tester), TextDirection.rtl);
      expect(prose(tester), TextDirection.rtl);
    });

    testWidgets('the chrome and its numerals never turn with the book', (
      tester,
    ) async {
      await _pumpBook(
        tester,
        html: page('.book-content { direction: rtl; }'),
      );
      await _showChrome(tester);

      // The counter is the app's own furniture and reads the app's own way,
      // whatever the book says.
      final counter = find.text('1 / $_pages');
      expect(counter, findsOneWidget);
      expect(Directionality.of(tester.element(counter)), TextDirection.ltr);
    });
  });
}
