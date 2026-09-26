import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/book_markup.dart';
import 'package:patra/src/features/reader/book_page.dart';
import 'package:patra/src/features/reader/book_web_page.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'book_reader_harness.dart';
import 'test_support.dart';

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

void main() {
  testWidgets('a book opens on its first page', (tester) async {
    final (requested, posted) = await pumpBook(tester);

    expect(askedPages(requested), [
      0,
      1,
    ], reason: 'the page it opens on, and the one beside it');
    expect(postedPages(posted), [
      0,
    ], reason: 'opening a book says where it was opened');
    await showBookChrome(tester);
    // Twelve, which is what the book says: `chapter-info` counted no pages
    // at all, so a reader that asked it instead would show nothing.
    expect(find.text('1 / $bookPages'), findsOneWidget);
  });

  testWidgets('a book opens where reading left off', (tester) async {
    final (requested, posted) = await pumpBook(tester, progressPage: 4);

    expect(askedPages(requested), [3, 4, 5]);
    expect(postedPages(posted), [4]);
    await showBookChrome(tester);
    expect(find.text('5 / $bookPages'), findsOneWidget);
  });

  testWidgets('a book opened from a link lands in the same place', (
    tester,
  ) async {
    // What a link carries is a chapter and nothing else: no page, and no
    // place within one. The series screen does name a page, and it is not the
    // one that counts — so the two ways in are made to disagree here, and
    // both have to land on the server's.
    final (fromLink, linkPosted) = await pumpBook(tester, progressPage: 4);
    final (fromSeries, _) = await pumpBook(
      tester,
      initialPage: 7,
      progressPage: 4,
    );

    expect(askedPages(fromLink), [
      3,
      4,
      5,
    ], reason: 'a link names no page at all');
    expect(askedPages(fromSeries), [
      3,
      4,
      5,
    ], reason: 'the page the route named is not the one a book opens at');
    expect(postedPages(linkPosted), [4]);
  });

  testWidgets('a swipe turns the page, and the counter follows', (
    tester,
  ) async {
    final (requested, posted) = await pumpBook(tester);

    await swipeBookPage(tester);

    expect(askedPages(requested), [0, 1, 2]);
    expect(postedPages(posted), [0, 1]);
    await showBookChrome(tester);
    expect(find.text('2 / $bookPages'), findsOneWidget);
  });

  testWidgets('a page turned to is already in hand', (tester) async {
    final (requested, _) = await pumpBook(tester);

    // The next page is fetched while the reader is at rest on this one, not
    // when it is turned to: `PageView.builder` mounts a page as late as it
    // can, so a page asked for only then is a page fetched under the
    // reader's finger.
    expect(askedPages(requested), [0, 1]);

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
    final (requested, _) = await pumpBook(tester);

    await swipeBookPage(tester);
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    // Three pages, each asked for once. A page the pager unmounts is a page
    // an autoDispose provider forgets, and reading back used to re-fetch it —
    // and to draw the spinner again while it came.
    expect(askedPages(requested), [0, 1, 2]);
  });

  testWidgets('the sides of the screen turn the page', (tester) async {
    final (requested, posted) = await pumpBook(tester);
    final size = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(size.width * .85, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(postedPages(posted), [0, 1], reason: 'the right-hand side reads on');
    // The page it turned to is the page it asked the server for.
    expect(requested, contains(1));

    await tester.tapAt(Offset(size.width * .15, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(postedPages(posted), [
      0,
      1,
      0,
    ], reason: 'the left-hand side reads back');
  });

  testWidgets('the last page reports the whole book', (tester) async {
    final (_, posted) = await pumpBook(
      tester,
      initialPage: bookPages - 1,
      progressPage: bookPages - 1,
    );

    // Kavita marks a chapter read at `pagesRead >= pages`, so the last page
    // is posted as the total rather than as its own number.
    expect(postedPages(posted), [bookPages]);
  });

  testWidgets('the bar names the book', (tester) async {
    await pumpBook(tester);

    await showBookChrome(tester);
    // The title Kavita read out of the file, not the series it belongs to.
    expect(find.text(bookTitle), findsOneWidget);
    expect(find.text('Dune'), findsNothing);
  });

  testWidgets('the cog offers how the book is set, and nothing else', (
    tester,
  ) async {
    await pumpBook(tester);
    await showBookChrome(tester);
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

  testWidgets('a page the server cannot produce says so', (tester) async {
    await pumpBook(tester, unavailable: 1);

    await swipeBookPage(tester);

    // Rather than an empty screen, which reads as a book with no words in it.
    expect(find.text('This page could not be loaded.'), findsOneWidget);
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
      await pumpBook(tester);
      await showBookChrome(tester);

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
      final (requested, posted) = await pumpBook(tester);
      await showBookChrome(tester);

      await choose(tester, 'The worm');

      // Page 5 is the one the server named for that chapter, and it is both
      // the page asked for and the progress reported for it: a reader who
      // has chosen a chapter has read their way to where it begins.
      expect(requested.last, 5);
      expect(postedPages(posted).last, 5);
    });

    testWidgets('choosing a part moves the reader to the page it begins on', (
      tester,
    ) async {
      final (requested, posted) = await pumpBook(tester);
      await showBookChrome(tester);

      await choose(tester, 'Part two');

      expect(requested.last, 8);
      expect(postedPages(posted).last, 8);
    });

    testWidgets('a book the server listed nothing for offers none', (
      tester,
    ) async {
      await pumpBook(tester, contents: const []);
      await showBookChrome(tester);

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

  // A copy saved before a copy was a directory carried its pictures inside
  // its pages (ADR-0009), and such a copy still opens: the name is the bytes.
  group('what a stored page carries', () {
    const carried = 'data:;base64,QUJD';

    test('the bytes a name carries, and nothing else', () {
      expect(carriedPictureBytes(carried), [65, 66, 67]);
      // A name that is a path, and one that is a damaged copy: neither is
      // something this device already has.
      expect(carriedPictureBytes('OEBPS/worm.jpg'), isNull);
      expect(carriedPictureBytes('data:;base64,!!!'), isNull);
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
          find
              .descendant(
                of: find.byType(PageView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .axisDirection;

    /// The direction the page itself is laid out in, which is what the pager
    /// turns on.
    ///
    /// Read where the pager is rather than inside a page, so it asks the
    /// reader and not whichever renderer draws the page.
    TextDirection laidOut(WidgetTester tester) =>
        Directionality.of(tester.element(find.byType(PageView)));

    testWidgets('and its pages turn the way it reads', (tester) async {
      // Doing only the text half would produce a book that reads
      // right-to-left while its pages turn left-to-right — worse than
      // leaving it as it is. The pager is inside the book's own
      // `Directionality`, so it mirrors with the words.
      final (requested, posted) = await pumpBook(
        tester,
        html: page('.book-content { direction: rtl; }'),
      );
      final size = tester.getSize(find.byType(Scaffold));

      await tester.tapAt(Offset(size.width * .15, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(postedPages(posted), [
        0,
        1,
      ], reason: 'the left-hand side reads on in a book that reads that way');
      expect(requested, contains(1));

      await tester.tapAt(Offset(size.width * .85, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(postedPages(posted), [0, 1, 0]);
    });

    testWidgets('the library the server names cannot turn a book', (
      tester,
    ) async {
      // The regression #118 shipped with, at the level a reader meets it.
      // `chapter-info` reports `libraryType: 0` for a book — measured on all
      // 53 epubs of the demo server's *Books* library, and since #120 known
      // to be what every Kavita sends for everything — so wiring the book
      // reader into the chain let the manga convention answer for every book
      // on every server, not merely for one shelved oddly. Nothing is
      // measured of a book now, and nothing anywhere reads the type it names.
      await pumpBook(tester, html: page('.book-content { font-size: 1em; }'));

      expect(laidOut(tester), TextDirection.ltr);
      expect(pager(tester), AxisDirection.right);
    });

    testWidgets('an inert declaration is not a declaration', (tester) async {
      // `PrepareFinalHtml` keeps no `<html>`, so this rule applies to
      // nothing: a book saying the opposite of what the reader would read
      // out of a text search.
      await pumpBook(
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
      final (requested, _) = await pumpBook(
        tester,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          title: bookTitle,
          pages: 3,
          format: MangaFormat.epub,
          pageHtml: page('.book-content { direction: rtl; }'),
        ),
      );

      expect(requested, isEmpty, reason: 'the copy is the page');
      expect(laidOut(tester), TextDirection.rtl);
    });

    testWidgets('the chrome and its numerals never turn with the book', (
      tester,
    ) async {
      await pumpBook(tester, html: page('.book-content { direction: rtl; }'));
      await showBookChrome(tester);

      // The counter is the app's own furniture and reads the app's own way,
      // whatever the book says.
      final counter = find.text('1 / $bookPages');
      expect(counter, findsOneWidget);
      expect(Directionality.of(tester.element(counter)), TextDirection.ltr);
    });
  });

  // The language a book is written in is the book's, and it is what the
  // engine will hyphenate in (#122). Kavita sends it on the call the series
  // screen already makes, so the normal way in costs nothing; a link has no
  // series screen behind it and is the one case that asks for itself (#125).
  group('the language a book is written in', () {
    /// The series as the series screen leaves it on the device: its one
    /// volume, holding this chapter, with whatever language the server gave.
    List<Volume> heldSeries({String? language}) => [
      Volume(
        id: 4,
        name: '1',
        minNumber: 1,
        pages: bookPages,
        pagesRead: 0,
        chapters: [
          Chapter(
            id: 7,
            title: bookTitle,
            titleName: bookTitle,
            range: '1',
            minNumber: 1,
            pages: bookPages,
            pagesRead: 0,
            isSpecial: false,
            format: MangaFormat.epub,
            language: language,
          ),
        ],
      ),
    ];

    // Asked of the web engine, which is what a reader's page is drawn by:
    // what it does with the language is *the web engine*'s question, and
    // what is asked here is what the reader obtained and what it cost.
    setUp(() => WebViewPlatform.instance = _FakeWebEngine());

    /// The page the engine was handed, once the files it is written into
    /// have landed.
    Future<BookWebPage> handed(WidgetTester tester) async {
      await settleBookFiles(tester);
      return tester.widget<BookWebPage>(find.byType(BookWebPage));
    }

    /// The language the page on screen was handed.
    Future<String?> drawnIn(WidgetTester tester) async =>
        (await handed(tester)).language;

    BookAdapter server({String? language = 'en'}) => BookAdapter(
      requested: <int>[],
      posted: <BookPost>[],
      language: language,
    );

    testWidgets('opened from the series screen, it costs no request', (
      tester,
    ) async {
      final adapter = server(language: 'de');
      await pumpBook(
        tester,
        webEngine: true,
        server: adapter,
        held: heldSeries(language: 'fr'),
      );

      expect(
        await drawnIn(tester),
        'fr',
        reason: 'what the series screen stored',
      );
      expect(adapter.chapterAsked, 0);
    });

    testWidgets('opened from a link, it is asked for', (tester) async {
      final adapter = server(language: 'fr-CA');
      await pumpBook(tester, webEngine: true, server: adapter);

      expect(await drawnIn(tester), 'fr-CA');
      expect(adapter.chapterAsked, 1, reason: 'once, and only here');
    });

    testWidgets('a book the server gives no language has none', (tester) async {
      // Held with none, which is the server's answer and not an absence:
      // asking again would be asking the same question for the same answer,
      // and nothing — the interface, the library, the profile — stands in.
      final adapter = server(language: null);
      await pumpBook(
        tester,
        webEngine: true,
        server: adapter,
        held: heldSeries(),
      );

      expect(await drawnIn(tester), isNull);
      expect(adapter.chapterAsked, 0);

      final linked = server(language: null);
      await pumpBook(tester, webEngine: true, server: linked);
      expect(await drawnIn(tester), isNull);
      expect(linked.chapterAsked, 1);
    });

    testWidgets('a saved copy is read in the language it was made with', (
      tester,
    ) async {
      final adapter = server(language: 'en');
      await pumpBook(
        tester,
        webEngine: true,
        server: adapter,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          seriesId: 3,
          title: bookTitle,
          pages: 3,
          format: MangaFormat.epub,
          language: 'fr',
          pageHtml: '<p>La spice doit couler.</p>',
        ),
      );

      // The server says English today; the copy was made in French, and a
      // copy is read as it was made.
      expect(await drawnIn(tester), 'fr');
      // And a copy that says costs nothing to ask, though nothing of the
      // series is held — the way in from the Downloads tab.
      expect(adapter.chapterAsked, 0);
    });

    testWidgets('a saved copy is read in its language with no server', (
      tester,
    ) async {
      await pumpBook(
        tester,
        webEngine: true,
        offline: true,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          seriesId: 3,
          title: bookTitle,
          pages: 3,
          format: MangaFormat.epub,
          language: 'fr',
          pageHtml: '<p>La spice doit couler.</p>',
        ),
      );

      expect((await handed(tester)).html, contains('La spice doit couler.'));
      expect(await drawnIn(tester), 'fr');
    });

    testWidgets('a copy saved before its language was recorded still opens', (
      tester,
    ) async {
      await pumpBook(
        tester,
        webEngine: true,
        offline: true,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          seriesId: 3,
          title: bookTitle,
          pages: 3,
          format: MangaFormat.epub,
          pageHtml: '<p>The spice must flow.</p>',
        ),
      );

      expect((await handed(tester)).html, contains('The spice must flow.'));
      expect(await drawnIn(tester), isNull);
    });
  });

  group('the web engine', () {
    // Where the platform has an engine — Android and iOS — a page is drawn by
    // it, and nothing of it paints under a test binding. What can be asked
    // is what a reader or the server would observe: the document the engine
    // was handed, what was fetched and how, and what was posted.
    late _FakeWebEngine engine;
    setUp(() => WebViewPlatform.instance = engine = _FakeWebEngine());

    /// Lets the files a page is written into land: real I/O, which a test's
    /// clock does not move.
    Future<void> settle(WidgetTester tester) => settleBookFiles(tester);

    testWidgets('draws the page it was handed, made inert, from a file', (
      tester,
    ) async {
      await pumpBook(
        tester,
        webEngine: true,
        html:
            '<p onclick="steal()">The spice must flow.</p>'
            '<script>steal()</script>'
            '<img src="OEBPS/images/worm.jpg"/>',
      );
      await settle(tester);

      final page = engine.pageShowing(0)!;
      expect(page.javaScript, JavaScriptMode.unrestricted);
      expect(page.bridge, 'PatraBridge');
      final document = page.document!;
      expect(document, contains('Content-Security-Policy'));
      expect(document, contains('<html lang="en">'));
      expect(document, contains('The spice must flow.'));
      expect(document.toLowerCase(), isNot(contains('steal')));
      // Nothing addressed at the server: the page could send no header.
      expect(document, isNot(contains('kavita.test')));
      expect(document, isNot(contains('OEBPS/images')));
    });

    testWidgets('a book is justified and hyphenated in its own language, '
        'not the interface\'s', (tester) async {
      // An English book read by somebody whose app speaks French: the words
      // are the book's, and so are the rules they are broken by (#130).
      await pumpBook(
        tester,
        webEngine: true,
        locale: const Locale('fr'),
        server: BookAdapter(
          requested: <int>[],
          posted: <BookPost>[],
          language: 'en',
        ),
      );
      await settle(tester);

      final document = engine.pageShowing(0)!.document!;
      expect(document, contains('<html lang="en">'));
      expect(document, contains('text-align: justify'));
      expect(document, contains('hyphens: auto'));
    });

    testWidgets('a book in no known language is left ragged right', (
      tester,
    ) async {
      await pumpBook(
        tester,
        webEngine: true,
        locale: const Locale('fr'),
        server: BookAdapter(
          requested: <int>[],
          posted: <BookPost>[],
          language: null,
        ),
      );
      await settle(tester);

      final document = engine.pageShowing(0)!.document!;
      // Nothing inferred from the interface, and nothing to justify with.
      expect(document, contains('<html>'));
      expect(document, isNot(contains('text-align: justify')));
      expect(document, isNot(contains('hyphens: auto')));
    });

    testWidgets("a page's pictures are fetched by the app, and drawn from "
        'the file beside the page', (tester) async {
      late BookAdapter server;
      await pumpBook(
        tester,
        webEngine: true,
        html: '<p>a</p><img src="OEBPS/images/worm.jpg"/>$addressedPicture',
        onServer: (it) => server = it,
      );
      await settle(tester);

      final asked = {
        for (final request in server.resources)
          request.uri.queryParameters['file'],
      };
      expect(
        asked,
        containsAll(['OEBPS/images/worm.jpg', 'OEBPS/images/cover.jpg']),
      );
      for (final request in server.resources) {
        // With the client's own headers, which is the only way these are had.
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.uri.host, 'kavita.test');
      }

      final page = engine.pageShowing(0)!;
      final pictures = RegExp(r'<img src="([^"]*)"')
          .allMatches(page.document!)
          .map((match) => match.group(1)!)
          .toList();
      expect(pictures, hasLength(2));
      final directory = File(page.file!).parent.path;
      for (final picture in pictures) {
        expect(picture, startsWith('file:///'));
        final file = File.fromUri(Uri.parse(picture));
        // Inside the directory the page is read from, which is all an engine
        // on iOS is allowed to read.
        expect(file.path, startsWith(directory));
        expect(file.readAsBytesSync(), base64Decode(carriedPng));
      }
    });

    testWidgets("the reader's settings reach the document", (tester) async {
      await pumpBook(tester, webEngine: true);
      await settle(tester);
      final document = engine.pageShowing(0)!.document!;
      expect(document, contains('@layer patra'));
      expect(document, contains('!important'));
    });

    testWidgets('progress is posted as it always was', (tester) async {
      final (_, posted) = await pumpBook(
        tester,
        webEngine: true,
        progressPage: 2,
      );
      await settle(tester);
      expect(postedPages(posted), [2]);

      // Where in the page the reader came to rest, as the app's own bridge
      // tells it: the same call, the same field.
      engine.pageShowing(2)!.tell('{"block":3,"at":0.25}');
      await settle(tester);
      expect(posted.last, (pageNum: 2, anchor: 'patra:3@0.2500'));
    });

    testWidgets('a book opens again on the words it was left at', (
      tester,
    ) async {
      await pumpBook(
        tester,
        webEngine: true,
        progressPage: 2,
        bookScrollId: 'patra:12@0.4000',
      );
      await settle(tester);
      // The page is put at the block the reader was in, however the words
      // are laid out today — not at a share of the page's height.
      expect(engine.pageShowing(2)!.placedAt, {'block': 12, 'at': .4});
    });

    testWidgets('a place stored as a bare fraction still opens near where it '
        'meant', (tester) async {
      // Written before there were blocks, and already on servers: a share
      // of the page as a whole, which is what it meant then.
      await pumpBook(
        tester,
        webEngine: true,
        progressPage: 2,
        bookScrollId: '0.5000',
      );
      await settle(tester);
      expect(engine.pageShowing(2)!.placedAt, {'at': .5});
    });

    testWidgets('a book with nothing recorded is put nowhere', (tester) async {
      await pumpBook(tester, webEngine: true, progressPage: 2);
      await settle(tester);
      expect(engine.pageShowing(2)!.placedAt, isNull);
    });

    for (final (what, change) in <(String, void Function(ProviderContainer))>[
      ('text size', (it) => it.read(bookTextSizeProvider.notifier).preview(30)),
      (
        'line spacing',
        (it) => it.read(bookLineHeightProvider.notifier).preview(2),
      ),
      (
        'reading face',
        (it) {
          final face = it.read(bookReadingFaceProvider);
          it
              .read(bookReadingFaceProvider.notifier)
              .set(
                face == ReadingFace.serif
                    ? ReadingFace.sans
                    : ReadingFace.serif,
              );
        },
      ),
    ]) {
      testWidgets('changing the $what mid-page keeps the reader on the same '
          'words', (tester) async {
        await pumpBook(tester, webEngine: true, progressPage: 2);
        await settle(tester);
        final first = engine.pageShowing(2)!;
        first.tell('{"block":7,"at":0.6}');
        await settle(tester);

        change(
          ProviderScope.containerOf(tester.element(find.byType(ReaderScreen))),
        );
        await settle(tester);

        final again = engine.pageShowing(2)!;
        final loads = identical(first, again) ? again.loads - 1 : again.loads;
        expect(loads, greaterThan(0), reason: 'the page is set again');
        expect(again.placedAt, {'block': 7, 'at': .6});
      });
    }

    testWidgets('a saved copy keeps the place, after the server has it too', (
      tester,
    ) async {
      final (_, posted) = await pumpBook(
        tester,
        webEngine: true,
        progressPage: 1,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          seriesId: 3,
          title: bookTitle,
          pages: 3,
          format: MangaFormat.epub,
          pageHtml: '<p>La spice doit couler.</p>',
        ),
      );
      await settle(tester);
      engine.pageShowing(1)!.tell('{"block":4,"at":0.5}');
      await settle(tester);
      expect(posted.last, (pageNum: 1, anchor: 'patra:4@0.5000'));

      final saved = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      ).read(savedChapterProvider(7))!;
      // The server took it, so there is nothing left to send — and the copy
      // still knows where its reader is, for the train.
      expect(saved.pending, isNull);
      expect(
        saved.place,
        const PendingProgress(pageNum: 1, bookScrollId: 'patra:4@0.5000'),
      );
    });

    testWidgets('where the reader is, written into the copy, does not read '
        'the page again', (tester) async {
      // The copy is written every time a scroll settles; a page taken apart
      // again on every one is seconds of work for a page of megabytes.
      await pumpBook(
        tester,
        webEngine: true,
        progressPage: 1,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          seriesId: 3,
          title: bookTitle,
          pages: 3,
          format: MangaFormat.epub,
          pageHtml: '<p>La spice doit couler.</p>',
        ),
      );
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      );
      var read = 0;
      final listening = container.listen(
        bookPageProvider((chapterId: 7, page: 1)),
        (_, next) {
          if (next.hasValue && !next.isLoading) read++;
        },
      );
      addTearDown(listening.close);

      engine.pageShowing(1)!.tell('{"block":0,"at":0.5}');
      await settle(tester);
      engine.pageShowing(1)!.tell('{"block":0,"at":0.7}');
      await settle(tester);

      expect(
        container.read(savedChapterProvider(7))!.place!.bookScrollId,
        'patra:0@0.7000',
      );
      expect(read, 0);
    });

    testWidgets('a saved copy opens with no server on the words it was left '
        'at', (tester) async {
      await pumpBook(
        tester,
        webEngine: true,
        offline: true,
        saved: (root) async {
          final copy = await saveChapterFixture(
            root,
            bookProfileId,
            chapterId: 7,
            seriesId: 3,
            title: bookTitle,
            pages: 3,
            format: MangaFormat.epub,
            pageHtml: '<p>La spice doit couler.</p>',
          );
          await DownloadsService(
            root: root,
            profileId: bookProfileId,
          ).writeMeta(
            copy.copyWith(
              place: const PendingProgress(
                pageNum: 2,
                bookScrollId: 'patra:9@0.2500',
              ),
            ),
          );
        },
      );
      await settle(tester);
      expect(engine.pageShowing(2)!.placedAt, {'block': 9, 'at': .25});
    });

    testWidgets('the sides of the screen still turn the page', (tester) async {
      final (_, posted) = await pumpBook(tester, webEngine: true);
      await settle(tester);
      final size = tester.getSize(find.byType(Scaffold));
      await tester.tapAt(Offset(size.width - 10, size.height / 2));
      await settle(tester);
      expect(postedPages(posted), [0, 1]);
      expect(engine.pageShowing(1), isNotNull);
    });

    testWidgets('a swipe still turns the page', (tester) async {
      final (_, posted) = await pumpBook(tester, webEngine: true);
      await settle(tester);
      await swipeBookPage(tester);
      await settle(tester);
      expect(postedPages(posted), [0, 1]);
    });

    testWidgets('a book declared right to left still turns from the right', (
      tester,
    ) async {
      await pumpBook(
        tester,
        webEngine: true,
        html: '<style>.book-content { direction: rtl }</style><p>a</p>',
      );
      await settle(tester);
      final pager = find.byType(PageView);
      expect(Directionality.of(tester.element(pager)), TextDirection.rtl);
      // And the engine is handed the declaration itself.
      expect(engine.pageShowing(0)!.document, contains('direction: rtl'));
    });

    // What a reader on a train opens is the book they would have read at
    // home: the same document, set in the book's own face, in its language
    // — its pictures and its face files beside the page rather than at an
    // address that is dead offline (#129).
    testWidgets('a saved book with no server is handed the document the '
        'streamed one is', (tester) async {
      const html =
          '<style>'
          '@font-face { font-family: "Book Face"; src: url("//kavita.test/api/'
          'book/7/book-resources?apiKey=key&file=fonts/face.woff2") '
          'format("woff2") }'
          '.book-content p { font-family: "Book Face", serif }'
          '</style>'
          '<p>La spice doit couler.</p>'
          '<p><img src="OEBPS/images/worm.jpg"/></p>'
          '$addressedPicture';
      BookAdapter server() =>
          BookAdapter(requested: [], posted: [], html: html, language: 'fr');

      /// The document the engine was handed, with the directory it was
      /// written in named the same way whichever run wrote it.
      String handed() {
        final page = engine.pageShowing(0)!;
        return page.document!.replaceAll(
          File(page.file!).parent.path,
          '<pages>',
        );
      }

      await pumpBook(tester, webEngine: true, server: server());
      await settle(tester);
      final streamed = handed();

      engine.pages.clear();
      await pumpBook(
        tester,
        webEngine: true,
        offline: true,
        saved: (root) =>
            saveThroughDownloader(tester, root, server(), language: 'fr'),
      );
      await settle(tester);
      final stored = handed();

      expect(stored, streamed);
      // Which is a page hyphenated in its own language, set in its own face,
      // and drawn with its pictures — every one of them a file the engine
      // can read with no server.
      expect(stored, contains('<html lang="fr">'));
      final page = engine.pageShowing(0)!;
      final files = RegExp(r'url\("?(file:[^")]*)|src="(file:[^"]*)"')
          .allMatches(page.document!)
          .map((match) => match.group(1) ?? match.group(2)!)
          .toList();
      expect(files, hasLength(3), reason: 'the face and two pictures');
      for (final file in files) {
        expect(
          File.fromUri(Uri.parse(file)).readAsBytesSync(),
          base64Decode(carriedPng),
        );
      }
    });

    // A copy saved before a copy was a directory carries its pictures inside
    // its pages. Such a page is still valid, and it opens as it is: nothing
    // is migrated, and nothing is fetched again.
    testWidgets('a copy saved before it was a directory still opens, its '
        'pictures carried', (tester) async {
      await pumpBook(
        tester,
        webEngine: true,
        offline: true,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          seriesId: 3,
          title: bookTitle,
          pages: 3,
          format: MangaFormat.epub,
          language: 'fr',
          pageHtml:
              '<p>La spice doit couler.</p>'
              '<img src="data:image/png;base64,$carriedPng"/>',
        ),
      );
      await settle(tester);
      final document = engine.pageShowing(0)!.document!;
      expect(document, contains('<html lang="fr">'));
      expect(document, contains('La spice doit couler.'));
      expect(document, contains('src="data:image/png;base64,$carriedPng"'));
    });

    // A copy saved before a copy was a directory carries its pictures inside
    // its pages, and pages of several megabytes were measured on a device:
    // taken apart on the thread the app draws on, three of them were an ANR.
    // Past a size, a page is taken apart and rewritten in an isolate — and
    // still opens, from the copy or from the server. The development
    // renderer's own case is in `development_book_page_test.dart`.
    final heavy =
        '<p>The spice must flow.</p>'
        '<p title="${'A' * (BookPage.parsesInPlaceBelow * 2)}">.</p>';
    Future<void> saveHeavy(Directory root) => saveChapterFixture(
      root,
      bookProfileId,
      chapterId: 7,
      seriesId: 3,
      title: bookTitle,
      pages: 3,
      format: MangaFormat.epub,
      pageHtml: heavy,
    );

    testWidgets('a heavy saved page still opens, in the web engine', (
      tester,
    ) async {
      await pumpBook(tester, webEngine: true, offline: true, saved: saveHeavy);
      await settle(tester);
      expect(engine.pageShowing(0)!.document, contains('The spice must flow.'));
    });

    testWidgets('a heavy page from the server still opens', (tester) async {
      await pumpBook(tester, webEngine: true, html: heavy);
      await settle(tester);
      expect(engine.pageShowing(0)!.document, contains('The spice must flow.'));
    });

    testWidgets('goes nowhere but the page it was handed', (tester) async {
      await pumpBook(tester, webEngine: true);
      await settle(tester);
      final page = engine.pageShowing(0)!;
      final own = Uri.file(page.file!).toString();
      expect(await page.ask(own), NavigationDecision.navigate);
      expect(await page.ask('$own#note-1'), NavigationDecision.navigate);
      expect(
        await page.ask('https://tracker.example/'),
        NavigationDecision.prevent,
      );
      expect(await page.ask('file:///etc/passwd'), NavigationDecision.prevent);
    });
  });
}

/// A web engine that paints nothing and remembers what it was handed.
class _FakeWebEngine extends WebViewPlatform {
  final pages = <_FakeWebPage>[];

  /// The last page loaded with the document for [page] of the book.
  _FakeWebPage? pageShowing(int page) => pages.reversed
      .where((it) => it.file?.endsWith('/7-$page.html') ?? false)
      .firstOrNull;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final page = _FakeWebPage(params);
    pages.add(page);
    return page;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigation(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebView(params);
}

class _FakeWebPage extends PlatformWebViewController {
  _FakeWebPage(super.params) : super.implementation();

  JavaScriptMode? javaScript;
  String? bridge;
  void Function(JavaScriptMessage)? _bridge;
  _FakeNavigation? _navigation;

  /// The file the page was loaded from, and what it held when it was.
  String? file;
  String? document;

  /// What the app's own bridge says, as the page's script would say it.
  void tell(String message) => _bridge!(JavaScriptMessage(message: message));

  /// Whether the page may go to [url].
  Future<NavigationDecision> ask(String url) async =>
      _navigation!.onNavigationRequest!(
        NavigationRequest(url: url, isMainFrame: true),
      );

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async =>
      javaScript = mode;

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    bridge = params.name;
    _bridge = params.onMessageReceived;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => _navigation = handler as _FakeNavigation;

  @override
  Future<void> loadFile(String absoluteFilePath) async {
    file = absoluteFilePath;
    loads++;
    document = File(absoluteFilePath).readAsStringSync();
    _navigation?.onPageFinished?.call(Uri.file(absoluteFilePath).toString());
  }

  /// How many times a document has been loaded into this page.
  var loads = 0;

  /// The app's own scripts, in the order they were run.
  final scripts = <String>[];

  /// Where the latest script put the page: the place it was told, as the
  /// bridge reads it, or null for a page left at its top.
  Object? get placedAt {
    final told = RegExp(r'var anchor = (.*?);\n').firstMatch(scripts.last);
    return jsonDecode(told!.group(1)!);
  }

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);
}

class _FakeNavigation extends PlatformNavigationDelegate {
  _FakeNavigation(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageFinished;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback handler,
  ) async => onNavigationRequest = handler;

  @override
  Future<void> setOnPageFinished(PageEventCallback handler) async =>
      onPageFinished = handler;
}

class _FakeWebView extends PlatformWebViewWidget {
  _FakeWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
