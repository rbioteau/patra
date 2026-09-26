import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/book_document.dart';
import 'package:patra/src/settings/reading_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('book_document'));
  tearDown(() => root.deleteSync(recursive: true));

  group("a page's files", () {
    test('are fetched once each and written beside the page', () async {
      final asked = <String>[];
      final files = await fetchBookPageFiles(
        const [
          'OEBPS/images/worm.jpg',
          'OEBPS/images/worm.jpg',
          'OEBPS/fonts/face.otf',
        ],
        into: Directory('${root.path}/7'),
        fetch: (src) async {
          asked.add(src);
          return src.codeUnits;
        },
      );
      expect(asked, ['OEBPS/images/worm.jpg', 'OEBPS/fonts/face.otf']);
      expect(files.keys, {'OEBPS/images/worm.jpg', 'OEBPS/fonts/face.otf'});
      for (final MapEntry(:key, :value) in files.entries) {
        final file = File.fromUri(Uri.parse(value));
        expect(value, startsWith('file:///'));
        expect(file.parent.path, '${root.path}/7');
        expect(file.readAsStringSync(), key);
      }
      // The extension goes with it: an engine reading a file names its type
      // by it.
      expect(files['OEBPS/images/worm.jpg'], endsWith('.jpg'));
    });

    test("keep the extension of a whole address's file", () async {
      const src =
          '//kavita.example/api/book/7/book-resources?apiKey=k&file=cover.png';
      final files = await fetchBookPageFiles(
        const [src],
        into: root,
        fetch: (_) async => const [1],
      );
      expect(files[src], endsWith('.png'));
      expect(files[src], isNot(contains('apiKey')));
    });

    test('are not fetched where the page carries them itself', () async {
      final asked = <String>[];
      final files = await fetchBookPageFiles(
        const ['data:image/png;base64,AAAA', ''],
        into: root,
        fetch: (src) async {
          asked.add(src);
          return const [1];
        },
      );
      expect(asked, isEmpty);
      expect(files, isEmpty);
    });

    test('that cannot be had are not there, and the rest are', () async {
      final files = await fetchBookPageFiles(
        const ['a.jpg', 'b.jpg'],
        into: root,
        fetch: (src) async =>
            src == 'a.jpg' ? throw const SocketException('down') : [1],
      );
      expect(files.keys, ['b.jpg']);
    });

    test('already on the device are copied rather than fetched', () async {
      final copy = File('${root.path}/book-font')..writeAsStringSync('face');
      final asked = <String>[];
      final files = await fetchBookPageFiles(
        const ['//dead.example/book-resources?file=face.otf'],
        into: Directory('${root.path}/7'),
        onDevice: {'//dead.example/book-resources?file=face.otf': copy},
        fetch: (src) async {
          asked.add(src);
          return const [1];
        },
      );
      expect(asked, isEmpty);
      final written = File.fromUri(Uri.parse(files.values.single));
      expect(written.parent.path, '${root.path}/7');
      expect(written.readAsStringSync(), 'face');
    });

    test('already copied out of a copy are not copied again', () async {
      // A saved book is opened again and again, and a picture of megabytes
      // copied on every page turn is a wait the reader pays each time.
      const src = 'OEBPS/images/worm.jpg';
      final copy = File('${root.path}/worm')..writeAsStringSync('worm');
      final into = Directory('${root.path}/7');
      final first = await fetchBookPageFiles(
        const [src],
        into: into,
        onDevice: {src: copy},
        fetch: (_) async => const [],
      );
      final written = File.fromUri(Uri.parse(first[src]!));
      final copiedAt = written.lastModifiedSync();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final again = await fetchBookPageFiles(
        const [src],
        into: into,
        onDevice: {src: copy},
        fetch: (_) async => const [],
      );

      expect(again[src], first[src]);
      expect(written.lastModifiedSync(), copiedAt);
      expect(written.readAsStringSync(), 'worm');
    });
  });

  group('the document a page is loaded from', () {
    test('points its pictures at the files beside it', () async {
      final file = await writeBookDocument(
        File('${root.path}/7-0.html'),
        '<p>Il était</p><img src="OEBPS/images/worm.jpg">'
        '<img src="OEBPS/images/lost.jpg">',
        language: 'fr',
        setting: (textSize: 18, lineHeight: 1.6, face: ReadingFace.book),
        files: const {'OEBPS/images/worm.jpg': 'file:///cache/7/0.jpg'},
      );
      final document = file.readAsStringSync();
      expect(document, contains('<html lang="fr">'));
      expect(document, contains('src="file:///cache/7/0.jpg"'));
      expect(document, isNot(contains('lost.jpg')));
      expect(document, contains('Il était'));
    });
  });

  group("the app's faces", () {
    test("are written out of the app's own bundle, once", () async {
      final fonts = Directory('${root.path}/fonts');
      final serif = (await appFaceFiles(ReadingFace.serif, into: fonts))!;
      final roman = File.fromUri(Uri.parse(serif.roman));
      final italic = File.fromUri(Uri.parse(serif.italic));
      expect(roman.path, contains('Literata'));
      expect(italic.path, contains('Literata-Italic'));
      expect(roman.lengthSync(), greaterThan(0));
      expect(italic.lengthSync(), greaterThan(0));

      final written = roman.lastModifiedSync();
      await appFaceFiles(ReadingFace.serif, into: fonts);
      expect(roman.lastModifiedSync(), written);

      final sans = (await appFaceFiles(ReadingFace.sans, into: fonts))!;
      expect(sans.roman, contains('AtkinsonHyperlegibleNext'));
    });

    test("are none where the book's own face was chosen", () async {
      expect(await appFaceFiles(ReadingFace.book, into: root), isNull);
    });
  });
}
