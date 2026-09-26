/// **The development renderer — not what ships.**
///
/// Every test here describes the page the app draws *itself*, in Flutter,
/// out of the blocks the parser takes a page apart into
/// (`features/reader/development/`). That renderer is kept because it is the
/// only way to look at a page of a book without a phone — the web view plugin
/// has no Linux implementation — and it is allowed to drift (#131). What a
/// reader sees on Android and iOS is the platform's web engine
/// (`book_web_page.dart`, ADR-0013), and nothing here says anything about it:
/// a green run of this file is a claim about a development tool.
///
/// What a reader sees is pinned — as far as a test binding can pin an engine
/// that does not paint under it — by `book_reader_test.dart` (*the web
/// engine*), `book_rewrite_test.dart` and `book_document_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/features/reader/book_page.dart';
import 'package:patra/src/features/reader/development/development_book_page.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/theme.dart';

import 'book_reader_harness.dart';
import 'test_support.dart';

/// Where the page on screen is scrolled to, read out of the render tree
/// rather than off anything the reader said about it.
///
/// Asked for inside the page itself, because a sheet open over the reader
/// scrolls too.
ScrollPosition _pagePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(DevelopmentBookPage),
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
const _everyBlock =
    '<h2>Book two</h2>'
    '<p>The spice must flow, and the worm <b>follows</b>.</p>'
    '<blockquote>A beginning is a very delicate time.</blockquote>'
    '<ul><li>First.</li><li>Second.</li></ul>';

void main() {
  group('the development renderer is not shipped', () {
    final renderer = RegExp(r"import '[^']*development/[^']*';");

    test('nothing but the reader reaches it', () {
      final importers = [
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              !file.path.contains('/development/') &&
              renderer.hasMatch(file.readAsStringSync()))
            file.path,
      ];
      expect(importers, ['lib/src/features/reader/reader_screen.dart']);
    });

    test('and the reader reaches it only outside a release build', () {
      // `kReleaseMode` is a constant, so a release build compiles the branch
      // away and the renderer with it: nothing that ships can route to it,
      // whatever platform it lands on.
      final reader = File('lib/src/features/reader/reader_screen.dart')
          .readAsStringSync();
      final guard = RegExp(
        r'if\s*\(\s*kReleaseMode\s*\)\s*return\s+const\s+'
        r'BookPageUnavailable\(\)\s*;',
      ).firstMatch(reader)?.start;
      final uses = RegExp(r'DevelopmentBookPage\(').allMatches(reader);
      expect(guard, isNotNull, reason: 'the reader guards the renderer');
      expect(uses, hasLength(1), reason: 'and reaches it in one place');
      expect(uses.single.start, greaterThan(guard!));
    });
  });

  group('the development renderer (not shipped): a place in a page', () {
    testWidgets('a book opens again where in the page it was left', (
      tester,
    ) async {
      await pumpBook(
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
      final server = BookAdapter(
        requested: <int>[],
        posted: <BookPost>[],
        html: _longPage,
      );
      await pumpBook(tester, server: server);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final left = _pagePosition(tester).pixels;
      expect(left, greaterThan(0), reason: 'the reader did scroll the page');

      await pumpBook(tester, server: server);

      final reopened = _pagePosition(tester);
      expect(reopened.pixels, closeTo(left, 1));
    });

    testWidgets('a page the reader comes back to is where they left it', (
      tester,
    ) async {
      await pumpBook(tester, html: _longPage);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final left = _pagePosition(tester).pixels;

      await swipeBookPage(tester);
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
      final (_, posted) = await pumpBook(tester, html: _longPage);

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
        double.parse(postedAnchors(posted).last!),
        closeTo(position.pixels / position.maxScrollExtent, .01),
      );
    });

    testWidgets('a book with nothing recorded opens at the top of its page', (
      tester,
    ) async {
      await pumpBook(tester, progressPage: 4, html: _longPage);

      expect(_pagePosition(tester).pixels, 0);
    });

    testWidgets('a marker another reader wrote is not a place', (tester) async {
      // Kavita's own web client fills `bookScrollId` with the id of an element
      // in the page, and there is no element in a page this app draws: a book
      // whose place was last saved there opens at the top of its page rather
      // than nowhere at all.
      await pumpBook(
        tester,
        progressPage: 4,
        bookScrollId: 'body-h2-17',
        html: _longPage,
      );

      expect(_pagePosition(tester).pixels, 0);
    });

    testWidgets('a book set at another size keeps the place in the page', (
      tester,
    ) async {
      await pumpBook(tester, html: _longPage);
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

      await showBookChrome(tester);
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

    testWidgets('a picture the page refers to is drawn', (tester) async {
      await pumpBook(tester);

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
      await pumpBook(tester, html: addressedPicture);

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
      final (requested, _) = await pumpBook(
        tester,
        saved: (root) => saveChapterFixture(
          root,
          bookProfileId,
          chapterId: 7,
          title: 'Dune Messiah',
          pages: 3,
          format: MangaFormat.epub,
          pageHtml:
              '<p>The spice must flow.</p>'
              '<p><img src="data:;base64,$carriedPng"/></p>',
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

    // A copy is a directory (#129): the page as the server wrote it, beside
    // the pictures it names. With no server, a picture is the file beside it.
    testWidgets(
      'a saved book draws its pictures from the copy, with no server',
      (tester) async {
        await pumpBook(
          tester,
          offline: true,
          saved: (root) => saveThroughDownloader(
            tester,
            root,
            BookAdapter(requested: [], posted: []),
          ),
        );

        expect(find.textContaining('The spice must flow'), findsOneWidget);
        final pictures = tester.widgetList<Image>(find.byType(Image));
        expect(pictures, hasLength(1));
        final picture = pictures.single.image;
        expect(picture, isA<FileImage>());
        expect(
          (picture as FileImage).file.readAsBytesSync(),
          base64Decode(carriedPng),
        );
      },
    );
  });

  group(
    'the development renderer (not shipped): where a page sits in the screen',
    () {
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
                child: DevelopmentBookPage(
                  textSize: defaultBookTextSize,
                  lineHeight: defaultBookLineHeight,
                  face: (
                    family: fontAtkinsonHyperlegibleNext,
                    canSetItalic: false,
                  ),
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

        final page = tester.getRect(find.byType(DevelopmentBookPage));
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
        final page = tester.getRect(find.byType(DevelopmentBookPage));
        final content = tester.getRect(find.byType(Column));
        expect(content.top - page.top, closeTo(gutter, 1));
      });
    },
  );

  group('the development renderer (not shipped): how a page is set', () {
    Future<void> pumpWords(
      WidgetTester tester,
      String html, {
      BookType face = (
        family: fontAtkinsonHyperlegibleNext,
        canSetItalic: false,
      ),
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
              child: DevelopmentBookPage(
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
        // Not one line of it justified — in this renderer. The premise it
        // was written on changed rather than its reasoning: the web engine,
        // which draws the hyphen at a break, justifies and hyphenates where
        // the book is silent and its language known (#130, pinned in
        // `book_rewrite_test.dart`). Flutter still does not: measured, U+00AD
        // is honoured as a break opportunity but the hyphen is not drawn at
        // the break, so a narrow column has nothing to justify with and opens
        // gaps instead — which reads as a rendering fault rather than as
        // typography. The measurement is written down in the reader's rules,
        // so this is not put back here.
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
      final (requested, _) = await pumpBook(tester, html: _everyBlock);
      await showBookChrome(tester);
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
          of: find.byType(DevelopmentBookPage),
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
        tester.widget<Text>(find.text('1 / $bookPages')).style?.fontFamily,
        fontLiterata,
      );

      // Nothing was asked of the server: a page set in another face is the
      // page the reader is already holding, laid out again.
      expect(askedPages(requested), [0, 1]);
    });

    testWidgets('a page set in another face keeps the place in it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpBook(tester, html: _longPage);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final scrolled = _pagePosition(tester);
      final read = scrolled.pixels / scrolled.maxScrollExtent;
      expect(read, greaterThan(0), reason: 'the reader did scroll the page');

      await showBookChrome(tester);
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
        await pumpWords(tester, '<p>The worm <i>follows</i>.</p>', face: face);
        return [
          for (final run in _runs(
            tester,
            find.descendant(
              of: find.byType(DevelopmentBookPage),
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

  group(
    'the development renderer (not shipped): the direction a book declares',
    () {
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
          find
              .descendant(of: rule.first, matching: find.byType(RichText))
              .first,
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
              of: find.byType(DevelopmentBookPage),
              matching: find.byType(RichText),
            ),
          )
          .first
          .textDirection;

      /// The direction the page itself is laid out in, which is what the pager
      /// turns on.
      TextDirection laidOut(WidgetTester tester) => Directionality.of(
        tester.element(find.byType(DevelopmentBookPage).first),
      );

      testWidgets('a book that declares itself is laid out that way', (
        tester,
      ) async {
        await pumpBook(tester, html: page('.book-content { direction: rtl; }'));

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

      testWidgets('a book that declares nothing is laid out as it always was', (
        tester,
      ) async {
        await pumpBook(tester, html: page('.book-content { font-size: 1em; }'));

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
    },
  );

  group('the development renderer (not shipped): a heavy page', () {
    /// Lets the files a page is written into land: real I/O, which a test's
    /// clock does not move.
    Future<void> settle(WidgetTester tester) async {
      // Each step of a write is a round trip the clock does not move, and a
      // page is several: its pictures, the app's face, the document.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // A copy saved before a copy was a directory carries its pictures inside
    // its pages, and pages of several megabytes were measured on a device:
    // taken apart on the thread the app draws on, three of them were an ANR.
    // Past a size, a page is taken apart and rewritten in an isolate — and
    // still opens here too, which is what keeps a heavy book lookable-at
    // on the development machine.
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

    testWidgets('a heavy saved page still opens, drawn by the app', (
      tester,
    ) async {
      await pumpBook(tester, offline: true, saved: saveHeavy);
      await settle(tester);
      expect(find.text('The spice must flow.'), findsOneWidget);
    });
  });
}
