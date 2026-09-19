import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations_en.dart';
import 'package:patra/l10n/generated/app_localizations_fr.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/entity_naming.dart';

void main() {
  final en = AppLocalizationsEn();
  final fr = AppLocalizationsFr();

  Chapter chapter({
    String range = '12',
    String title = '',
    String titleName = '',
    bool isSpecial = false,
  }) => Chapter.fromJson({
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

    test('a chapter with no number is known by its title alone', () {
      // What a one-shot is: an album, a standalone novel, any file Kavita
      // parsed no number out of. The unit used to be drawn around the
      // number that is not there — "Chapter  - Le Combat ordinaire" — which
      // is the same mistake a special would make without its own rule.
      final oneShot = chapter(range: '', title: 'Le Combat ordinaire');
      expect(
        LibraryType.comic.chapterTitle(en, oneShot),
        'Le Combat ordinaire',
      );
      expect(LibraryType.book.chapterTitle(fr, oneShot), 'Le Combat ordinaire');
      // Kavita's own sentinel is not a number either, and never reaches a
      // label.
      expect(
        LibraryType.manga.chapterTitle(
          en,
          chapter(range: '-100000', titleName: 'Le Combat ordinaire'),
        ),
        'Le Combat ordinaire',
      );
    });

    // The one place a chapter's number is stored rather than drawn: the copy
    // a reader saves. A volume with no chapter breakdown is the reading unit
    // there too, so its copy is named after the volume — a row in the
    // Downloads tab reading "-100000" names nothing a reader recognises.
    test('a copy of a volume with no chapters is named by the volume', () {
      final v = Volume.fromJson({
        'id': 1,
        'name': '2',
        'minNumber': 2,
        'chapters': [
          {'id': 7, 'range': '-100000', 'minNumber': -100000},
        ],
      });
      final chapter = v.chapters.first;
      expect(chapter.isVolumePlaceholder, isTrue);
      expect(
        LibraryType.manga.chapterTitle(en, chapter),
        contains('100000'),
        reason:
            'the chapter on its own has no honest name, which is why the '
            'copy is named after the volume it stands for',
      );
      expect(LibraryType.manga.volumeLabel(en, v.name), 'Volume 2');
      expect(LibraryType.manga.volumeLabel(fr, v.name), 'Tome 2');
    });
  });

  group('naming what reading resumes at', () {
    Volume volume(num minNumber, List<Map<String, dynamic>> chapters) =>
        Volume.fromJson({
          'id': 1,
          'name': '1',
          'minNumber': minNumber,
          'chapters': chapters,
        });
    Map<String, dynamic> placeholder() => {
      'id': 2,
      'range': '-100000',
      'minNumber': -100000,
    };

    // A volume with no chapter breakdown is known by the volume, and its
    // placeholder chapter carries Kavita's sentinel, which must never be
    // shown as a number.
    test('a volume with no chapters is named by the volume', () {
      final v = volume(1, [placeholder()]);
      expect(LibraryType.manga.terseTitle(en, v, v.chapters.first), 'Volume 1');
      expect(LibraryType.book.terseTitle(en, v, v.chapters.first), 'Book 1');
      expect(LibraryType.manga.terseTitle(fr, v, v.chapters.first), 'Tome 1');
    });

    test('the sentinel never reaches the screen', () {
      final v = volume(1, [placeholder()]);
      expect(
        LibraryType.manga.terseTitle(en, v, v.chapters.first),
        isNot(contains('100000')),
      );
      // A placeholder inside the loose-leaf pseudo-volume names nothing at
      // all rather than naming a volume that does not exist.
      final loose = volume(-100000, [placeholder()]);
      expect(LibraryType.manga.terseTitle(en, loose, loose.chapters.first), '');
    });

    test('an ordinary chapter is named by its number alone', () {
      final v = volume(1, [
        {'id': 3, 'range': '12', 'minNumber': 12, 'titleName': 'Le duel'},
      ]);
      expect(
        LibraryType.manga.terseTitle(en, v, v.chapters.first),
        'Chapter 12',
      );
      expect(
        LibraryType.comic.terseTitle(en, v, v.chapters.first),
        'Issue #12',
      );
    });

    test('a special is known by its title alone', () {
      final v = volume(100000, [
        {
          'id': 4,
          'range': '1',
          'minNumber': 1,
          'isSpecial': true,
          'titleName': 'Prologue',
        },
      ]);
      expect(LibraryType.manga.terseTitle(en, v, v.chapters.first), 'Prologue');
    });
  });
}
