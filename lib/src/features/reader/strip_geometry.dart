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
/// It is derived for one (canvas, width factor, chapter) and only read from
/// then on: the strip is built from one of these, so a geometry and a strip
/// cannot disagree about where a page is.
class StripGeometry {
  StripGeometry({
    required this.screenWidth,
    double widthFactor = 1.0,
    required int pages,
    required double Function(int page) aspectRatioFor,
  }) : widthFactor = widthFactor
           .clamp(minWidthFactor, maxWidthFactor)
           .toDouble() {
    final laidOutWidth = width;
    var top = 0.0;
    for (var page = 0; page < pages; page++) {
      tops.add(top);
      final height = laidOutWidth / aspectRatioFor(page);
      heights.add(height);
      top += height;
    }
  }

  /// A strip with nothing in it: what the reader holds before the first
  /// layout, which is the only place the width is known.
  StripGeometry.empty()
    : screenWidth = 0,
      widthFactor = 1.0;

  /// How narrow and how wide the strip is ever laid out.
  ///
  /// `1.0` is the whole screen — how a chapter opens, and the only value that
  /// changes nothing about the way it reads today. Below it the strip is
  /// narrower than the screen and sits centred on the reader's black canvas.
  /// The range stops at `1.0` because wider than the screen is the half of
  /// this feature that needs a horizontal pan to go with it; raising it is
  /// that pan's business, and not this constant's alone.
  static const double minWidthFactor = 0.5;
  static const double maxWidthFactor = 1.0;

  /// The width of the canvas the strip is drawn on: the screen, which is
  /// what the factor is a fraction of. The reader hands it the width it was
  /// given, which is the window's, since its body fills the window.
  final double screenWidth;

  /// How wide the strip is drawn, as a fraction of [screenWidth].
  ///
  /// Clamped here rather than wherever the factor comes from, because two
  /// things will set it — a preference and a pinch — and they must not be
  /// able to clamp it differently.
  final double widthFactor;

  /// The width every page is laid out at: a height is this over the page's
  /// aspect ratio, so every number below follows from it.
  double get width => screenWidth * widthFactor;

  /// How much canvas is left either side of the strip.
  ///
  /// Half of what the strip does not take, on each side: below `1.0` the
  /// strip is centred, and what is not strip is the reader's own black
  /// canvas — nothing of the strip is painted over it.
  double get inset => (screenWidth - width) / 2;

  /// The height of each page, in the order the chapter reads.
  final List<double> heights = <double>[];

  /// Where each page starts, measured from the top of the strip.
  final List<double> tops = <double>[];

  int get pages => heights.length;

  /// The height of the whole strip.
  double get total => pages == 0 ? 0 : tops.last + heights.last;

  /// The width a page is asked of the decoder for a strip laid out
  /// [laidOutWidth] points wide, on a device [devicePixelRatio] dense: the
  /// width it is drawn at, and never the size the file happens to be.
  ///
  /// Not an optimisation to be deferred. Narrowing the strip puts more pages
  /// in the same cache extent — about three to five between full width and
  /// half — so a decode left at the file's own size multiplies decoded
  /// memory for a change nobody can see. It is one number for the whole strip
  /// for a second reason: `ResizeImage` puts the width in its cache key, so a
  /// page warmed ahead at one width and drawn at another is two images, one
  /// of them decoded for nothing.
  ///
  /// Asked of a width rather than of this strip because a strip being pinched
  /// is drawn at one width and decoded at another — the width it *settled*
  /// at, which is not a geometry of its own (see `strip_width.dart`). The
  /// answer has to be the same sum either way, or a page warmed at one width
  /// and drawn at another is two images.
  static int decodeWidthFor(double laidOutWidth, double devicePixelRatio) =>
      (laidOutWidth * devicePixelRatio).ceil();

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
/// remember where it got to, and centred on the canvas when it is narrower
/// than the canvas is.
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
class StripExtentList extends StatelessWidget {
  const StripExtentList({
    super.key,
    required this.geometry,
    required this.itemBuilder,
  });

  final StripGeometry geometry;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      // The canvas the strip does not take. What is left either side is the
      // reader's own black, which is also what centres the strip.
      padding: EdgeInsets.symmetric(horizontal: geometry.inset),
      sliver: SliverVariedExtentList(
        delegate: _StripChildDelegate(itemBuilder, geometry: geometry),
        itemExtentBuilder: (int index, _) => geometry.heights[index],
      ),
    );
  }
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
  _StripChildDelegate(super.builder, {required this.geometry});

  final StripGeometry geometry;

  @override
  int? get childCount => geometry.pages;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) =>
      geometry.total;
}
