/// Which direction a chapter is read in, and where that answer came from.
///
/// It is **one chain, each rung asked only when the one above it has no
/// answer** (ADR-0007):
///
/// 1. the **series** — a direction chosen for that one series;
/// 2. the **profile** — the reading profile's own stored default;
/// 3. the **device** — this device's own stored default;
/// 4. the **detected** — the direction the work itself suggests (#57), asked
///    only while the device holds nothing, since a guess must never beat a
///    choice: the library a work was shelved in and the shape of its pages,
///    measured by `page_shape.dart` from the chapter being read;
/// 5. the left-to-right a chapter has always opened in.
///
/// The direction used to be taken from the profile's default when the chapter
/// opened and changed in memory afterwards, which made it neither: a chapter
/// set to vertical reopened paged and the profile's preference had not moved,
/// because nothing had been written at all. The two rows beside it in the
/// cog's sheet both write through, so the direction was the odd one out — and
/// it is the one row that is about the work rather than about the hand, which
/// is why it is the one that gets a per-series rung and magnifying and the
/// width do not.
///
/// A series direction belongs to the profile that chose it and is never sent
/// to the server: Kavita keeps no such preference, and a person's own reading
/// of a series is theirs. It is stored in the one keychain row that profile
/// already owns whole (`settings/profile_preferences.dart`), so forgetting a
/// profile takes it along with everything else that profile chose.
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

  /// The reading profile's own default, which is what they chose for
  /// everything they read.
  profile,

  /// Worked out from the work rather than chosen by anybody (#57).
  detected,

  /// This device's stored default — or, where it holds none, the
  /// left-to-right the chain ends in: the one rung that answers without
  /// anybody having chosen, and the one a detected direction is measured
  /// against.
  device;
}

/// The direction a chapter of one series is read in, and where it came from.
///
/// Built from the four rungs and never from the answers, so the two cannot
/// disagree: which direction is in force, where it came from and what this
/// series would land on without its own are all read off the same four
/// values, resolved by the same chain.
class ChapterDirection {
  ChapterDirection({
    required this.series,
    required this.profile,
    required this.detected,
    required this.device,
  }) {
    final (resolved, from) = _resolve(
      series: series,
      profile: profile,
      device: device,
      detected: detected,
    );
    direction = resolved;
    source = from;
    // Asked again with the series rung empty, which is the only difference
    // between what is in force and what would be if the series' own choice
    // were dropped.
    final (landing, _) = _resolve(
      profile: profile,
      device: device,
      detected: detected,
    );
    withoutSeries = landing;
  }

  /// What this series has chosen for itself, if anything.
  final ReadingDirection? series;

  /// What the reading profile has **stored** as their own default, if
  /// anything — not the direction a chapter opens in, which this often is
  /// not. Null is not the left-to-right the chain ends in, and the difference
  /// is what lets a detected direction be promoted over nothing at all.
  final ReadingDirection? profile;

  /// What this device has stored as its own default, if anything: asked
  /// **above** the detected rung, because a direction somebody set on this
  /// device is a choice and a guess must never beat one (ADR-0007).
  final ReadingDirection? device;

  /// What the work itself suggests (#57), if anything suggests anything:
  /// asked only where nobody has stored a direction above it.
  final ReadingDirection? detected;

  /// The direction in force: the highest rung that has an answer.
  late final ReadingDirection direction;

  /// Which rung [direction] came from.
  late final ReadingDirectionSource source;

  /// Where this series lands if its own direction is dropped: the chain below
  /// the series rung. The row that drops one is worded with it, because
  /// "follow the default" is not much of a promise without saying which
  /// direction that is — and it is worded neutrally, since what the series
  /// lands on may be the profile's own or a detected one.
  late final ReadingDirection withoutSeries;

  /// Whether there is a series direction to go back on.
  bool get hasSeriesDirection => series != null;

  /// Whether the direction in force is worth promoting to the profile's own
  /// default: it differs from what they have stored — and **no stored default
  /// counts as differing from everything**, which is what lets a detected
  /// direction become somebody's default rather than only ever being beaten
  /// by one.
  bool get canPromote => direction != profile;
}

/// #57's rung: the direction the work itself suggests, for one series.
///
/// Asked only where nothing has been stored above it, and answering nothing
/// for a series the app has not measured — which is why the chain reads as
/// three rungs until a chapter of that series has been opened. It is filled
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

/// Which direction a chapter of [seriesId] opens in for whoever is reading,
/// and where that answer came from.
///
/// A family of the series and not of the chapter: the whole chain is
/// per-series, and a chapter is one of many ways in.
final chapterDirectionProvider = Provider.family<ChapterDirection, int>((
  ref,
  seriesId,
) {
  final store = ref.read(profilePreferencesStoreProvider);
  return ChapterDirection(
    series: ref.watch(seriesDirectionsProvider)[seriesId],
    profile: ref.watch(profileDirectionProvider),
    detected: ref.watch(detectedDirectionProvider(seriesId)),
    device: store.deviceDirection,
  );
});

/// The chain itself: the first rung with an answer, and which rung it was.
///
/// The order is the series', then the profile's, then **this device's
/// stored default**, then the detected direction, and the built-in
/// left-to-right last of all. The last two of those are the surprising pair,
/// and they are that way round because a guess must never beat a choice
/// (ADR-0007): a direction this device has stored is one somebody set here,
/// where the left-to-right an absent key falls back to is not a choice at
/// all — the difference the stored language already makes between an empty
/// string and an absent one. So the detected rung is asked while the device
/// holds nothing and stands down the moment it does; #57 fills it, and
/// nothing here has to change for that to be true.
(ReadingDirection, ReadingDirectionSource) _resolve({
  ReadingDirection? series,
  ReadingDirection? profile,
  ReadingDirection? device,
  ReadingDirection? detected,
}) {
  if (series != null) return (series, ReadingDirectionSource.series);
  if (profile != null) return (profile, ReadingDirectionSource.profile);
  if (device != null) return (device, ReadingDirectionSource.device);
  if (detected != null) return (detected, ReadingDirectionSource.detected);
  // Nothing anybody chose anywhere and nothing worked out: the left-to-right
  // a chapter has always opened in. It reads as the device's rung because
  // that is the rung it stands behind rather than inside.
  return (ReadingDirection.leftToRight, ReadingDirectionSource.device);
}
