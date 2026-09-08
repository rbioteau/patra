import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
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

  // The one predicate both heroes ask, so the page one draws behind itself and
  // the cover it draws in front cannot name different chapters.
  group('the chapter a hero is inside', () {
    test('is the resumed chapter once it has been opened', () {
      final point = resumePoint([
        _volume(1, 1, [_chapter(10, number: 1, pages: 20, read: 8)]),
      ]);
      expect(entryUnderWay(point)!.chapter.id, 10);
    });

    // The series is under way — a whole volume is finished — but the chapter
    // the button lands on is untouched, and there is no page you are on.
    test('is none where the next chapter has not been opened', () {
      final point = resumePoint([
        _volume(1, 1, [_chapter(10, number: 1, pages: 20, read: 20)]),
        _volume(2, 2, [_chapter(11, number: 2, pages: 20, read: 0)]),
      ]);
      expect(point!.entry.chapter.id, 11);
      expect(point.started, isTrue);
      expect(entryUnderWay(point), isNull);
    });

    // Everything is read, so the button offers the series again from a
    // chapter that happens to be full — which is not a chapter under way.
    test('is none once the whole series is read', () {
      final point = resumePoint([
        _volume(1, 1, [_chapter(10, number: 1, pages: 20, read: 20)]),
      ]);
      expect(point!.allRead, isTrue);
      expect(entryUnderWay(point), isNull);
    });

    test('is none while the volumes are still in flight', () {
      expect(entryUnderWay(null), isNull);
    });
  });

  group('the cover that pictures a resume entry', () {
    final client = KavitaClient(
      baseUrl: 'http://kavita.test',
      token: 'token',
      username: 'romain',
      apiKey: 'key',
    );

    test('is the chapter cover for an ordinary chapter', () {
      final volume = _volume(1, 1, [_chapter(10, number: 3)]);
      final url = entryCoverUrl(client, (
        volume: volume,
        chapter: volume.chapters.single,
      ));
      expect(url, contains('/api/Image/chapter-cover'));
      expect(url, contains('chapterId=10'));
    });

    // A volume with no chapter breakdown is the reading unit, and the row it
    // opens is drawn by the volume's cover — one image, not two.
    test('is the volume cover for a volume with no chapter breakdown', () {
      final volume = _volume(7, 1, [_chapter(10, number: -100000)]);
      final url = entryCoverUrl(client, (
        volume: volume,
        chapter: volume.chapters.single,
      ));
      expect(url, contains('/api/Image/volume-cover'));
      expect(url, contains('volumeId=7'));
    });

    // The pseudo-volumes are Kavita bookkeeping, not a reading unit: a
    // sentinel-numbered chapter filed under one is still its own chapter.
    test('is the chapter cover inside a pseudo-volume', () {
      final loose = _looseLeaf([_chapter(10, number: -100000)]);
      expect(
        entryCoverUrl(client, (volume: loose, chapter: loose.chapters.single)),
        contains('/api/Image/chapter-cover'),
      );
      final specials = _specials([_chapter(11, number: -100000)]);
      expect(
        entryCoverUrl(client, (
          volume: specials,
          chapter: specials.chapters.single,
        )),
        contains('/api/Image/chapter-cover'),
      );
    });
  });
}
