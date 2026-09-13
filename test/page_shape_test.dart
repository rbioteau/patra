import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
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
ChapterInfo _chapter({
  int seriesId = 3,
  LibraryType libraryType = LibraryType.manga,
  List<(int, int)> pages = const [],
  Set<int> wide = const {},
}) => ChapterInfo(
  seriesId: seriesId,
  volumeId: 4,
  libraryId: 1,
  pages: pages.length,
  seriesName: 'Berserk',
  title: 'Chapter 1',
  libraryType: libraryType,
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

/// A container that has measured [shapes] and nothing else — which is where
/// the app is the moment a chapter's `chapter-info` has landed.
ProviderContainer _measured(List<ChapterInfo> chapters) {
  final container = ProviderContainer(overrides: [testKeychain()]);
  addTearDown(container.dispose);
  for (final chapter in chapters) {
    container.read(pageShapesProvider.notifier).record(chapter);
  }
  return container;
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

Future<ProviderContainer> _reading(List<ChapterInfo> chapters) async {
  final container = ProviderContainer(
    overrides: [
      testKeychain(),
      profilePreferencesStoreProvider.overrideWithValue(
        await preferencesStore(),
      ),
      initialAuthStateProvider.overrideWithValue(
        AuthState(profiles: [_romain], activeId: _romain.id),
      ),
    ],
  );
  addTearDown(container.dispose);
  for (final chapter in chapters) {
    container.read(pageShapesProvider.notifier).record(chapter);
  }
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
    test('a manga reads right to left, and its panels scroll', () {
      final paged = _measured([
        _chapter(pages: [_page, _page, _page]),
      ]);
      expect(
        paged.read(detectedDirectionProvider(3)),
        ReadingDirection.rightToLeft,
      );

      final scrolling = _measured([
        _chapter(pages: [_panel, _panel, _panel]),
      ]);
      expect(
        scrolling.read(detectedDirectionProvider(3)),
        ReadingDirection.verticalScroll,
      );
    });

    test('every other kind of library reads the way it always has', () {
      for (final type in [
        LibraryType.comic,
        LibraryType.book,
        LibraryType.image,
        LibraryType.lightNovel,
        LibraryType.comicVine,
      ]) {
        final container = _measured([
          _chapter(libraryType: type, pages: [_page, _page, _page]),
        ]);
        expect(
          container.read(detectedDirectionProvider(3)),
          ReadingDirection.leftToRight,
          reason: '$type is not a manga library',
        );
      }
    });

    test('a work that is vertical is vertical in any library', () {
      // Which way a work goes is the library type’s answer, but *whether* it
      // scrolls is the pages’ — and that is the one the dimensions own.
      final container = _measured([
        _chapter(
          libraryType: LibraryType.comic,
          pages: [_panel, _panel, _panel],
        ),
      ]);
      expect(
        container.read(detectedDirectionProvider(3)),
        ReadingDirection.verticalScroll,
      );
    });

    test('a series the app has not measured is a series nothing is guessed '
        'about', () {
      final container = _measured([
        _chapter(seriesId: 3, pages: [_panel, _panel, _panel]),
      ]);
      expect(container.read(detectedDirectionProvider(9)), isNull);
    });

    test('is asked of the work, not of the chapter that measured it', () {
      // Recorded against the series, so the chapter it was measured on is not
      // part of what is asked for: the second chapter here belongs to the
      // same work, and it is the work that has a direction.
      final container = _measured([
        _chapter(seriesId: 3, pages: [_panel, _panel, _panel]),
      ]);
      expect(
        container.read(detectedDirectionProvider(3)),
        ReadingDirection.verticalScroll,
      );
    });

    test('a work is measured again as it is read', () {
      // So the chapter in hand is the one that speaks for it, even where an
      // earlier chapter of the same work measured differently.
      final container = _measured([
        _chapter(seriesId: 3, pages: [_panel, _panel, _panel]),
        _chapter(seriesId: 3, pages: [_page, _page, _page]),
      ]);
      expect(
        container.read(detectedDirectionProvider(3)),
        ReadingDirection.rightToLeft,
        reason: 'the newest measurement is the one recorded',
      );
    });
  });

  group('in the chain', () {
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
