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
  });

  /// Every page the reader asked the server for, in order.
  final List<int> requested;

  /// Every progress post, as the page number inside it.
  final List<int> posted;

  /// A page the server cannot produce.
  final int? unavailable;

  /// What every page is made of, where a test has a page of its own: the
  /// server's HTML is not what any assertion here is about, but the address
  /// a picture is named by is.
  final String? html;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    switch (options.path) {
      case '/api/Reader/progress':
        posted.add((options.data as Map<String, dynamic>)['pageNum'] as int);
        return _answer('{}', json: true);
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

/// The reader on a book, and what it asked the server for.
Future<(List<int> requested, List<int> posted)> _pumpBook(
  WidgetTester tester, {
  int initialPage = 0,
  int? unavailable,
  String? html,
}) async {
  final dir = mockPathProvider();
  final downloads = DownloadsService(
    root: Directory('${dir.path}/downloads')..createSync(),
    profileId: 'https://kavita.test#1',
  );
  final requested = <int>[];
  final posted = <int>[];
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  final adapter = _BookAdapter(
    requested: requested,
    posted: posted,
    unavailable: unavailable,
    html: html,
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
  return (requested, posted);
}

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
    expect(posted, [0], reason: 'opening a book says where it was opened');
    await _showChrome(tester);
    // Twelve, which is what the book says: `chapter-info` counted no pages
    // at all, so a reader that asked it instead would show nothing.
    expect(find.text('1 / $_pages'), findsOneWidget);
  });

  testWidgets('a book opens where reading left off', (tester) async {
    final (requested, posted) = await _pumpBook(tester, initialPage: 4);

    expect(requested, [4]);
    expect(posted, [4]);
    await _showChrome(tester);
    expect(find.text('5 / $_pages'), findsOneWidget);
  });

  testWidgets('a swipe turns the page, and the counter follows', (
    tester,
  ) async {
    final (requested, posted) = await _pumpBook(tester);

    await _swipe(tester);

    expect(requested, [0, 1]);
    expect(posted, [0, 1]);
    await _showChrome(tester);
    expect(find.text('2 / $_pages'), findsOneWidget);
  });

  testWidgets('the sides of the screen turn the page', (tester) async {
    final (requested, posted) = await _pumpBook(tester);
    final size = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(size.width * .85, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(posted, [0, 1], reason: 'the right-hand side reads on');
    // The page it turned to is the page it asked the server for.
    expect(requested, contains(1));

    await tester.tapAt(Offset(size.width * .15, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(posted, [0, 1, 0], reason: 'the left-hand side reads back');
  });

  testWidgets('the last page reports the whole book', (tester) async {
    final (_, posted) = await _pumpBook(tester, initialPage: _pages - 1);

    // Kavita marks a chapter read at `pagesRead >= pages`, so the last page
    // is posted as the total rather than as its own number.
    expect(posted, [_pages]);
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
                picture: (_) => SizedBox(
                  key: const Key('picture'),
                  height: pictureHeight,
                ),
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
