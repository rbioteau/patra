import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/features/reader/book_layout.dart';

/// What the book reader decides without drawing anything: how a text size
/// steps, which line spacing a height is, and which chapter a page is in.
void main() {
  group('the text size', () {
    test('steps a point at a time, inside 12 to 28', () {
      expect(steppedTextSize(16, 1), 17);
      expect(steppedTextSize(16, -1), 15);
      expect(steppedTextSize(28, 1), 28);
      expect(steppedTextSize(12, -1), 12);
    });

    test('steps two at a time where it is asked to', () {
      expect(steppedTextSize(18, 1, step: 2), 20);
      expect(steppedTextSize(27, 1, step: 2), 28);
    });

    test('a size set off the step lands back on a whole point', () {
      expect(steppedTextSize(16.4, 1), 17);
    });
  });

  group('the line spacing', () {
    test('three of them, tight to loose', () {
      expect(BookSpacing.values.map((s) => s.height), [1.35, 1.55, 1.8]);
    });

    test('a height is the spacing it was set at, and none other', () {
      expect(BookSpacing.of(1.55), BookSpacing.normal);
      expect(BookSpacing.of(1.8), BookSpacing.loose);
      // A height chosen on the slider this replaced names no segment
      // rather than the nearest one: the row does not lie about it.
      expect(BookSpacing.of(1.6), isNull);
    });
  });

  group('the chapter a page is in', () {
    const contents = [
      BookContentsEntry(
        title: 'Part One',
        page: 2,
        children: [
          BookContentsEntry(title: 'Chapter 1', page: 3),
          BookContentsEntry(title: 'Chapter 2', page: 8),
        ],
      ),
      BookContentsEntry(title: 'Part Two', page: 12),
    ];

    test('is the deepest entry that has begun', () {
      expect(chapterAt(contents, 5), 'Chapter 1');
      expect(chapterAt(contents, 8), 'Chapter 2');
      expect(chapterAt(contents, 11), 'Chapter 2');
      expect(chapterAt(contents, 12), 'Part Two');
    });

    test('a part is named on the page it begins on, before its chapters', () {
      expect(chapterAt(contents, 2), 'Part One');
    });

    test('before the first entry, and with no contents, there is none', () {
      expect(chapterAt(contents, 0), isNull);
      expect(chapterAt(const [], 4), isNull);
    });
  });
}
