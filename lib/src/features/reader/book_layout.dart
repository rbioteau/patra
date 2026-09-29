import '../../api/models.dart';
import '../../settings/reading_settings.dart';

/// [size] moved by [delta] steps of [step] points, inside the range a book
/// can be set at, and on a whole point: a size left between two steps by the
/// slider this replaced lands back on one.
double steppedTextSize(double size, int delta, {int step = 1}) =>
    (size.round() + delta * step)
        .clamp(minBookTextSize, maxBookTextSize)
        .toDouble();

/// The room between a book's lines, offered as three spacings rather than a
/// slider: a line of prose is read at one of a few leadings, and a number a
/// person has to tune is a number they will not tune.
enum BookSpacing {
  tight(1.35),
  normal(1.55),
  loose(1.8);

  const BookSpacing(this.height);

  /// The leading, as a share of the size of the words.
  final double height;

  /// The spacing [height] is, or null for a height set off the three — which
  /// then names no segment rather than the nearest one.
  static BookSpacing? of(double height) {
    for (final spacing in values) {
      if ((spacing.height - height).abs() < .001) return spacing;
    }
    return null;
  }
}

/// The title of the chapter [page] is in: the deepest entry of the server's
/// contents that has begun by that page, or null before the first one.
///
/// Walked in the order the contents are listed, which is the order the book
/// is read in, so where a part and its first chapter begin on the same page
/// the chapter is the answer — and where the part begins alone, the part is.
String? chapterAt(List<BookContentsEntry> contents, int page) {
  String? found;
  void walk(List<BookContentsEntry> entries) {
    for (final entry in entries) {
      if (entry.page > page) return;
      found = entry.title;
      walk(entry.children);
    }
  }

  walk(contents);
  return found;
}
