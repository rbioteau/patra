import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/generated/app_localizations.dart';

/// How pages advance in the reader. One setting, not a mode plus a direction:
/// webtoon is a direction like the other two.
enum ReadingDirection {
  leftToRight,
  rightToLeft,
  webtoon;

  bool get isWebtoon => this == ReadingDirection.webtoon;
  bool get isRightToLeft => this == ReadingDirection.rightToLeft;

  /// Full phrases only — never "LTR"/"RTL" in UI copy.
  String label(AppLocalizations l10n) => switch (this) {
    ReadingDirection.leftToRight => l10n.readingDirectionLtr,
    ReadingDirection.rightToLeft => l10n.readingDirectionRtl,
    ReadingDirection.webtoon => l10n.readingModeWebtoon,
  };
}

class ReadingSettingsStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'readingDirection';

  static Future<ReadingDirection> load() async {
    try {
      final raw = await _storage.read(key: _key);
      return ReadingDirection.values.firstWhere(
        (d) => d.name == raw,
        orElse: () => ReadingDirection.leftToRight,
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
