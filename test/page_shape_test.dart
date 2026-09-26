import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/catalogue/catalogue_provider.dart';
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/features/reader/book_face.dart';
import 'package:patra/src/features/reader/page_shape.dart';
import 'package:patra/src/features/reader/reading_direction.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';

import 'test_support.dart';

/// One chapter of a work, with the pages the server measured — the only
/// numbers a guess about the shape of a work has to go on.
///
/// [pages] are (width, height) in the order the server reported them, and
/// [wide] names the ones it flagged as a double-page scan.
///
/// It carries a [libraryId] and **no library type**: `chapter-info` states one
/// and Kavita has never populated it (#120), so the chapter says which shelf
/// it is on and the catalogue says what that shelf is.
ChapterInfo _chapter({
  int seriesId = 3,
  int libraryId = 1,
  List<(int, int)> pages = const [],
  Set<int> wide = const {},
  MangaFormat format = MangaFormat.archive,
}) => ChapterInfo(
  seriesId: seriesId,
  volumeId: 4,
  libraryId: libraryId,
  pages: pages.length,
  seriesName: 'Berserk',
  title: 'Chapter 1',
  // What makes a chapter words rather than pictures: `ChapterInfo.content`
  // is read off the series' format, and `epub` is the one that reflows.
  seriesFormat: format,
  pageDimensions: {
    for (final (page, size) in pages.indexed)
      page: PageDimension(
        pageNumber: page,
        width: size.$1,
        height: size.$2,
        isWide: wide.contains(page),
      ),
  },
);

/// A manga page, which is about as tall as a comic page and not a panel.
const _page = (1000, 1450);

/// A page that is a panel: the same width, several times the height.
const _panel = (800, 4000);

/// A double-page scan: two pages' width presented as one.
const _spread = (1600, 1200);

/// What a book's own stylesheet said, recorded the way the reader records it
/// when a page lands.
void _record(ProviderContainer container, Map<int, ReadingDirection> declared) {
  for (final entry in declared.entries) {
    container
        .read(declaredDirectionsProvider.notifier)
        .record(entry.key, entry.value);
  }
}

/// Somebody reading, and a device that has never been given a direction of
/// its own: the two rungs above the detected one are both empty, which is the
/// only situation in which a guess is asked for at all.
final _romain = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-romain',
  token: signedToken(1),
);

/// The shelf every chapter here is on unless a test says otherwise, as the
/// **catalogue** holds it — which is the only place the rung reads a library's
/// type from (#120).
const _mangaShelf = Library(id: 1, name: 'Mangas', type: LibraryType.manga);

/// Lets what the catalogue is doing off the event loop finish.
///
/// Two things need it, and the test below would pass for the wrong reason
/// without either: the store's own read of the device (`_spineReadProvider`,
/// which lands a spine and so re-answers everything derived from one), and
/// `CatalogueStore.librariesWritten`, a broadcast stream — so a write and the
/// rebuild it provokes are never in the same turn, in a test or in the app.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

/// The chapter asked about, and the shelf it is on: the pair the chain is a
/// family of, written out once so a test names a series rather than a record.
ChapterDirectionKey _of(int seriesId, {int libraryId = 1}) =>
    (seriesId: seriesId, libraryId: libraryId);

/// A container that has measured [chapters] and holds [shelves] in its
/// catalogue — which is where the app is the moment a chapter's `chapter-info`
/// has landed, with the library list the launch already loaded behind it.
///
/// [declared] is the other kind of evidence the detected rung has (#118): what
/// a book's own stylesheet said, by series, recorded the way the reader
/// records it when a page lands.
///
/// [shelves] is what the device *remembers* of its libraries, and `const []`
/// is a real state rather than a corner: a chapter opened before the library
/// list has reached this device. Nothing here ever answers a request for one
/// — the store is written directly, the way a launch would have written it.
Future<ProviderContainer> _reading(
  List<ChapterInfo> chapters, {
  Map<int, ReadingDirection> declared = const {},
  List<Library> shelves = const [_mangaShelf],
}) async {
  final root = Directory.systemTemp.createTempSync('patra-page-shape-test');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  final catalogue = CatalogueStore(root: root, profileId: _romain.id);
  if (shelves.isNotEmpty) await catalogue.putLibraries(shelves);

  final container = ProviderContainer(
    overrides: [
      testKeychain(),
      profilePreferencesStoreProvider.overrideWithValue(
        await preferencesStore(),
      ),
      initialAuthStateProvider.overrideWithValue(
        AuthState(profiles: [_romain], activeId: _romain.id),
      ),
      catalogueStoreProvider.overrideWithValue(catalogue),
    ],
  );
  addTearDown(container.dispose);
  for (final chapter in chapters) {
    container.read(pageShapesProvider.notifier).record(chapter);
  }
  _record(container, declared);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what the pages say', () {
    test('the pages of a work that scrolls are panels', () {
      final shape = PageShape.of(
        _chapter(pages: [_panel, _panel, _panel, _panel, _panel]),
      );
      expect(shape.isVertical, isTrue);
    });

    test('a manga’s pages are pages', () {
      final shape = PageShape.of(
        _chapter(pages: [_page, _page, _page, _page, _page]),
      );
      expect(shape.isVertical, isFalse);
    });

    test('is measured by the median, never by the mean', () {
      // Solo Leveling, in miniature: pages from 1.43 to 10.62 tall, and a
      // mean that the manga-shaped ones among them drag below the threshold.
      final scrolling = PageShape.of(
        _chapter(pages: [(1000, 1430), (1000, 10620), (1000, 7000)]),
      );
      expect(scrolling.isVertical, isTrue, reason: 'a median of 7.0');

      // And the other way round: two square pages and one very tall one,
      // which average out at a work that scrolls and median at a comic.
      final comic = PageShape.of(
        _chapter(pages: [(1000, 1000), (1000, 1000), (1000, 10000)]),
      );
      expect(comic.isVertical, isFalse, reason: 'a median of 1.0, mean of 4.0');
    });

    test('an even number of pages is measured between the middle two', () {
      final paged = PageShape.of(
        _chapter(
          pages: [(1000, 1000), (1000, 1000), (1000, 1000), (1000, 9000)],
        ),
      );
      expect(paged.isVertical, isFalse, reason: 'a median of 1.0, mean of 3.0');

      final scrolling = PageShape.of(
        _chapter(
          pages: [(1000, 1000), (1000, 1000), (1000, 3000), (1000, 3000)],
        ),
      );
      expect(scrolling.isVertical, isTrue, reason: 'a median of 2.0');
    });

    test('a spread is not a page, and says nothing about one', () {
      // Six spreads against four pages at 1.9: taken together the median is a
      // spread’s 0.75, and a work that scrolls would open paged.
      final shape = PageShape.of(
        _chapter(
          pages: [
            _spread,
            _spread,
            _spread,
            _spread,
            _spread,
            _spread,
            (1000, 1900),
            (1000, 1900),
            (1000, 1900),
            (1000, 1900),
          ],
          wide: {0, 1, 2, 3, 4, 5},
        ),
      );
      expect(shape.isVertical, isTrue);
    });

    test('a page the server flagged as wide is dropped whether it is '
        'flagged or merely landscape', () {
      // Kavita only measures `isWide` on the files it crawled that way, so
      // the dimensions are asked as well: either is enough.
      final flagged = PageShape.of(
        _chapter(
          pages: [
            _spread,
            _spread,
            _spread,
            (1000, 1900),
            (1000, 1900),
            (1000, 1900),
          ],
          wide: {0, 1, 2},
        ),
      );
      final merelyLandscape = PageShape.of(
        _chapter(
          pages: [
            _spread,
            _spread,
            _spread,
            (1000, 1900),
            (1000, 1900),
            (1000, 1900),
          ],
        ),
      );
      expect(flagged.isVertical, isTrue);
      expect(merelyLandscape.isVertical, isTrue);
    });

    test('fewer than three pages measured is no verdict', () {
      // Kavita’s own floor: two pages cannot tell a work that scrolls from a
      // scan with a tall cover.
      expect(
        PageShape.of(_chapter(pages: [_panel, _panel])).isVertical,
        isFalse,
      );
      expect(
        PageShape.of(_chapter(pages: [_panel, _panel, _panel])).isVertical,
        isTrue,
      );
    });

    test('a page the server measured as nothing is not measured', () {
      final shape = PageShape.of(
        _chapter(pages: [(0, 0), (0, 0), (0, 0), _panel, _panel, _panel]),
      );
      expect(shape.isVertical, isTrue);
    });

    test('a chapter with no dimensions has no shape to be vertical', () {
      // A server that has not crawled the chapter yet answers with none, and
      // so does no server at all.
      expect(PageShape.of(_chapter()).isVertical, isFalse);
    });
  });

  group('the direction the work suggests', () {
    test('a manga reads right to left, and its panels scroll', () async {
      final paged = await _reading([
        _chapter(pages: [_page, _page, _page]),
      ]);
      expect(
        paged.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.rightToLeft,
      );

      final scrolling = await _reading([
        _chapter(pages: [_panel, _panel, _panel]),
      ]);
      expect(
        scrolling.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.verticalScroll,
      );
    });

    test('every other kind of library reads the way it always has', () async {
      for (final type in [
        LibraryType.comic,
        LibraryType.book,
        LibraryType.image,
        LibraryType.lightNovel,
        LibraryType.comicVine,
      ]) {
        final container = await _reading(
          [
            _chapter(pages: [_page, _page, _page]),
          ],
          shelves: [Library(id: 1, name: 'Shelf', type: type)],
        );
        expect(
          container.read(detectedDirectionProvider(_of(3))),
          ReadingDirection.leftToRight,
          reason: '$type is not a manga library',
        );
      }
    });

    test('the type is the shelf\u2019s, never the one the chapter states', () async {
      // #120, and the whole of it: `chapter-info` declares a library type and
      // Kavita has never populated it, so what a chapter says is the enum's
      // default \u2014 manga \u2014 for every library there is. Nothing here
      // passes a type to [_chapter] because there is nowhere left to pass one,
      // which is the assertion: a comic shelf reads left to right while the
      // chapter on it is exactly the chapter a manga shelf would carry.
      final comics = await _reading(
        [
          _chapter(pages: [_page, _page, _page]),
        ],
        shelves: const [
          Library(id: 1, name: 'Comics', type: LibraryType.comic),
        ],
      );
      expect(
        comics.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.leftToRight,
      );

      final mangas = await _reading([
        _chapter(pages: [_page, _page, _page]),
      ]);
      expect(
        mangas.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.rightToLeft,
        reason: 'the same chapter, on the shelf that does carry a convention',
      );
    });

    test('a shelf the device has not learned yet is no witness at all', () async {
      // The rung stands down rather than guessing: manga is the one type that
      // carries a direction, so falling back to it would be falling back to
      // right-to-left for every work whose shelf has not arrived. Nothing is
      // fetched to find out \u2014 opening a chapter is not the moment to fill
      // a household's catalogue \u2014 so the answer is simply nothing, and
      // the chain reaches the built-in left-to-right that nobody chose.
      final container = await _reading([
        _chapter(pages: [_page, _page, _page]),
      ], shelves: const []);
      expect(container.read(detectedDirectionProvider(_of(3))), isNull);

      final resolved = container.read(chapterDirectionProvider(_of(3)));
      expect(resolved.direction, ReadingDirection.leftToRight);
      expect(resolved.source, ReadingDirectionSource.builtIn);
    });

    test(
      'the list arriving is what a rung that stood down was waiting for',
      () async {
        // A device that has never stored a library list — a first launch, and a
        // link that opens a chapter before Home has asked for one. The rung
        // stands down, and then the list lands: it has to answer again.
        //
        // The listener is the assertion as much as the reads are. The rung is
        // kept for the session, so a stale "the device knows no such library"
        // is not merely held until the reader closes — nothing would ever drop
        // it, and a manga library would go on reading left to right until the
        // app was restarted. What corrects it is the store saying its library
        // list moved (`librariesRevisionProvider`), and this holds the rung
        // open across that the way an open reader does.
        final container = await _reading([
          _chapter(pages: [_page, _page, _page]),
        ], shelves: const []);
        final open = container.listen(
          detectedDirectionProvider(_of(3)),
          (_, _) {},
        );
        addTearDown(open.close);
        // Settled first, or the device's own read of the spine lands *after*
        // the write and re-answers the rung by itself — which would pass this
        // test with nothing watching the list at all.
        await _settle();
        expect(container.read(detectedDirectionProvider(_of(3))), isNull);

        await container.read(catalogueStoreProvider).putLibraries(const [
          _mangaShelf,
        ]);
        await _settle();

        expect(
          container.read(detectedDirectionProvider(_of(3))),
          ReadingDirection.rightToLeft,
          reason: 'the shelf arrived, and the rung has a witness again',
        );
      },
    );

    test('a shelf the device holds, but not this one, is no witness either', () async {
      // The same refusal by the other road: the list arrived and this library
      // is not in it, which is what a profile losing access to a library looks
      // like from here.
      final container = await _reading([
        _chapter(libraryId: 9, pages: [_page, _page, _page]),
      ]);
      expect(
        container.read(detectedDirectionProvider(_of(3, libraryId: 9))),
        isNull,
      );
    });

    test('a work that is vertical is vertical in any library', () async {
      // Which way a work goes is the library type\u2019s answer, but *whether*
      // it scrolls is the pages\u2019 \u2014 and that is the one the
      // dimensions own.
      final container = await _reading(
        [
          _chapter(pages: [_panel, _panel, _panel]),
        ],
        shelves: const [
          Library(id: 1, name: 'Comics', type: LibraryType.comic),
        ],
      );
      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.verticalScroll,
      );
    });

    test('a vertical work needs no shelf to be vertical', () async {
      // And so the one half of the guess that survives a library list nobody
      // has loaded: the pages were measured, and they answer on their own.
      final container = await _reading([
        _chapter(pages: [_panel, _panel, _panel]),
      ], shelves: const []);
      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.verticalScroll,
      );
    });

    test('a series the app has not measured is a series nothing is guessed '
        'about', () async {
      final container = await _reading([
        _chapter(seriesId: 3, pages: [_panel, _panel, _panel]),
      ]);
      expect(container.read(detectedDirectionProvider(_of(9))), isNull);
    });

    test('is asked of the work, not of the chapter that measured it', () async {
      // Recorded against the series, so the chapter it was measured on is not
      // part of what is asked for: the second chapter here belongs to the
      // same work, and it is the work that has a direction.
      final container = await _reading([
        _chapter(seriesId: 3, pages: [_panel, _panel, _panel]),
      ]);
      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.verticalScroll,
      );
    });

    test('a work is measured again as it is read', () async {
      // So the chapter in hand is the one that speaks for it, even where an
      // earlier chapter of the same work measured differently.
      final container = await _reading([
        _chapter(seriesId: 3, pages: [_panel, _panel, _panel]),
        _chapter(seriesId: 3, pages: [_page, _page, _page]),
      ]);
      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.rightToLeft,
        reason: 'the newest measurement is the one recorded',
      );
    });
  });

  group('what the book says of itself', () {
    test('a declared direction is what the work suggests', () async {
      // A book has no page dimensions for `chapter-info` to report, so
      // nothing is measured of it at all and what it declared is the only
      // evidence there is.
      final container = await _reading(
        [_chapter(format: MangaFormat.epub)],
        shelves: const [Library(id: 1, name: 'Books', type: LibraryType.book)],
        declared: {3: ReadingDirection.rightToLeft},
      );

      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.rightToLeft,
      );
    });

    test('only right-to-left is ever read off a book', () {
      // `direction: ltr` is the CSS default and cannot be told from a
      // stylesheet that says nothing, so a recording is only ever
      // right-to-left — which is why no test here fixes a declared
      // left-to-right and asserts on a state the parser cannot produce.
      // Pinned on the parser, since that is where the decision is made.
      expect(
        parseBookDirection(
          '<div class="book-content"><style>'
          '.book-content { direction: ltr; }</style><p>Hi</p></div>',
        ),
        isNull,
      );
      expect(
        parseBookDirection(
          '<div class="book-content"><style>'
          '.book-content { direction: rtl; }</style><p>مرحبا</p></div>',
        ),
        ReadingDirection.rightToLeft,
      );
    });

    test('is asked of the work, not of the chapter it was read on', () async {
      final container = await _reading(
        const [],
        declared: {3: ReadingDirection.rightToLeft},
      );

      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.rightToLeft,
      );
      expect(container.read(detectedDirectionProvider(_of(9))), isNull);
    });

    test(
      'a book in a manga library is not turned by the shelf it is on',
      () async {
        // The regression #118 shipped with and the reason this guard exists.
        // A book has no page dimensions for `chapter-info` to report, so a
        // shape recorded for one says `isVertical: false` about a work nothing
        // was measured of — and the library type beside it then speaks. But the
        // type witnesses a convention about how *scans* are bound, and an epub
        // shelved in a manga library is not bound at all: every book on that
        // shelf opened right-to-left with nothing in it saying so.
        final container = await _reading([_chapter(format: MangaFormat.epub)]);

        expect(container.read(detectedDirectionProvider(_of(3))), isNull);
        expect(
          container.read(pageShapesProvider)[3],
          isNull,
          reason: 'a book measures nothing, so nothing is recorded for it',
        );
      },
    );

    test(
      'a book that declares itself is turned, whatever shelf it is on',
      () async {
        // The other half: the guard refuses a *measurement*, never the book's
        // own word.
        for (final type in [LibraryType.book, LibraryType.manga]) {
          final container = await _reading(
            [_chapter(format: MangaFormat.epub)],
            shelves: [Library(id: 1, name: 'Shelf', type: type)],
            declared: {3: ReadingDirection.rightToLeft},
          );

          expect(
            container.read(detectedDirectionProvider(_of(3))),
            ReadingDirection.rightToLeft,
            reason: '$type',
          );
        }
      },
    );

    test('a series holding both scans and words keeps what its scans '
        'measured', () async {
      // The guard refuses a measurement, not a work: an omnibus with an epub
      // chapter beside its scans is still a work whose pages were measured.
      final container = await _reading([
        _chapter(pages: [_panel, _panel, _panel]),
        _chapter(format: MangaFormat.epub),
      ]);

      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.verticalScroll,
      );
    });

    test('a book that declares nothing leaves the pages to answer', () async {
      final container = await _reading([
        _chapter(pages: [_page, _page, _page]),
      ]);

      expect(
        container.read(detectedDirectionProvider(_of(3))),
        ReadingDirection.rightToLeft,
      );
    });
  });

  group('in the chain', () {
    test('a book that declares itself is still only a guess', () async {
      // The whole point of reading a declaration as *evidence*: it fills the
      // detected rung, so a series or a library somebody has set stands above
      // it. A guess must never beat a choice (ADR-0007).
      final container = await _reading(
        [_chapter(format: MangaFormat.epub)],
        shelves: const [Library(id: 1, name: 'Books', type: LibraryType.book)],
        declared: {3: ReadingDirection.rightToLeft},
      );

      final guessed = container.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(guessed.direction, ReadingDirection.rightToLeft);
      expect(guessed.source, ReadingDirectionSource.detected);

      await container
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.leftToRight);
      final chosen = container.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(chosen.direction, ReadingDirection.leftToRight);
      expect(chosen.source, ReadingDirectionSource.series);
      // And the row back lands on what the book said of itself.
      expect(chosen.withoutSeries, ReadingDirection.rightToLeft);
    });

    test("a library's own direction outranks what the book declared", () async {
      final container = await _reading(
        [_chapter(format: MangaFormat.epub)],
        shelves: const [Library(id: 1, name: 'Books', type: LibraryType.book)],
        declared: {3: ReadingDirection.rightToLeft},
      );

      await container
          .read(libraryDirectionsProvider.notifier)
          .set(1, ReadingDirection.leftToRight);
      final resolved = container.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(resolved.direction, ReadingDirection.leftToRight);
      expect(resolved.source, ReadingDirectionSource.library);
      expect(resolved.withoutLibrary, ReadingDirection.rightToLeft);
    });

    test('a series nobody has set opens the way the work suggests', () async {
      final container = await _reading([
        _chapter(pages: [_panel, _panel, _panel]),
      ]);

      final resolved = container.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(resolved.direction, ReadingDirection.verticalScroll);
      expect(resolved.source, ReadingDirectionSource.detected);
    });

    test('a guess never beats a choice', () async {
      final container = await _reading([
        _chapter(pages: [_panel, _panel, _panel]),
      ]);

      await container
          .read(seriesDirectionsProvider.notifier)
          .set(3, ReadingDirection.leftToRight);
      final chosen = container.read(
        chapterDirectionProvider((seriesId: 3, libraryId: 1)),
      );
      expect(chosen.direction, ReadingDirection.leftToRight);
      expect(chosen.source, ReadingDirectionSource.series);

      // And the row back says where the series lands, which is the guess it
      // was overriding.
      expect(chosen.withoutSeries, ReadingDirection.verticalScroll);
    });
  });
}
