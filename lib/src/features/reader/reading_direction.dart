/// Which direction a chapter is read in, and where that answer came from.
///
/// It is **one chain, each rung asked only when the one above it has no
/// answer** (ADR-0007):
///
/// 1. the **series** — a direction chosen for that one series;
/// 2. the **library** — a direction chosen for every series shelved there
///    (#65);
/// 3. the **detected** — the direction the work itself suggests (#57): what
///    a book declared of itself in its own stylesheet (#118), and otherwise
///    the shape of its pages, measured by `page_shape.dart` from the chapter
///    being read, and the library it was shelved in, taken off the catalogue
///    the device already holds (#120);
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
import '../../catalogue/catalogue_reads.dart';
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
/// nothing for a series the app has neither measured nor read a declaration
/// off — which is why the chain reads as two rungs until a chapter of that
/// series has been opened. Both kinds of evidence reach the app in the reader
/// and nowhere else: page dimensions in the `chapter-info` it asks for
/// ([pageShapesProvider]), and a book's own declaration in the pages it is
/// handed ([declaredDirectionsProvider]). A work nobody has opened is a work
/// nothing has been guessed about.
///
/// **What the book said of itself is asked first** (#118). The two are not
/// two answers to one question: a declaration is the work's own statement,
/// where the library type is only a witness to a convention of origin — and
/// a book has no page dimensions for `chapter-info` to report at all, so
/// asking the pages first would read every book left to right and leave the
/// declaration with nothing to say. Whether a work is vertical stays the
/// pages' answer, because no book declares that: `direction` is an axis of
/// writing and not a way of turning pages.
///
/// **The library type comes from the catalogue and never from the chapter**
/// (#120). `chapter-info` states one, and `GetChapterInfo` has never assigned
/// it: from Kavita v0.7.14 to today the value its repository resolves is
/// dropped when the response is rebuilt field by field, so every chapter of
/// every library comes back with the enum's default — *manga*, the one type
/// that carries a direction. Read off the chapter, this rung therefore
/// answered right-to-left for every work whose pages produced no verdict,
/// which on a server reporting no dimensions is every work on it. The type
/// the device holds in its own catalogue is right, and asking it costs
/// nothing: [heldLibraryTypeProvider] reads the spine already in hand and
/// puts nothing on the wire, because opening a chapter is not the moment to
/// fill a household's catalogue.
///
/// **A shelf the device has not learned is not a shelf that reads
/// left-to-right.** Where the catalogue holds no answer the rung has no
/// witness to the convention and answers nothing at all, which is how it
/// stands down rather than guessing — the built-in left-to-right behind it is
/// then reached as what nobody chose, and the sheet says so. That is the same
/// refusal `libraryNameProvider` makes with an empty name, and the opposite
/// of what `libraryTypeProvider` does for a screen wording a row.
///
/// Keyed by the series **and its library**, the pair `chapterDirectionProvider`
/// is already a family of, so the two cannot be asked different questions
/// about one chapter. What is *remembered* is still per series, because a
/// direction detected for one chapter of a work is a direction for the work.
final detectedDirectionProvider =
    Provider.family<ReadingDirection?, ChapterDirectionKey>((ref, key) {
      final declared = ref.watch(declaredDirectionsProvider)[key.seriesId];
      if (declared != null) return declared;
      final shape = ref.watch(pageShapesProvider)[key.seriesId];
      if (shape == null) return null;
      if (shape.isVertical) return ReadingDirection.verticalScroll;
      return _horizontal(ref.watch(heldLibraryTypeProvider(key.libraryId)));
    });

/// What the books this session has opened declared of themselves, by series
/// (#118).
///
/// Kavita hands a book's own CSS over with every page and discards both of
/// the conventional places a base direction is written — `PrepareFinalHtml`
/// keeps the classes off `<html>` and `<body>` and throws the elements away —
/// so the stylesheet is the only witness, and `parseBookDirection`
/// (`book_face.dart`) is what reads it. A page is where it arrives, so the
/// reader is what records it, exactly as it is what records the shape of a
/// chapter's pages.
///
/// Recorded against the **series** rather than the chapter it was read on,
/// for the reason ADR-0007 already gives: a direction read off one chapter of
/// a work is a direction for the work. An omnibus carrying one right-to-left
/// story would turn whole, which is the case that could argue for per-chapter
/// and is written up on #118 rather than guessed at here.
///
/// A record of a reading and not a preference, like [pageShapesProvider]:
/// nothing is written to the device, a series is read again when it is opened
/// again, and the container it lives in is rebuilt for every profile.
final declaredDirectionsProvider =
    NotifierProvider<DeclaredDirectionsNotifier, Map<int, ReadingDirection>>(
      DeclaredDirectionsNotifier.new,
    );

class DeclaredDirectionsNotifier extends Notifier<Map<int, ReadingDirection>> {
  @override
  Map<int, ReadingDirection> build() => const {};

  /// Records what a page of [seriesId] declared.
  ///
  /// The only reading that reaches here today is right-to-left, because that
  /// is the only one `parseBookDirection` makes: a declared `ltr` cannot be
  /// told from a stylesheet that says nothing. It takes a whole
  /// [ReadingDirection] all the same, because that is the currency the chain
  /// is resolved in and the shape [pageShapesProvider]'s own record answers
  /// in — a set of series that declared one direction would be a shape of its
  /// own to unpick the moment a second reading is worth making.
  ///
  /// A record it already holds is left alone rather than written again: the
  /// reader records from a page landing, every page of a book carries the same
  /// stylesheet, and a new map on each of them would rebuild the chain — and
  /// the page set from it — once per page turn.
  void record(int seriesId, ReadingDirection direction) {
    if (state[seriesId] == direction) return;
    state = {...state, seriesId: direction};
  }
}

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
///
/// **No type is no answer, and not the answer for "not manga"** (#120). The
/// two are told apart here rather than upstream because this is the one place
/// that knows what a type is for: a shelf nobody has told the device about
/// witnesses nothing, and a rung with no witness stands down.
ReadingDirection? _horizontal(LibraryType? type) => switch (type) {
  null => null,
  LibraryType.manga => ReadingDirection.rightToLeft,
  _ => ReadingDirection.leftToRight,
};

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
        detected: ref.watch(detectedDirectionProvider(key)),
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
