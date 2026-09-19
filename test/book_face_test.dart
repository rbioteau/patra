import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/book_face.dart';

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
}