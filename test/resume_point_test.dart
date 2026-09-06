import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/resume_point.dart';

Chapter _chapter(
  int id, {
  num number = 1,
  int pages = 20,
  int read = 0,
  bool special = false,
  num? sortOrder,
}) => Chapter.fromJson({
  'id': id,
  'range': '$number',
  'minNumber': number,
  'pages': pages,
  'pagesRead': read,
  'isSpecial': special,
  'sortOrder': sortOrder ?? number,
});

Volume _volume(int id, num number, List<Chapter> chapters) => Volume.fromJson({
  'id': id,
  'name': '$number',
  'minNumber': number,
  'chapters': [
    for (final c in chapters)
      {
        'id': c.id,
        'range': c.range,
        'minNumber': c.minNumber,
        'pages': c.pages,
        'pagesRead': c.pagesRead,
        'isSpecial': c.isSpecial,
        'sortOrder': c.sortOrder,
      },
  ],
});

Volume _looseLeaf(List<Chapter> chapters) => _volume(90, -100000, chapters);
Volume _specials(List<Chapter> chapters) => _volume(91, 100000, chapters);

void main() {
  group('the chapter reading resumes at', () {
    test('a series with no volumes has none', () {
      expect(resumePoint(const []), isNull);
      expect(resumePoint([_volume(1, 1, const [])]), isNull);
    });

    test('an untouched series resumes at its first chapter, unstarted', () {
      final point = resumePoint([
        _volume(1, 1, [_chapter(10, number: 1), _chapter(11, number: 2)]),
      ]);
      expect(point!.entry.chapter.id, 10);
      expect(point.started, isFalse);
      expect(point.allRead, isFalse);
    });

    test('it is the first chapter not finished', () {
      final point = resumePoint([
        _volume(1, 1, [
          _chapter(10, number: 1, pages: 20, read: 20),
          _chapter(11, number: 2, pages: 20, read: 7),
          _chapter(12, number: 3),
        ]),
      ]);
      expect(point!.entry.chapter.id, 11);
    });

    // Reading progress is a fact about the series, not about the chapter the
    // button lands on: finishing a volume leaves the next one untouched, and
    // someone halfway through a series must not be told to start it.
    test('a finished chapter still means the series is started', () {
      final point = resumePoint([
        _volume(1, 1, [_chapter(10, number: 1, pages: 20, read: 20)]),
        _volume(2, 2, [_chapter(11, number: 1)]),
      ]);
      expect(point!.entry.chapter.id, 11);
      expect(point.started, isTrue);
    });

    test('a fully read series resumes at the beginning and says so', () {
      final point = resumePoint([
        _volume(1, 1, [
          _chapter(10, number: 1, pages: 20, read: 20),
          _chapter(11, number: 2, pages: 20, read: 20),
        ]),
      ]);
      expect(point!.entry.chapter.id, 10);
      expect(point.allRead, isTrue);
      expect(point.started, isTrue);
    });

    // Volumes, then loose chapters, then specials — the order the series
    // screen renders its sections in.
    test('loose chapters come after the volumes, specials after those', () {
      final entries = orderedChapters([
        _specials([_chapter(30, number: 1, special: true)]),
        _looseLeaf([_chapter(20, number: 5)]),
        _volume(1, 1, [_chapter(10, number: 1)]),
      ]);
      expect(entries.map((e) => e.chapter.id), [10, 20, 30]);
    });

    // Kavita sorts every list it builds on sortOrder, and it is not the order
    // the array arrives in.
    test('chapters follow sortOrder, not the order they arrived in', () {
      final entries = orderedChapters([
        _volume(1, 1, [
          _chapter(11, number: 2, sortOrder: 2),
          _chapter(10, number: 1, sortOrder: 1),
        ]),
      ]);
      expect(entries.map((e) => e.chapter.id), [10, 11]);
    });

    test(
      'a special sitting in a numbered volume is filed with the specials',
      () {
        final entries = orderedChapters([
          _volume(1, 1, [
            _chapter(10, number: 1),
            _chapter(11, number: 2, special: true),
          ]),
          _looseLeaf([_chapter(20, number: 5)]),
        ]);
        expect(entries.map((e) => e.chapter.id), [10, 20, 11]);
      },
    );
  });
}
