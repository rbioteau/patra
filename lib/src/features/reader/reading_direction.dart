/// Which direction a chapter is read in, and where that answer came from.
///
/// It is **one chain, each rung asked only when the one above it has no
/// answer** (ADR-0007):
///
/// 1. the **series** — a direction chosen for that one series;
/// 2. the **library** — a direction chosen for every series shelved there
///    (#65);
/// 3. the **detected** — the direction the work itself suggests (#57): the
///    library a work was shelved in and the shape of its pages, measured by
///    `page_shape.dart` from the chapter being read;
/// 4. the left-to-right a chapter has always opened in.
///
/// There used to be two rungs between the series' own and the detected one —
/// the reading profile's own default and this device's — and #58 took them
/// out. Detection is per series, so what those defaults were doing, choosing a
/// direction for works nobody has opened, is what detection does better and
/// *per work*; and a rung held by a person or a device overrides detection for
/// every series at once, which in a library holding manga and webtoons is
/// precisely wrong. What corrects a library the guess gets wrong is the
/// library's own rung (#65), which sits where those two were.
///
/// What is left above the detected rung is therefore two rungs about works and
/// nothing about people or devices — which is what the direction is: the one
/// of the reader's three settings that is about the book rather than the hand,
/// and the only one kept per work rather than per person. Magnifying and the
/// width belong to the hand and follow the person.
///
/// Both maps belong to the profile that chose them and are never sent to the
/// server: Kavita keeps no such preference, and a person's own reading of a
/// series is theirs. They are stored in the one keychain row that profile
/// already owns whole (`settings/profile_preferences.dart`), so forgetting a
/// profile takes them along with everything else that profile chose.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../settings/profile_preferences.dart';
import '../../settings/reading_settings.dart';
import 'page_shape.dart';

/// Where the direction in force came from.
///
/// A checked row on its own reads as "I chose this", and a guess is not a
/// choice — so the reader's sheet says which rung answered, and the two rows
/// that act on the answer are drawn from what the rungs actually hold.
enum ReadingDirectionSource {
  /// This series' own direction: a choice about one work.
  series,

  /// The direction chosen for every series in this library: a choice about
  /// one library (#65).
  library,

  /// Worked out from the work rather than chosen by anybody (#57).
  detected,

  /// The left-to-right a chapter has always opened in: the one rung that
  /// answers without anybody having chosen anything, and so the one the
  /// sheet must never present as a choice.
  builtIn,
}

/// The direction a chapter of one series is read in, and where it came from.
///
/// Built from the three rungs and never from the answers, so the two cannot
/// disagree: which direction is in force, where it came from and what this
/// series or this library would land on without their own are all read off
/// the same three values, resolved by the same chain.
class ChapterDirection {
  ChapterDirection({
    required this.series,
    required this.library,
    required this.detected,
  }) {
    final (resolved, from) = _resolve(
      series: series,
      library: library,
      detected: detected,
    );
    direction = resolved;
    source = from;
    // Asked again with the series rung empty, which is the only difference
    // between what is in force and what would be if the series' own choice
    // were dropped.
    final (landing, _) = _resolve(library: library, detected: detected);
    withoutSeries = landing;
    // And with the library's empty instead: where the library lands, which
    // is where the chapter does too unless the series has a direction of its
    // own to keep.
    final (libraryLanding, _) = _resolve(series: series, detected: detected);
    withoutLibrary = libraryLanding;
  }

  /// What this series has chosen for itself, if anything.
  final ReadingDirection? series;

  /// What has been chosen for every series in this library, if anything:
  /// #65's rung, and the one that corrects a library the detected direction
  /// gets wrong for all of them at once.
  final ReadingDirection? library;

  /// What the work itself suggests (#57), if anything suggests anything:
  /// asked only where no work or shelf above it has been given a direction.
  final ReadingDirection? detected;

  /// The direction in force: the highest rung that has an answer.
  late final ReadingDirection direction;

  /// Which rung [direction] came from.
  late final ReadingDirectionSource source;

  /// Where this series lands if its own direction is dropped: the chain below
  /// the series rung. The row that drops one is worded with it, because
  /// "follow the default" is not much of a promise without saying which
  /// direction that is — and it is worded neutrally, since what the series
  /// lands on may be the library's own or a detected one.
  late final ReadingDirection withoutSeries;

  /// Where the library lands if its own direction is dropped: the chain below
  /// the library rung, with the series keeping its own where it has one — so
  /// this is what a chapter of this series really opens in afterwards, and
  /// not merely what the library falls back to.
  late final ReadingDirection withoutLibrary;

  /// Whether there is a series direction to go back on.
  bool get hasSeriesDirection => series != null;

  /// Whether there is a library direction to go back on.
  bool get hasLibraryDirection => library != null;

  /// Whether the direction in force is worth promoting to the library's own:
  /// it differs from what that library holds — and a library holding nothing
  /// counts as differing from everything, which is what lets a detected
  /// direction become a library's rather than only ever being beaten by one.
  bool get canPromoteToLibrary => direction != library;
}

/// #57's rung: the direction the work itself suggests, for one series.
///
/// Asked only where no direction above it has been chosen, and answering
/// nothing for a series the app has not measured — which is why the chain
/// reads as two rungs until a chapter of that series has been opened. Filled
/// from [pageShapesProvider], which is what the reader's own `chapter-info`
/// records: page dimensions reach the app nowhere else, so a work nobody has
/// opened is a work nothing has been guessed about.
///
/// Keyed by series and not by chapter because what is remembered is per
/// series: a direction detected for one chapter of a work is a direction for
/// the work.
final detectedDirectionProvider = Provider.family<ReadingDirection?, int>((
  ref,
  seriesId,
) {
  final shape = ref.watch(pageShapesProvider)[seriesId];
  if (shape == null) return null;
  return shape.isVertical
      ? ReadingDirection.verticalScroll
      : _horizontal(shape.libraryType);
});

/// Which way a work goes when its pages are not panels, from the library it
/// was shelved in.
///
/// The dimensions never say this — a manhua's pages are the shape of manga's
/// and it reads the other way — so it is the library type's answer, and it is
/// the one signal it carries. Manga is the only type that carries a direction
/// with it; a comic, an issue run, a book, a light novel and a shelf of
/// images all open the way a chapter always has. Where the type is wrong for
/// a whole library, that library's own direction (#65) is what corrects it,
/// and a series' own is what corrects one work.
ReadingDirection _horizontal(LibraryType type) => type == LibraryType.manga
    ? ReadingDirection.rightToLeft
    : ReadingDirection.leftToRight;

/// What the chain is asked about: the series a chapter belongs to, and the
/// library that series is shelved in — two ids because the library's rung is
/// keyed on the library and the series' on the work.
typedef ChapterDirectionKey = ({int seriesId, int libraryId});

/// Which direction a chapter of [key.seriesId] opens in for whoever is
/// reading, and where that answer came from.
///
/// A family of the series and its library rather than of the chapter: the
/// whole chain is per-series but for the library's rung, and a chapter is one
/// of many ways in.
final chapterDirectionProvider =
    Provider.family<ChapterDirection, ChapterDirectionKey>((ref, key) {
      return ChapterDirection(
        series: ref.watch(seriesDirectionsProvider)[key.seriesId],
        library: ref.watch(libraryDirectionsProvider)[key.libraryId],
        detected: ref.watch(detectedDirectionProvider(key.seriesId)),
      );
    });

/// The chain itself: the first rung with an answer, and which rung it was.
///
/// The order is the series', then the **library's** (#65), then the detected
/// direction (#57), and the built-in left-to-right last of all. The two rungs
/// about a person and a device that used to sit between the library's and the
/// detected one are #58's removal.
///
/// Nothing a guess can reach is above it: the detected rung is asked only
/// where no series and no library has been given a direction, because a guess
/// must never beat a choice (ADR-0007). The built-in left-to-right behind it
/// is not a choice either, which is the whole of why a library that is merely
/// *set* is not the same as one that was never set.
(ReadingDirection, ReadingDirectionSource) _resolve({
  ReadingDirection? series,
  ReadingDirection? library,
  ReadingDirection? detected,
}) {
  if (series != null) return (series, ReadingDirectionSource.series);
  if (library != null) return (library, ReadingDirectionSource.library);
  if (detected != null) return (detected, ReadingDirectionSource.detected);
  // Nothing anybody chose and nothing worked out: the left-to-right a chapter
  // has always opened in, which is the one answer in here nobody made.
  return (ReadingDirection.leftToRight, ReadingDirectionSource.builtIn);
}
