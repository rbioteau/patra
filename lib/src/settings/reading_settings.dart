import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/generated/app_localizations.dart';

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

/// The **device's** reading defaults, under the flat keys they have always
/// been written to.
///
/// What a person chooses is theirs and lives in `profile_preferences.dart`;
/// this is what a profile that has never chosen starts from — which is what
/// makes a device set before it held profiles keep its settings for
/// everybody on it.
class ReadingSettingsStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'readingDirection';

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

  static Future<ReadingDirection> load() async {
    try {
      return directionNamed(await _storage.read(key: _key)) ??
          ReadingDirection.leftToRight;
    } on Exception {
      return ReadingDirection.leftToRight;
    }
  }

  static Future<void> save(ReadingDirection direction) async {
    try {
      await _storage.write(key: _key, value: direction.name);
    } on Exception {
      // A preference is not worth surfacing a storage failure for.
    }
  }

  /// Off unless it was deliberately turned on: the gesture replaces the swipe
  /// that turns a page, and finding that out by accident is a bad first
  /// minute with the reader.
  static Future<bool> loadMagnify() async {
    try {
      return await _storage.read(key: _magnifyKey) == 'true';
    } on Exception {
      return false;
    }
  }

  static Future<void> saveMagnify(bool enabled) async {
    try {
      await _storage.write(key: _magnifyKey, value: enabled.toString());
    } on Exception {
      // As above.
    }
  }
}
