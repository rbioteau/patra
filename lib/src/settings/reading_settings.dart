import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  static Future<ReadingDirection> load() async {
    try {
      final raw = await _storage.read(key: _key);
      return ReadingDirection.values.firstWhere(
        (d) => d.name == raw,
        orElse: () => _legacyNames[raw] ?? ReadingDirection.leftToRight,
      );
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

/// Preference restored before the app started; injected in main().
final initialReadingDirectionProvider = Provider<ReadingDirection>(
  (ref) => ReadingDirection.leftToRight,
);

/// The direction a newly opened chapter starts in. The reader can override it
/// for the current chapter without changing this.
class DefaultReadingDirectionNotifier extends Notifier<ReadingDirection> {
  @override
  ReadingDirection build() => ref.read(initialReadingDirectionProvider);

  Future<void> set(ReadingDirection direction) async {
    state = direction;
    await ReadingSettingsStore.save(direction);
  }
}

final defaultReadingDirectionProvider =
    NotifierProvider<DefaultReadingDirectionNotifier, ReadingDirection>(
      DefaultReadingDirectionNotifier.new,
    );

/// Preference restored before the app started; injected in main().
final initialMagnifyProvider = Provider<bool>((ref) => false);

/// Whether a one-finger drag magnifies the page instead of turning it.
///
/// Unlike the reading direction there is no per-chapter override: the
/// direction is a property of the book, this is a property of the hand.
class MagnifyNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(initialMagnifyProvider);

  Future<void> set(bool enabled) async {
    state = enabled;
    await ReadingSettingsStore.saveMagnify(enabled);
  }
}

final magnifyProvider = NotifierProvider<MagnifyNotifier, bool>(
  MagnifyNotifier.new,
);
