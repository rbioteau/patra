import 'package:flutter_test/flutter_test.dart';
import 'package:verso/src/api/models.dart';

void main() {
  group('Kavita sentinel numbers', () {
    test('a volume holding loose chapters is not a real volume', () {
      // Observed positive on a live 0.9 server and negative elsewhere: both
      // are bookkeeping, neither is a volume number.
      for (final sentinel in [100000, -100000]) {
        final volume = VolumeDto.fromJson({
          'id': 1,
          'name': '$sentinel',
          'minNumber': sentinel,
          'chapters': <dynamic>[],
        });
        expect(volume.isLooseLeaf, isTrue, reason: 'minNumber $sentinel');
        expect(volume.isSpecials, isFalse);
      }
    });

    test('specials sit in their own pseudo-volume', () {
      for (final sentinel in [100001, -100001]) {
        final volume = VolumeDto.fromJson({
          'id': 2,
          'name': '$sentinel',
          'minNumber': sentinel,
          'chapters': <dynamic>[],
        });
        expect(volume.isSpecials, isTrue, reason: 'minNumber $sentinel');
        expect(volume.isLooseLeaf, isFalse);
      }
    });

    test('a real volume is neither', () {
      final volume = VolumeDto.fromJson({
        'id': 3,
        'name': '1',
        'minNumber': 1,
        'chapters': <dynamic>[],
      });
      expect(volume.isLooseLeaf, isFalse);
      expect(volume.isSpecials, isFalse);
    });

    test('a chapterless volume exposes a placeholder chapter', () {
      for (final sentinel in [-100000, 100000]) {
        final chapter = ChapterDto.fromJson({
          'id': 10,
          'minNumber': sentinel,
          'pages': 180,
        });
        expect(chapter.isVolumePlaceholder, isTrue, reason: '$sentinel');
      }
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
