import 'package:flutter/widgets.dart';

/// The geometry of a strip: how tall every page is, where every page starts,
/// and how tall the whole strip is, for the width it is laid out at.
///
/// A height is the width over the page's aspect ratio, and the server reports
/// the ratios before a single image has decoded — so all of this is known
/// before anything is painted, and nothing here asks a lazy sliver to guess.
/// That is the point of the module: the offsets the strip is scrolled to and
/// the offsets it is *drawn at* are one set of numbers.
///
/// It is derived for one (width, chapter) and only read from then on: the
/// strip is built from one of these, so a geometry and a strip cannot disagree
/// about where a page is.
class StripGeometry {
  StripGeometry({
    required this.width,
    required int pages,
    required double Function(int page) aspectRatioFor,
  }) {
    var top = 0.0;
    for (var page = 0; page < pages; page++) {
      tops.add(top);
      final height = width / aspectRatioFor(page);
      heights.add(height);
      top += height;
    }
  }

  /// A strip with nothing in it: what the reader holds before the first
  /// layout, which is the only place the width is known.
  StripGeometry.empty() : width = 0;

  /// The width every page is laid out at.
  final double width;

  /// The height of each page, in the order the chapter reads.
  final List<double> heights = <double>[];

  /// Where each page starts, measured from the top of the strip.
  final List<double> tops = <double>[];

  int get pages => heights.length;

  /// The height of the whole strip.
  double get total => pages == 0 ? 0 : tops.last + heights.last;

  /// The page containing [contentY], measured from the top of the strip.
  int pageAt(double contentY) {
    if (tops.isEmpty) return 0;
    var low = 0;
    var high = tops.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (tops[mid] <= contentY) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// [contentY] named as a page and a fraction down it.
  ///
  /// Not as a pixel offset: a name like this survives a change of every
  /// height at once — a rotation, or a different width — where a raw offset
  /// lands somewhere else entirely.
  StripAnchor anchorAt(double contentY) {
    if (pages == 0) return const StripAnchor(0, 0);
    final page = pageAt(contentY.clamp(0.0, total));
    final height = heights[page];
    return StripAnchor(
      page,
      height <= 0 ? 0 : ((contentY - tops[page]) / height).clamp(0.0, 1.0),
    );
  }

  /// The scroll offset that puts [anchor] at the top of the viewport.
  double offsetFor(StripAnchor anchor) =>
      tops[anchor.page] + anchor.fraction * heights[anchor.page];
}

/// A place in the strip: the page it is on, and how far down that page.
class StripAnchor {
  const StripAnchor(this.page, this.fraction);

  final int page;
  final double fraction;

  @override
  String toString() => 'page $page at ${(fraction * 100).toStringAsFixed(1)}%';
}

/// The strip itself, as a sliver: a gapless column of pages, told every
/// page's extent rather than left to lay them out one after another and
/// remember where it got to.
///
/// That difference is the whole of ADR-0006's sliver requirement. A sliver
/// that measures its children as it goes keeps the offset its *first* child
/// had, so changing every height at once — which is what a different width
/// does — shifts the content by the offset times one minus the ratio of the
/// two heights, and its total is an average-based guess besides, so the last
/// page is never reached. Given the extents, offsets, the page at an offset
/// and the total are all derived from them, and a change of every height is
/// exact.
///
/// The cost is a layout that walks the pages: the sliver sums the extents to
/// place each child and searches from the first page for the one at the
/// current offset. Nothing at 200 pages, worth watching at 2000.
class StripExtentList extends SliverVariedExtentList {
  StripExtentList({
    super.key,
    required StripGeometry geometry,
    required IndexedWidgetBuilder itemBuilder,
  }) : super(
         delegate: _StripChildDelegate(
           itemBuilder,
           pages: geometry.pages,
           total: geometry.total,
         ),
         itemExtentBuilder: (int index, _) => geometry.heights[index],
       );
}

/// A delegate that states the strip's whole extent, the way the reader's
/// thumbnail strip's delegate did.
///
/// Left to itself a lazy sliver averages the children it has built and
/// applies that to the rest; with pages of different heights the guess is out
/// by thousands of points, which is also how far from the truth the scroll
/// extent sits — and an extent that is short is a last page that cannot be
/// reached. Stating it keeps the extent steady while the strip is built, too,
/// where the guess moves on every frame.
class _StripChildDelegate extends SliverChildBuilderDelegate {
  _StripChildDelegate(super.builder, {required this.pages, required this.total});

  final int pages;
  final double total;

  @override
  int? get childCount => pages;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) =>
      total;
}
