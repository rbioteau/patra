import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../keychain.dart';

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

// How a book is set, and the range the two choices are offered over.
//
// They are **reading** settings of the person's — with a device default
// behind them like the others, and chosen in the reader's sheet (#75) — so
// they are answered here rather than by the page that is set in them. The
// page is drawn at whatever number these hold.

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
