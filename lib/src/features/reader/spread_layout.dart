import '../../api/models.dart';

/// How a landscape spread groups a chapter's pages onto screens.
///
/// Two at a time, except where the scan is *itself* a double page. Kavita
/// reports each page's dimensions, and a page wider than it is tall is already
/// a spread: pairing it with its neighbour would shrink both to a quarter of
/// the screen and put a spine down the middle of a drawing meant to be seen
/// whole. Those get a screen of their own.
///
/// A wide page also shifts the parity of everything after it — pages 0 and 1
/// share a screen, page 2 is a spread on its own, and then 3 and 4 pair up —
/// which is why this is a walk over the chapter rather than `page ~/ 2`.
///
/// With no dimensions from the server nothing is wide and this is exactly the
/// old pairing.
class SpreadLayout {
  SpreadLayout._(this.slots, this._slotOfPage);

  factory SpreadLayout.of(ChapterInfoDto chapter) {
    final slots = <List<int>>[];
    final slotOfPage = List.filled(chapter.pages, 0);
    var page = 0;
    while (page < chapter.pages) {
      final pairs =
          !chapter.isWide(page) &&
          page + 1 < chapter.pages &&
          !chapter.isWide(page + 1);
      slotOfPage[page] = slots.length;
      if (pairs) {
        slotOfPage[page + 1] = slots.length;
        slots.add([page, page + 1]);
        page += 2;
      } else {
        slots.add([page]);
        page += 1;
      }
    }
    return SpreadLayout._(slots, slotOfPage);
  }

  /// The pages on each screen, in reading order.
  final List<List<int>> slots;

  /// Which screen each page is on.
  final List<int> _slotOfPage;

  int get length => slots.length;

  /// The screen [page] is on. Out-of-range pages clamp to the ends, so a stale
  /// page number from a seek can never index past the chapter.
  int indexOf(int page) => _slotOfPage.isEmpty
      ? 0
      : _slotOfPage[page.clamp(0, _slotOfPage.length - 1)];

  /// The first page shown on screen [index] — what the reader calls "the page
  /// it is on", and where a step lands.
  int firstOf(int index) =>
      slots.isEmpty ? 0 : slots[index.clamp(0, slots.length - 1)].first;

  /// How many pages are shown alongside [page], itself included.
  int spanOf(int page) => slots.isEmpty ? 1 : slots[indexOf(page)].length;
}
