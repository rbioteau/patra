import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/features/reader/spread_layout.dart';

/// A chapter of [pages] pages, with the ones listed in [wide] scanned as
/// double pages. Kavita numbers `pageDimensions` from the file, which may be
/// 0- or 1-based; these are 0-based, as `ChapterInfo` reads them first.
ChapterInfo _chapter(int pages, {Set<int> wide = const {}}) => ChapterInfo(
  seriesId: 1,
  volumeId: 1,
  libraryId: 1,
  pages: pages,
  seriesName: 'Berserk',
  title: 'Chapter 1',
  pageDimensions: {
    for (var page = 0; page < pages; page++)
      page: PageDimension(
        pageNumber: page,
        width: wide.contains(page) ? 1600 : 800,
        height: 1200,
        isWide: wide.contains(page),
      ),
  },
);

void main() {
  test('with nothing wide, pages pair up two by two', () {
    final spread = SpreadLayout.of(_chapter(6));

    expect(spread.slots, [
      [0, 1],
      [2, 3],
      [4, 5],
    ]);
    expect(spread.spanOf(3), 2);
    expect(spread.indexOf(3), 1);
    expect(spread.firstOf(1), 2);
  });

  test('a double-page scan takes a screen of its own', () {
    // And it shifts the parity of everything after it: 3 and 4 pair up where
    // a fixed `page ~/ 2` would have put 2 with 3 and split the spread.
    final spread = SpreadLayout.of(_chapter(6, wide: {2}));

    expect(spread.slots, [
      [0, 1],
      [2],
      [3, 4],
      [5],
    ]);
    expect(spread.spanOf(2), 1, reason: 'the wide page is read alone');
    expect(spread.spanOf(3), 2);
    expect(spread.indexOf(4), 2);
  });

  test('a page beside a wide one is read alone too', () {
    final spread = SpreadLayout.of(_chapter(4, wide: {1}));

    expect(spread.slots, [
      [0],
      [1],
      [2, 3],
    ]);
  });

  test('landscape dimensions are a spread even without the flag', () {
    // Kavita only sets `isWide` for the files it has measured that way, but a
    // page plainly wider than it is tall is a double page whatever it says.
    final chapter = ChapterInfo(
      seriesId: 1,
      volumeId: 1,
      libraryId: 1,
      pages: 3,
      seriesName: 'Berserk',
      title: 'Chapter 1',
      pageDimensions: const {
        0: PageDimension(pageNumber: 0, width: 800, height: 1200, isWide: false),
        1: PageDimension(
          pageNumber: 1,
          width: 1600,
          height: 1200,
          isWide: false,
        ),
        2: PageDimension(pageNumber: 2, width: 800, height: 1200, isWide: false),
      },
    );

    expect(SpreadLayout.of(chapter).slots, [
      [0],
      [1],
      [2],
    ]);
  });

  test('a chapter the server never measured pairs up as it always did', () {
    final spread = SpreadLayout.of(_chapter(5).copyWithoutDimensions());

    expect(spread.slots, [
      [0, 1],
      [2, 3],
      [4],
    ]);
  });

  test('an empty chapter answers without reaching past its pages', () {
    final spread = SpreadLayout.of(_chapter(0));

    expect(spread.length, 0);
    expect(spread.spanOf(0), 1);
    expect(spread.firstOf(0), 0);
    expect(spread.indexOf(9), 0);
  });
}

extension on ChapterInfo {
  /// The same chapter as an older server would describe it: no dimensions.
  ChapterInfo copyWithoutDimensions() => ChapterInfo(
    seriesId: seriesId,
    volumeId: volumeId,
    libraryId: libraryId,
    pages: pages,
    seriesName: seriesName,
    title: title,
  );
}
