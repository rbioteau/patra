/// What the shape of a work's pages says about how it is read (#57).
///
/// Two things are known about a chapter the moment it opens — the library it
/// was shelved in, and the dimensions of its pages — and between them they
/// suggest a direction for a work nobody has chosen one for. They answer
/// **different questions and never compete**:
///
/// - **whether** a work is vertical is a property of the pages, and only the
///   dimensions can say it;
/// - **which way** it goes when it is not is a convention of origin, and only
///   the library type was ever a witness to it.
///
/// What turns the two into a direction is the chain's business and lives in
/// `reading_direction.dart`; this file only measures.
///
/// **And it measures pictures only.** A chapter of words has no page with a
/// size, so there is nothing here for it and nothing is recorded — see
/// [PageShapesNotifier.record], which is where that refusal is argued.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';

/// What the app has measured of one work: the library it was shelved in, and
/// whether its pages are panels rather than pages.
class PageShape {
  const PageShape({required this.libraryType, required this.isVertical});

  /// Measures what [info] says about the work it belongs to.
  ///
  /// Pages the server calls wide are dropped first: a spread is two pages'
  /// width presented as one, so its shape says nothing about the shape of a
  /// page. What is left is measured by **median** and not by mean, because
  /// one spread or one unusually short page drags a mean — which is why
  /// Kavita's own detector needs a width-variation test and a 40%-strong rule
  /// to compensate. Solo Leveling is the measured proof: its pages run from
  /// 1.43 to 10.62 tall and it medians at 6.94, where a mean over nine pages
  /// is pulled towards the manga-shaped ones among them.
  ///
  /// A work is vertical only on evidence: fewer than [measuredPagesNeeded]
  /// pages measured is not vertical, because two pages cannot tell a work
  /// that scrolls from a scan with a tall cover. That is no verdict about
  /// *being vertical* and not no answer at all: the library the work was
  /// shelved in still says which way it goes, which is the other question.
  factory PageShape.of(ChapterInfo info) {
    final tallness = <double>[
      for (final page in info.pageDimensions.entries)
        // The app's own test for a spread, so a page the server flagged and a
        // page that is plainly landscape are dropped alike.
        if (!info.isWide(page.key) &&
            page.value.width > 0 &&
            page.value.height > 0)
          page.value.height / page.value.width,
    ]..sort();
    return PageShape(
      libraryType: info.libraryType,
      isVertical:
          tallness.length >= measuredPagesNeeded &&
          _median(tallness) >= verticalTallness,
    );
  }

  final LibraryType libraryType;

  /// Whether the pages measured are panels rather than pages: a work that is
  /// scrolled rather than turned.
  final bool isVertical;
}

/// The **tallness** — height over width — at which a page is a panel rather
/// than a page.
///
/// One number, measured rather than guessed, and it is #64's: Kavita's own
/// detector calls 1.5–1.8 *"weak, many regular manga/comics have ratios in
/// this range"* and 1.8 and above *moderate*, and a real library of 27 series
/// put every work that turns between 1.30 and 1.58 while the two that scroll
/// medians at 1.86 and 6.94 — so 1.8 sits in an empty interval, and 2.0 and
/// 2.2 would open a work that scrolls as one that turns. The whole
/// measurement, and every series it was taken on, is in
/// `docs/research/reader-vertical-page-shape.md`. The instrument that took
/// it (`tool/measure_page_shapes.dart`) holds the same number as the
/// candidate it checks, so the two move together or not at all.
const double verticalTallness = 1.8;

/// How many pages have to be measured before they say anything about the
/// work. Kavita's own floor, and the right one.
const int measuredPagesNeeded = 3;

/// The middle of an already sorted list: the value half the pages are taller
/// than, which one short page or one spread cannot move.
double _median(List<double> sorted) {
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// What this session has measured, by series id.
///
/// Page dimensions reach the app in exactly one place — the `chapter-info`
/// the reader asks for when a chapter opens — and they arrive a chapter at a
/// time for a work that is one thing. So the reader's own fetch is what
/// measures a work, and it is recorded against the **series** rather than the
/// chapter it was measured on, because a direction measured on one chapter of
/// a work is a direction for the work (ADR-0007).
///
/// It is a record of measurement and not a preference, so nothing is written
/// to the device and nothing survives the session: reopening a series
/// measures it again, and the reader is inside the app, which `SessionScope`
/// builds on a container of the profile's own — so what one person's reading
/// measured is never the next person's.
final pageShapesProvider =
    NotifierProvider<PageShapesNotifier, Map<int, PageShape>>(
      PageShapesNotifier.new,
    );

class PageShapesNotifier extends Notifier<Map<int, PageShape>> {
  @override
  Map<int, PageShape> build() => const {};

  /// Records what [info] measured, against the work it belongs to.
  ///
  /// **A book measures nothing, so nothing is recorded for one** (#118). Its
  /// pages are the server's, laid out from words and carrying no dimensions
  /// for `chapter-info` to report, so [PageShape.of] would answer `isVertical:
  /// false` about a work nothing was measured of — and the library type
  /// beside it would then speak.
  ///
  /// **And the type it would speak with is not the library's.** Measured
  /// against the demo server (Kavita 0.9.1.4, `demo.kavitareader.com`):
  /// `chapter-info` reports `libraryType: 0` — manga — for all 53 epubs of a
  /// library whose type is *Books*, and `seriesFormat: 3` correctly for every
  /// one of them. So this is not the rare case of a book shelved oddly: left
  /// unguarded, **every book on every server** opened right-to-left, with
  /// nothing in the book saying so and nothing on the shelf either. That is
  /// the bug this guard exists for, and it is why the guard keys off
  /// [ChapterInfo.content] — derived from the format, which the server does
  /// report — and never off the type.
  ///
  /// What answers for a book instead is what the book *declared*
  /// (`declaredDirectionsProvider`), which is a statement rather than an
  /// inference — and where it declares nothing, the built-in left-to-right at
  /// the end of the chain, which is where a book has always opened.
  ///
  /// The guard is here rather than at the one call site so that no later
  /// caller can record a book by accident. A series holding both scans and
  /// words keeps what its scans measured: this refuses a measurement, not a
  /// work.
  ///
  /// The same measurement found `libraryType: 0` reported for a **comic** of
  /// a *Comics* library, and `pageDimensions: null` throughout — so the
  /// detected rung answers right-to-left for scans it should not either. That
  /// is #57's rung rather than this guard's business, it predates #118, and
  /// it is filed rather than quietly widened into here.
  void record(ChapterInfo info) {
    if (info.content == ChapterContent.reflowable) return;
    state = {...state, info.seriesId: PageShape.of(info)};
  }
}
