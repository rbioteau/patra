import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/features/series/series_selection.dart';
import 'package:patra/src/settings/profile_preferences.dart';

/// What the series screen decides without drawing anything: which view a
/// series opens in when nobody has chosen, what a selection holds, and what
/// the bar under it can offer to do with it.

Map<String, dynamic> _chapter(int id, num number, {bool special = false}) => {
  'id': id,
  'range': '$number',
  'minNumber': number,
  'sortOrder': number,
  'pages': 10,
  'pagesRead': 0,
  'isSpecial': special,
};

Volume _volume(int id, num number, List<Map<String, dynamic>> chapters) =>
    Volume.fromJson({
      'id': id,
      'name': '$number',
      'minNumber': number,
      'chapters': chapters,
    });

/// A volume with no chapter breakdown: Kavita's placeholder chapter inside.
Volume _whole(int id, num number) =>
    _volume(id, number, [_chapter(id * 10, -100000)]);

DownloadMembership _membership({
  Set<int> saved = const {},
  Set<int> inFlight = const {},
  Set<int> paused = const {},
  Set<int> pending = const {},
}) => DownloadMembership(
  saved: saved,
  inFlight: inFlight,
  paused: paused,
  pending: pending,
);

void main() {
  group('the view a series opens in', () {
    test('a manga of whole volumes is a grid of covers', () {
      expect(
        defaultSeriesView(LibraryType.manga, [_whole(1, 1), _whole(2, 2)]),
        SeriesView.grid,
      );
      expect(
        defaultSeriesView(LibraryType.comic, [_whole(1, 1)]),
        SeriesView.grid,
      );
    });

    test('a special beside whole volumes does not make it a list', () {
      expect(
        defaultSeriesView(LibraryType.manga, [
          _whole(1, 1),
          _volume(9, 100000, [_chapter(90, 1, special: true)]),
        ]),
        SeriesView.grid,
      );
    });

    test('chapters are rows: their covers are mostly the volume\'s', () {
      expect(
        defaultSeriesView(LibraryType.manga, [
          _volume(1, 1, [_chapter(11, 1), _chapter(12, 2)]),
        ]),
        SeriesView.list,
      );
      expect(
        defaultSeriesView(LibraryType.manga, [
          _volume(1, -100000, [_chapter(11, 1)]),
        ]),
        SeriesView.list,
        reason: 'a chapter-only series',
      );
    });

    test('a book is a list, whatever it is made of', () {
      expect(
        defaultSeriesView(LibraryType.book, [_whole(1, 1), _whole(2, 2)]),
        SeriesView.list,
      );
      expect(
        defaultSeriesView(LibraryType.lightNovel, [_whole(1, 1)]),
        SeriesView.list,
      );
    });

    test('nothing to show is a list', () {
      expect(defaultSeriesView(LibraryType.manga, const []), SeriesView.list);
    });
  });

  group('what a selection can be asked to do', () {
    test('nothing selected offers nothing', () {
      final summary = summarizeSelection(const {}, _membership());
      expect(summary.count, 0);
      expect(summary.toFetch, isEmpty);
      expect(summary.allSaved, isFalse);
    });

    test('what is neither here nor on its way is what a save fetches', () {
      final summary = summarizeSelection({
        1,
        2,
        3,
        4,
        5,
      }, _membership(saved: {1}, inFlight: {2}, paused: {3}, pending: {4}));
      expect(summary.count, 5);
      // A paused or failed copy is fetched again from the pages it kept.
      expect(summary.toFetch, {3, 4, 5});
      expect(summary.allSaved, isFalse);
    });

    test('everything here is a selection that can only be removed', () {
      final summary = summarizeSelection({1, 2}, _membership(saved: {1, 2}));
      expect(summary.toFetch, isEmpty);
      expect(summary.allSaved, isTrue);
    });
  });

  group('the selection', () {
    test('is entered with one, toggled, and left', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(seriesSelectionProvider, (_, _) {});
      final selection = container.read(seriesSelectionProvider.notifier);

      expect(sub.read(), isNull);
      selection.start(7);
      expect(sub.read(), {7});
      selection.toggle(8);
      selection.toggle(7);
      expect(sub.read(), {8});
      // Emptied by hand, it stays open: the bar says to tap to add.
      selection.toggle(8);
      expect(sub.read(), isEmpty);
      selection.replace([1, 2]);
      expect(sub.read(), {1, 2});
      selection.clear();
      expect(sub.read(), isNull);
    });

    test('a toggle outside selection mode does nothing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(seriesSelectionProvider, (_, _) {});
      container.read(seriesSelectionProvider.notifier).toggle(3);
      expect(sub.read(), isNull);
    });
  });
}
