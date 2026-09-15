import 'dart:convert';
import 'dart:io';

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
import 'package:patra/src/features/reader/book_page.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
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

/// What Kavita really writes for a page's pictures: a whole address with no
/// scheme in it, not a path inside the book.
const _addressedPicture =
    '<p><img src="//kavita.test/api/Book/7/book-resources'
    '?file=OEBPS/images/cover.jpg"/></p>';

/// A Kavita holding one book, in a Book library.
class _BookAdapter implements HttpClientAdapter {
  _BookAdapter({
    required this.requested,
    required this.posted,
    this.unavailable,
    this.html,
    this.progressPage = 0,
    this.bookScrollId,
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
        return _answer({
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'libraryType': LibraryType.book.id,
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

/// The reader on a book, and what it asked the server for.
///
/// [initialPage] is the page the route named, which is what the series screen
/// passes and what a link does not; [progressPage] and [bookScrollId] are what
/// the server says about where the reader was, which is what a book opens at.
/// [server] is that server, where a test needs the same one twice — a book
/// closed and opened again, which is the round trip.
Future<(List<int> requested, List<_Post> posted)> _pumpBook(
  WidgetTester tester, {
  int initialPage = 0,
  int? unavailable,
  String? html,
  int progressPage = 0,
  String? bookScrollId,
  _BookAdapter? server,
}) async {
  final dir = mockPathProvider();
  final downloads = DownloadsService(
    root: Directory('${dir.path}/downloads')..createSync(),
    profileId: 'https://kavita.test#1',
  );
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

/// Where the page on screen is scrolled to, read out of the render tree
/// rather than off anything the reader said about it.
ScrollPosition _pagePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// A page longer than the screen it is read on, which is the only case in
/// which there is a place within a page to be asked about.
///
/// Words rather than a picture: a picture fetched from a server a test does
/// not have is a picture with no height at all, and a page of nothing is not
/// a page that scrolls.
final String _longPage = [
  for (var i = 0; i < 40; i++) '<p>Paragraph $i of a long page.</p>',
].join();

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

    expect(requested, [0], reason: 'the first page is the one asked for');
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

    expect(requested, [4]);
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

    expect(fromLink, [4], reason: 'a link names no page at all');
    expect(fromSeries, [
      4,
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

    expect(requested, [0, 1]);
    expect(_postedPages(posted), [0, 1]);
    await _showChrome(tester);
    expect(find.text('2 / $_pages'), findsOneWidget);
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

  testWidgets('a picture the page addresses with no scheme is drawn', (
    tester,
  ) async {
    await _pumpBook(tester, html: _addressedPicture);

    final pictures = tester.widgetList<Image>(find.byType(Image));
    expect(pictures, hasLength(1));
    final cached = pictures.single.image as CachedNetworkImageProvider;
    // Asked for as the page wrote it, with this server's scheme in front: a
    // whole address wrapped into `book-resources` as though it were a path
    // inside the book is answered with a 400, and the page that carried it —
    // a cover's, which has no words — is then drawn as nothing at all.
    expect(
      cached.url,
      startsWith('http://kavita.test/api/Book/7/book-resources'),
    );
    expect(cached.url, contains('file=OEBPS/images/cover.jpg'));
    expect(cached.url, isNot(contains('%2F%2F')));
    expect(cached.cacheKey, imageCacheKey(cached.url));
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

  group('where a page sits in the screen', () {
    /// A phone's screen, and a page in it whose one picture is [height] tall
    /// — which is what a test can say about a picture it cannot fetch.
    const height = 800.0;

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
              width: 400,
              height: height,
              child: BookPageBody(
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
    Future<void> pumpWords(WidgetTester tester, String html) async {
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
                page: BookPage.fromHtml(html),
                picture: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('prose is justified, and a title is not', (tester) async {
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
        // Both edges of the column are straight, which is what the eye reads
        // a block of prose by — but a title is not prose and a list item is
        // a line, and stretching either opens holes in a handful of words.
        TextAlign.start, // the title
        TextAlign.justify, // the paragraph
        TextAlign.justify, // the quotation
        TextAlign.start, // the bullet
        TextAlign.start, // the item
      ]);
    });
  });
}
