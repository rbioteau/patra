import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';

void main() {
  group('Kavita sentinel numbers', () {
    VolumeDto volume(num minNumber) => VolumeDto.fromJson({
      'id': 1,
      'name': '$minNumber',
      'minNumber': minNumber,
      'chapters': <dynamic>[],
    });

    // ParserConstants: LooseLeafVolumeNumber = -100000, SpecialVolumeNumber =
    // +100000. Same magnitude, opposite signs — the sign is the whole
    // distinction, so neither may be compared on its absolute value.
    test('a volume holding loose chapters is not a real volume', () {
      expect(volume(-100000).isLooseLeaf, isTrue);
      expect(volume(-100000).isSpecials, isFalse);
    });

    test('specials sit in their own pseudo-volume', () {
      expect(volume(100000).isSpecials, isTrue);
      expect(volume(100000).isLooseLeaf, isFalse);
    });

    test('a real volume is neither', () {
      expect(volume(1).isLooseLeaf, isFalse);
      expect(volume(1).isSpecials, isFalse);
    });

    test('a chapterless volume exposes a placeholder chapter', () {
      final chapter = ChapterDto.fromJson({
        'id': 10,
        'minNumber': -100000,
        'pages': 180,
      });
      expect(chapter.isVolumePlaceholder, isTrue);
    });

    test('the specials volume number is not a chapter placeholder', () {
      final chapter = ChapterDto.fromJson({
        'id': 10,
        'minNumber': 100000,
        'pages': 180,
      });
      expect(chapter.isVolumePlaceholder, isFalse);
    });

    test('a special is never treated as a volume placeholder', () {
      final chapter = ChapterDto.fromJson({
        'id': 11,
        'minNumber': -100000,
        'isSpecial': true,
        'pages': 20,
      });
      expect(chapter.isVolumePlaceholder, isFalse);
    });
  });

  group('enums off the wire', () {
    test('library types map to their Kavita ids', () {
      expect(LibraryType.fromId(0), LibraryType.manga);
      expect(LibraryType.fromId(1), LibraryType.comic);
      expect(LibraryType.fromId(2), LibraryType.book);
      expect(LibraryType.fromId(3), LibraryType.image);
      expect(LibraryType.fromId(4), LibraryType.lightNovel);
      expect(LibraryType.fromId(5), LibraryType.comicVine);
      // A type from a newer server must not crash a screen.
      expect(LibraryType.fromId(99), LibraryType.manga);
      expect(LibraryType.fromId(null), LibraryType.manga);
    });

    test('only comics count issues, only book libraries count books', () {
      expect(LibraryType.comic.usesIssues, isTrue);
      expect(LibraryType.comicVine.usesIssues, isTrue);
      expect(LibraryType.manga.usesIssues, isFalse);
      expect(LibraryType.book.usesBooks, isTrue);
      expect(LibraryType.lightNovel.usesBooks, isTrue);
      expect(LibraryType.image.usesBooks, isFalse);
    });

    test('a storyline exists only where Kavita shows one', () {
      expect(LibraryType.manga.hasStoryline, isTrue);
      expect(LibraryType.image.hasStoryline, isTrue);
      for (final type in [
        LibraryType.comic,
        LibraryType.comicVine,
        LibraryType.book,
        LibraryType.lightNovel,
      ]) {
        expect(type.hasStoryline, isFalse, reason: type.name);
      }
    });

    test('the page reader handles everything the server can rasterise', () {
      expect(MangaFormat.fromId(0), MangaFormat.image);
      expect(MangaFormat.fromId(1).isImageReadable, isTrue);
      expect(MangaFormat.fromId(3), MangaFormat.epub);
      // A PDF is served as page images once Kavita is asked to extract it.
      expect(MangaFormat.pdf.isImageReadable, isTrue);
      // An EPUB is reflowable text: the server has no image path for it.
      expect(MangaFormat.epub.isImageReadable, isFalse);
      // Unknown is Kavita's own fallback: worth attempting.
      expect(MangaFormat.fromId(null).isImageReadable, isTrue);
    });

    test('a chapter carries its sort order and format', () {
      final chapter = ChapterDto.fromJson({
        'id': 1,
        'minNumber': 3,
        'sortOrder': 3.5,
        'format': 3,
      });
      expect(chapter.sortOrder, 3.5);
      expect(chapter.format, MangaFormat.epub);
    });
  });

  group('page dimensions', () {
    test('drive the webtoon layout when the server reports them', () {
      final info = ChapterInfoDto.fromJson({
        'seriesId': 1,
        'pages': 2,
        'pageDimensions': [
          {'pageNumber': 0, 'width': 800, 'height': 1200, 'isWide': false},
          {'pageNumber': 1, 'width': 1600, 'height': 1200, 'isWide': true},
        ],
      });
      expect(info.aspectRatioFor(0), closeTo(2 / 3, 0.0001));
      expect(info.aspectRatioFor(1), closeTo(4 / 3, 0.0001));
      expect(info.isWide(1), isTrue);
    });

    test('tolerate one-based page numbering', () {
      final info = ChapterInfoDto.fromJson({
        'seriesId': 1,
        'pages': 1,
        'pageDimensions': [
          {'pageNumber': 1, 'width': 1000, 'height': 1000},
        ],
      });
      expect(info.aspectRatioFor(0), 1.0);
    });

    test('fall back to a portrait page when absent', () {
      final info = ChapterInfoDto.fromJson({'seriesId': 1, 'pages': 3});
      expect(info.aspectRatioFor(0), PageDimension.defaultAspectRatio);
      expect(info.isWide(0), isFalse);
    });

    test('survive a malformed entry', () {
      final info = ChapterInfoDto.fromJson({
        'seriesId': 1,
        'pages': 1,
        'pageDimensions': [
          {'width': 10},
          null,
          {'pageNumber': 0, 'width': 0, 'height': 0},
        ],
      });
      expect(info.aspectRatioFor(0), PageDimension.defaultAspectRatio);
    });
  });
}
