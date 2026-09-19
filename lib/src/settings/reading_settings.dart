import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../keychain.dart';
import '../theme.dart';

/// How pages advance in the reader. One setting, not a mode plus a direction:
/// vertical scrolling is a direction like the other two.
///
/// Kavita calls that third value `webtoon`, after the genre it was built for,
/// and has a *paged* vertical direction of its own we do not offer — which is
/// why the name here says scrolling rather than merely vertical.
enum ReadingDirection {
  leftToRight,
  rightToLeft,
  verticalScroll;

  bool get isVerticalScroll => this == ReadingDirection.verticalScroll;
  bool get isRightToLeft => this == ReadingDirection.rightToLeft;

  /// Full phrases only — never "LTR"/"RTL" in UI copy.
  String label(AppLocalizations l10n) => switch (this) {
    ReadingDirection.leftToRight => l10n.readingDirectionLtr,
    ReadingDirection.rightToLeft => l10n.readingDirectionRtl,
    ReadingDirection.verticalScroll => l10n.readingDirectionVerticalScroll,
  };
}

// How a book is set, and the range the three choices are offered over.
//
// They are **reading** settings of the person's — with a device default
// behind them like the others, and chosen in the reader's sheet (#75, #92)
// — so they are answered here rather than by the page that is set in them.
// The page is drawn at whatever these hold.

/// How a book's words are set: the family they are drawn in, and whether its
/// emphasis can be set in an italic.
///
/// A pair rather than a family alone because the two are one answer: a face
/// with no italic of its own must have its emphasis set in the roman rather
/// than in a slant the engine drew, and the face the reader chose is what
/// decides which of the two it is. See [ReadingFace.resolve], which is the
/// only place that decides it.
typedef BookType = ({String family, bool canSetItalic});

/// The face a book is set in: **the book's own**, one of the two the app
/// ships, or nothing at all.
///
/// Three choices and not four families, because the reader is choosing a
/// kind of type rather than a font: which family answers "the book's own"
/// is the book's business, and a name like `Literata` on a row says nothing
/// to somebody who does not already know what Literata looks like. The sheet
/// draws each row in the face it offers, which is the sample (see
/// `reader_settings_sheet.dart`).
///
/// **The book's own is the default**, which is what the server's own client
/// does: its font choice is a sentinel that resolves to CSS `inherit` and
/// leaves the book's stylesheet to win, and the faces it offers are an
/// override on top of that. A book whose stylesheet asks for nothing is set
/// in the app's sans, which is what it was set in before there was anything
/// to choose.
///
/// **The name is what is written down** — the persisted preference is a
/// string, as it is for [ReadingDirection] — so a value renamed here has to
/// keep its old name readable, or a device holding it falls back to
/// [defaultBookReadingFace] without saying anything. [_legacyNames] is that,
/// and [named] is what reads it back; what a name it does not know costs is
/// the default rather than the app.
///
/// Every family named here is **bundled** (`assets/fonts/`, one variable file
/// per family) and nothing is fetched, which is what lets a saved book (#77)
/// open in the face its reader chose with no server at all. The one face that
/// is not bundled is the book's own, and a copy carries it — see the reader's
/// rules.
enum ReadingFace {
  /// The face the book's own stylesheet asks for.
  book,

  /// The app's serif, which is also the face its titles and its page numerals
  /// are drawn in.
  serif,

  /// The app's sans, drawn for reading long and for low vision.
  sans;

  /// What a book is set in: this choice, and what the book asked for.
  ///
  /// [bookFamily] is the family the book's own stylesheet named, already
  /// registered with the engine, or null where the book asks for nothing or
  /// its font could not be had — in which case the app's sans stands in, the
  /// same face a book was set in before there was anything to choose. This is
  /// the only place the fallback is decided, so a page cannot disagree with
  /// the row that chose it.
  BookType resolve({String? bookFamily, bool bookItalic = false}) =>
      switch (this) {
        ReadingFace.book => bookFamily == null
            ? (family: fontAtkinsonHyperlegibleNext, canSetItalic: false)
            : (family: bookFamily, canSetItalic: bookItalic),
        ReadingFace.serif => (family: fontLiterata, canSetItalic: true),
        ReadingFace.sans => (
          family: fontAtkinsonHyperlegibleNext,
          canSetItalic: true,
        ),
      };

  /// What the row offering this is called.
  ///
  /// Not the family's name: a row says what kind of type it is, and the row
  /// itself is drawn in it, which is the only sample a reader needs. See
  /// [ReadingFace].
  String label(AppLocalizations l10n) => switch (this) {
    ReadingFace.book => l10n.readingFaceBook,
    ReadingFace.serif => l10n.readingFaceSerif,
    ReadingFace.sans => l10n.readingFaceSans,
  };

  /// The names this build no longer uses, and what they stand for.
  ///
  /// The preference used to be a family — `spaceGrotesk`, `sourceSerif4`,
  /// `literata`, `atkinsonHyperlegibleNext` — and every device that has one
  /// holds one of those strings. An unrecognised string falls back to the
  /// default silently, which is how a setting resets itself on somebody's
  /// device and says nothing, so each old name is read as the choice that
  /// stands closest to it: the two serifs are the serif, the app's sans and
  /// the face drawn for low vision are the sans. `save` writes the current
  /// name, so the old strings die out.
  static const _legacyNames = {
    'sourceSerif4': ReadingFace.serif,
    'literata': ReadingFace.serif,
    'spaceGrotesk': ReadingFace.sans,
    'atkinsonHyperlegibleNext': ReadingFace.sans,
  };

  /// What [name] names, reading the names of faces this build no longer
  /// offers too, or null for a name it does not know: the stored preference
  /// is a string the device wrote, so an unknown one costs the profile its
  /// face and never the app its page.
  static ReadingFace? named(String? name) {
    for (final face in values) {
      if (face.name == name) return face;
    }
    return _legacyNames[name];
  }
}

/// The size a book's words are set at, in points: one number for every book,
/// and the size every book was set at before there was anything to choose.
const double defaultBookTextSize = 16;

// The range the sheet offers it over, one point a step.
const double minBookTextSize = 14;
const double maxBookTextSize = 22;

/// The leading between a book's lines, as a share of the size of its words
/// — `1.55` is a line and a half, which is what dense prose asks for.
const double defaultBookLineHeight = 1.55;

// The range the sheet offers it over, in sixteen steps: narrow enough for a
// page of small print, and open enough to read with a finger under a line.
const double minBookLineHeight = 1.2;
const double maxBookLineHeight = 2.0;

/// The face every book is set in until somebody chooses another: **the book's
/// own**, which is what the server's own client does with its font choice
/// (see [ReadingFace]) and what makes a book look like the book it is.
///
/// A book whose stylesheet asks for nothing is set in the app's sans, which is
/// the face a book was set in before there was anything to choose — so the
/// change costs a reader whose books carry no font exactly nothing.
const ReadingFace defaultBookReadingFace = ReadingFace.book;

/// The **device's** reading defaults, under the flat keys they have always
/// been written to.
///
/// What a person chooses is theirs and lives in `profile_preferences.dart`;
/// this is what a profile that has never chosen starts from — which is what
/// makes a device set before it held profiles keep its settings for
/// everybody on it.
///
/// **The direction is not one of them any more** (#58): it used to be stored
/// here as the device's own default, and read as the rung behind a person's.
/// ADR-0007 removed both rungs — detection is per series, and a default held
/// for every series at once is the wrong shape for a direction — so the row
/// is written no more. A device that has one still parses: the key is simply
/// not read.
class ReadingSettingsStore {
  const ReadingSettingsStore(this._keychain);

  final Keychain _keychain;

  /// Deliberately still `loupeGesture`. The concept was called a loupe
  /// before the word was found to be wrong for it — a loupe is a lens over
  /// a region, and this magnifies the whole page — but the *string* is
  /// already written on every device that has turned the setting on, and a
  /// storage key renamed without a migration is how a setting silently
  /// resets itself, exactly as [_legacyNames] above exists to prevent.
  static const _magnifyKey = 'loupeGesture';

  /// Values the enum no longer names. `webtoon` is what vertical scrolling was
  /// called before the glossary settled on its own word, and the preference
  /// outlives the rename: an unrecognised string falls back to left-to-right,
  /// so without this the setting resets itself on the next launch and says
  /// nothing. `save` writes the current name, so the old string dies out.
  static const _legacyNames = {'webtoon': ReadingDirection.verticalScroll};

  /// The direction [name] stands for, reading the legacy names too, or null
  /// where it stands for none.
  ///
  /// Null rather than a default, because the two callers want different
  /// things from an unrecognised string: the device's own setting falls back
  /// to left-to-right, while a *profile's* falls back to the device's — and a
  /// lookup that had already chosen for them could not tell the difference.
  static ReadingDirection? directionNamed(String? name) {
    for (final direction in ReadingDirection.values) {
      if (direction.name == name) return direction;
    }
    return _legacyNames[name];
  }

  /// Off unless it was deliberately turned on: the gesture replaces the swipe
  /// that turns a page, and finding that out by accident is a bad first
  /// minute with the reader.
  Future<bool> loadMagnify() async {
    try {
      return await _keychain.read(_magnifyKey) == 'true';
    } on Exception {
      return false;
    }
  }

  Future<void> saveMagnify(bool enabled) async {
    try {
      await _keychain.write(_magnifyKey, enabled.toString());
    } on Exception {
      // As above.
    }
  }
}

/// The device's own reading defaults, on the device's keychain.
///
/// Stateless, so it is derived rather than injected: what a test stands in
/// for is [keychainProvider] and nothing here.
final readingSettingsProvider = Provider<ReadingSettingsStore>(
  (ref) => ReadingSettingsStore(ref.watch(keychainProvider)),
);
