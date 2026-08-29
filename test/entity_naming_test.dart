import 'package:flutter_test/flutter_test.dart';
import 'package:verso/l10n/generated/app_localizations_en.dart';
import 'package:verso/l10n/generated/app_localizations_fr.dart';
import 'package:verso/src/api/models.dart';
import 'package:verso/src/entity_naming.dart';

void main() {
  final en = AppLocalizationsEn();
  final fr = AppLocalizationsFr();

  ChapterDto chapter({
    String range = '12',
    String title = '',
    String titleName = '',
    bool isSpecial = false,
  }) => ChapterDto.fromJson({
    'id': 1,
    'range': range,
    'title': title,
    'titleName': titleName,
    'isSpecial': isSpecial,
    'minNumber': 12,
  });

  group('the library type names the units', () {
    test('a manga has volumes and chapters', () {
      expect(LibraryType.manga.volumesTitle(en), 'Volumes');
      expect(LibraryType.manga.chaptersTitle(en), 'Chapters');
      expect(LibraryType.manga.numberedChapterLabel(en, '12'), 'Chapter 12');
      expect(LibraryType.manga.volumeLabel(en, '3'), 'Volume 3');
    });

    test('a comic has issues, both kinds of comic library', () {
      for (final type in [LibraryType.comic, LibraryType.comicVine]) {
        expect(type.chaptersTitle(en), 'Issues', reason: type.name);
        expect(type.numberedChapterLabel(en, '12'), 'Issue #12');
        // An issue run still comes in volumes.
        expect(type.volumesTitle(en), 'Volumes');
      }
    });

    test('a book library counts books, at both levels', () {
      for (final type in [LibraryType.book, LibraryType.lightNovel]) {
        expect(type.volumesTitle(en), 'Books', reason: type.name);
        expect(type.chaptersTitle(en), 'Books');
        expect(type.volumeLabel(en, '2'), 'Book 2');
      }
    });
  });

  group('the French glossary is fixed', () {
    test('volume is tome, chapter is chapitre', () {
      expect(LibraryType.manga.volumesTitle(fr), 'Tomes');
      expect(LibraryType.manga.volumeLabel(fr, '3'), 'Tome 3');
      expect(LibraryType.manga.chaptersTitle(fr), 'Chapitres');
      expect(LibraryType.manga.numberedChapterLabel(fr, '12'), 'Chapitre 12');
    });

    test('issue is numéro', () {
      expect(LibraryType.comic.chaptersTitle(fr), 'Numéros');
      expect(LibraryType.comic.numberedChapterLabel(fr, '12'), 'Numéro #12');
    });

    test('storyline is arc narratif, specials are hors-série', () {
      expect(LibraryType.manga.storylineTitle(fr), 'Arc narratif');
      expect(LibraryType.manga.specialsTitle(fr), 'Hors-série');
    });

    test('the resume button uses the same units, in shorthand', () {
      expect(
        LibraryType.manga.continueChapterLabel(fr, '3'),
        'Reprendre — ch. 3',
      );
      // Kavita's own issue shorthand is a bare hash mark, in both languages.
      expect(
        LibraryType.comic.continueChapterLabel(fr, '12'),
        'Reprendre — #12',
      );
      expect(
        LibraryType.comic.continueChapterLabel(en, '12'),
        'Continue — #12',
      );
      expect(
        LibraryType.manga.continueVolumeLabel(fr, '1'),
        'Reprendre — tome 1',
      );
      expect(
        LibraryType.book.continueVolumeLabel(fr, '1'),
        'Reprendre — livre 1',
      );
    });

    test('a book library says livre', () {
      expect(LibraryType.book.volumesTitle(fr), 'Livres');
      expect(LibraryType.lightNovel.volumeLabel(fr, '2'), 'Livre 2');
    });
  });

  group('naming one chapter follows Kavita', () {
    test('a special is known by its title alone', () {
      final special = chapter(title: 'Omake', isSpecial: true);
      expect(LibraryType.manga.chapterTitle(en, special), 'Omake');
      // Never numbered, whatever the library calls its chapters.
      expect(LibraryType.comic.chapterTitle(en, special), 'Omake');
    });

    test('a title is appended to the number, not swapped for it', () {
      final named = chapter(titleName: 'The Duel');
      expect(
        LibraryType.manga.chapterTitle(en, named),
        'Chapter 12 - The Duel',
      );
      expect(
        LibraryType.comic.chapterTitle(fr, named),
        'Numéro #12 - The Duel',
      );
    });

    test('a title that only repeats the number is dropped', () {
      expect(
        LibraryType.manga.chapterTitle(en, chapter(titleName: '12')),
        'Chapter 12',
      );
      expect(
        LibraryType.manga.chapterTitle(en, chapter(titleName: 'Chapter 12')),
        'Chapter 12',
      );
    });

    test('an untitled chapter is just its number', () {
      expect(LibraryType.manga.chapterTitle(fr, chapter()), 'Chapitre 12');
    });
  });
}
