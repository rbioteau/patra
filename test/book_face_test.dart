import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/book_face.dart';
import 'package:patra/src/settings/reading_settings.dart';

void main() {
  group('parseBookFace', () {
    test('reads a book with one @font-face and a usage rule', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "CustomBookFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/custom.woff2");
        }
        body { font-family: "CustomBookFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'CustomBookFont');
      expect(face.roman, isNotNull);
      expect(face.roman, contains('custom.woff2'));
      expect(face.italic, isNull);
    });

    test('reads a book with roman and italic', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "CustomFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/custom.woff2");
        }
        @font-face {
          font-family: "CustomFont";
          font-style: italic;
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/custom-italic.woff2");
        }
        body { font-family: "CustomFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'CustomFont');
      expect(face.roman, isNotNull);
      expect(face.italic, isNotNull);
    });

    test('a book shipping only one family and never naming it is read as asking for it', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "OnlyFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/only.woff2");
        }
        /* no usage rule */
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'OnlyFont');
    });

    test('a book shipping several families and naming none gets none', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "FontOne";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/one.woff2");
        }
        @font-face {
          font-family: "FontTwo";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/two.woff2");
        }
        /* no usage rule */
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNull);
    });

    test('the roman is preferred over a font-weight: 700 declaration', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "TestFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/test.woff2");
        }
        @font-face {
          font-family: "TestFont";
          font-weight: 700;
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/test-bold.woff2");
        }
        body { font-family: "TestFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'TestFont');
      // The roman (font-weight: 400) should be preferred over the 700 weight
      expect(face.roman, isNotNull);
      expect(face.roman, contains('test.woff2'));
    });

    test('the italic is picked up from font-style: italic', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "ItalicFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/italic.woff2");
        }
        @font-face {
          font-family: "ItalicFont";
          font-style: italic;
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/italic-italic.woff2");
        }
        body { font-family: "ItalicFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'ItalicFont');
      expect(face.roman, isNotNull);
      expect(face.italic, isNotNull);
      expect(face.italic, contains('italic-italic.woff2'));
    });

    test('a page with no <style> returns null', () {
      const html = '<html><body><p>Hello</p></body></html>';

      final face = parseBookFace(html);

      expect(face, isNull);
    });

    test('a page with empty <style> returns null', () {
      const html = '<html><head><style></style></head><body><p>Hello</p></body></html>';

      final face = parseBookFace(html);

      expect(face, isNull);
    });

    test('a page with style but no @font-face returns null', () {
      const html = '<html><head><style>body { color: red; }</style></head><body><p>Hello</p></body></html>';

      final face = parseBookFace(html);

      expect(face, isNull);
    });

    test('a page with @font-face but no src returns null', () {
      const html = '''
        <html><head><style>
        @font-face { font-family: "NoSrc"; }
        body { font-family: "NoSrc"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNull);
    });

    test('a page with @font-face with unreadable src returns null', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "BadFont";
          src: url("data:application/octet-stream,notafont");
        }
        body { font-family: "BadFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNull);
    });

    test('usage rule on body is preferred over html', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "BodyFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/body.woff2");
        }
        @font-face {
          font-family: "HtmlFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/html.woff2");
        }
        body { font-family: "BodyFont"; }
        html { font-family: "HtmlFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'BodyFont');
    });

    test('usage rule on :root is treated as page-level', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "RootFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/root.woff2");
        }
        :root { font-family: "RootFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'RootFont');
    });

    test('usage rule on .book-content is treated as page-level', () {
      const html = '''
        <html><head><style>
        @font-face {
          font-family: "ContentFont";
          src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/content.woff2");
        }
        .book-content { font-family: "ContentFont"; }
        </style></head><body><p>Hello</p></body></html>
      ''';

      final face = parseBookFace(html);

      expect(face, isNotNull);
      expect(face!.family, 'ContentFont');
    });
  });
  group('parseBookDirection', () {
    /// A page in the shape the server really hands one over: the wrapper
    /// Kavita puts a book's body in, carrying whatever classes it moved off
    /// the file's own `<html>`/`<body>`, with the book's CSS scoped into it.
    String page(String css, {String wrapper = 'book-content'}) =>
        '<div class="$wrapper"><style>$css</style><p>مرحبا</p></div>';

    test('a direction on the wrapper Kavita scoped the book into is read', () {
      // What `body{direction:rtl}` reaches us as: `ScopeStyles` replaces the
      // book's own `body` with the container it scopes a page to, so this is
      // the one selector that still picks out the page itself.
      expect(
        parseBookDirection(page('.book-content { direction: rtl; }')),
        ReadingDirection.rightToLeft,
      );
    });

    test('a direction on everything is read', () {
      expect(
        parseBookDirection(page('* { direction: rtl; }')),
        ReadingDirection.rightToLeft,
      );
    });

    test("a direction on the book's paragraphs is read", () {
      // `body p{direction:rtl}` scoped twice over. Every paragraph of the
      // page is the page's prose, which is what the reading is about.
      expect(
        parseBookDirection(page('.book-content .book-content p { direction: rtl; }')),
        ReadingDirection.rightToLeft,
      );
    });

    test('an inert rule on a class the wrapper carries is still a reading', () {
      // The case Kavita assembles the wrapper's class list *for*: a book that
      // wrote `body.rtl{direction:rtl}` and marked its own body `rtl`. The
      // scoping leaves the rule matching a wrapper inside a wrapper — nothing
      // at all — while the class it asked for is on the wrapper itself.
      expect(
        parseBookDirection(
          page('.book-content .book-content.rtl { direction: rtl; }', wrapper: 'book-content rtl'),
        ),
        ReadingDirection.rightToLeft,
      );
    });

    test('an inert rule on a class the wrapper does not carry is not a reading', () {
      // The same rule with nothing to corroborate it: a class used on one
      // element of an otherwise left-to-right book — a single quotation in
      // Arabic — must not turn the book.
      expect(
        parseBookDirection(page('.book-content .rtl { direction: rtl; }')),
        isNull,
      );
    });

    test('a declaration is not a match: an inert html[dir=rtl] rule says nothing', () {
      // `PrepareFinalHtml` keeps no `<html>` and no attribute but `src` and
      // `href`, so this rule applies to nothing — and reading "is
      // `direction:rtl` anywhere in the stylesheet" is exactly what would
      // over-trigger on it.
      expect(
        parseBookDirection(page('.book-content html[dir=rtl] { direction: rtl; }')),
        isNull,
      );
    });

    test('a direction on one run of words is not a direction for the book', () {
      expect(
        parseBookDirection(page('.book-content span { direction: rtl; }')),
        isNull,
      );
    });

    test('a stylesheet with no direction at all says nothing', () {
      expect(
        parseBookDirection(page('.book-content { font-family: "Amiri"; }')),
        isNull,
      );
    });

    test('a rule that only applies sometimes is not a declaration', () {
      // Nothing here can evaluate a media query — there is no browser — and
      // the medium `print` names is not the one anybody is reading on. What
      // makes this worth a test of its own is that the grammar matches the
      // **inner** rule as though it stood alone, so an at-rule that was not
      // dropped whole turns the book on the strength of its print
      // stylesheet.
      expect(
        parseBookDirection(
          page('@media print { .book-content { direction: rtl; } }'),
        ),
        isNull,
      );
      expect(
        parseBookDirection(
          page('@supports (direction: rtl) { .book-content { direction: rtl; } }'),
        ),
        isNull,
      );
    });

    test('a prefixed property is a different property', () {
      // A hyphen is a non-word character, so a `\b` before the name matches
      // inside `-epub-writing-direction` — and the prefixed properties are
      // exactly the ones an EPUB writes and this app does not honour.
      expect(
        parseBookDirection(
          page('.book-content { -epub-writing-direction: rtl; }'),
        ),
        isNull,
      );
    });

    test('a page with no stylesheet says nothing', () {
      expect(parseBookDirection('<div class="book-content"><p>Hello</p></div>'), isNull);
    });

    test('a declared left-to-right is not read, because it cannot be told from silence', () {
      // `direction: ltr` is the CSS default and is written as a reset far
      // more often than as a statement, so it says nothing a silent
      // stylesheet does not. `rtl` is never written by accident.
      expect(
        parseBookDirection(page('.book-content { direction: ltr; }')),
        isNull,
      );
    });

    test('the wrapper class list alone is not a reading', () {
      // Worth weighing, never trusted alone: what is being read is a
      // `direction` the book declared, and a class name is only what makes a
      // broken selector match the page again.
      expect(
        parseBookDirection(
          page('.book-content { font-family: "Amiri"; }', wrapper: 'book-content rtl'),
        ),
        isNull,
      );
    });

    test('the direction is read out of the same <style> the face is', () {
      // One walk over a page's stylesheets answers both questions, which is
      // why this lives beside `parseBookFace` rather than in the page parser.
      const html =
          '<div class="book-content"><style>'
          '@font-face { font-family: "Amiri"; '
          'src: url("//host/api/Book/7/book-resources?apiKey=key&file=OEBPS/fonts/amiri.ttf"); }'
          '.book-content { font-family: "Amiri"; direction: rtl; }'
          '</style><p>مرحبا</p></div>';

      expect(parseBookFace(html)?.family, 'Amiri');
      expect(parseBookDirection(html), ReadingDirection.rightToLeft);
    });
  });
}
