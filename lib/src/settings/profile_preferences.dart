/// Which settings follow the person and which stay with the device.
///
/// A family tablet is several profiles at one address (ADR-0003), and a
/// setting is one of two kinds. **Reading direction, magnifying and the
/// interface language belong to a person**: they are how somebody reads, and
/// two people sharing a tablet each get their own. **The image cache budget
/// belongs to the device**: it is disk, and the iPad owns its disk — it lives
/// in `cache_settings.dart` and is handed to every container `SessionScope`
/// builds, alongside the downloads root and the locks.
///
/// Nothing here is sent to the server, deliberately. Kavita keeps preferences
/// of its own and none of them is the reading direction — syncing would cover
/// one setting of three and buy a conflict to resolve for something a tap
/// already fixes.
///
/// **The device keeps a default of each all the same**, and it is not a
/// duplicate of the person's: it is what a profile that has never chosen
/// starts from, and — for the language — what the gate is drawn in, since the
/// picker stands in front of every session and has nobody to ask. Those
/// defaults are the flat keys `ReadingSettingsStore` and `LocaleSettingsStore`
/// have always written, which is what makes this an upgrade nobody notices:
/// a device that was set before it held profiles keeps every setting it had,
/// for everybody, until somebody chooses otherwise for themselves.
library;

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../keychain.dart';
import 'locale_settings.dart';
import 'reading_settings.dart';

/// What one profile has chosen for itself. A null field is a choice never
/// made, and the device's own default stands in for it.
class ProfilePreferences {
  const ProfilePreferences({this.direction, this.magnify, this.language});

  static const none = ProfilePreferences();

  final ReadingDirection? direction;
  final bool? magnify;

  /// The language chosen, as a code — or the **empty string** for "follow the
  /// device", which is a choice a person can make and come back to. It is not
  /// the same as never having chosen: that is null, and the device's default
  /// stands. `MaterialApp` already reads a null `locale` as "resolve against
  /// the system", so the two readings of null had to be told apart somewhere,
  /// and here is where.
  final String? language;

  ProfilePreferences copyWith({
    ReadingDirection? direction,
    bool? magnify,
    String? language,
  }) => ProfilePreferences(
    direction: direction ?? this.direction,
    magnify: magnify ?? this.magnify,
    language: language ?? this.language,
  );

  Map<String, dynamic> toJson() => {
    if (direction != null) 'direction': direction!.name,
    if (magnify != null) 'magnify': magnify,
    if (language != null) 'language': language,
  };

  /// Defensive like every other read from the keychain: this is loaded before
  /// `runApp`, so a row of the wrong shape must cost its profile a preference
  /// and never cost the device its app. Losing one is the safe direction —
  /// the person is then on the device's default and can choose again.
  static ProfilePreferences fromJson(Object? json) {
    if (json is! Map) return none;
    final direction = json['direction'];
    final magnify = json['magnify'];
    final language = json['language'];
    return ProfilePreferences(
      direction: direction is String
          ? ReadingSettingsStore.directionNamed(direction)
          : null,
      magnify: magnify is bool ? magnify : null,
      // A code this build no longer ships is not a choice it can honour, so
      // it reads as never having chosen and the device's default stands —
      // the same answer `supportedLocale` gives the device's own.
      language:
          language is String &&
              (language.isEmpty || supportedLocale(language) != null)
          ? language
          : null,
    );
  }
}

/// Every preference this device holds for a person, keyed by [Profile.id],
/// plus the device's own defaults behind them.
///
/// Loaded once, before `runApp`, and kept in memory afterwards — so this
/// instance is the one the app reads. It is injected the way the lock store
/// and the image cache store are, because it belongs to the **device**: it
/// has to survive a handover building the app again on a container of its
/// own, or the person arriving would be handed the defaults instead of what
/// they chose last time.
class ProfilePreferencesStore {
  ProfilePreferencesStore({
    Keychain? keychain,
    this.deviceDirection = ReadingDirection.leftToRight,
    this.deviceMagnify = false,
    Locale? deviceLanguage,
    // A private field cannot be a named parameter, so the lint's suggestion
    // is not available here.
    // ignore: prefer_initializing_formals
  }) : _deviceLanguage = deviceLanguage,
       _keychain = keychain ?? const SecureKeychain();

  final Keychain _keychain;

  /// One row rather than a key per profile, because the whole map is read at
  /// once before the app starts and written whole on every change.
  static const _key = 'profilePreferences';

  /// What a profile that has never chosen reads in, and what the reader opens
  /// in for them. Read from the flat keys before `runApp` and handed in
  /// there; frozen for the run, because nothing on any screen sets a device
  /// default for these two — a person's choice is their own.
  final ReadingDirection deviceDirection;
  final bool deviceMagnify;

  /// The language of the **gate**, which is drawn before anybody has been
  /// chosen and so cannot ask a profile.
  ///
  /// It moves, unlike the two above, because it is the one preference with a
  /// surface outside a session and no screen of its own to be set on: the
  /// last language anybody chose here is the only evidence there is of what
  /// this household reads in. [rememberDeviceLanguage] is the only way to
  /// move it, and that is the point — the value in hand and the value in the
  /// keychain are two halves of one fact, and a field anybody could assign
  /// is a fact half of the app could be wrong about.
  Locale? get deviceLanguage => _deviceLanguage;
  Locale? _deviceLanguage;

  /// Makes [locale] what this device falls back to, in memory and in the
  /// keychain, which are the same decision and so are one call.
  /// [device] is handed in rather than held: this store is built in `main()`
  /// before there is a container, and the row it writes here is the
  /// *device's* own — so the caller, which is a notifier and has a keychain
  /// in reach, is where that store comes from.
  Future<void> rememberDeviceLanguage(
    Locale? locale,
    LocaleSettingsStore device,
  ) async {
    _deviceLanguage = locale;
    await device.save(locale);
  }

  Map<String, ProfilePreferences> _byProfile = const {};

  /// What has been chosen, per profile. Empty until [load], which is what a
  /// test that never calls it gets.
  Map<String, ProfilePreferences> get byProfile => Map.unmodifiable(_byProfile);

  Future<Map<String, ProfilePreferences>> load() async {
    final String? raw;
    try {
      raw = await _keychain.read(_key);
    } on Exception {
      // A keychain that cannot be read is a device on its defaults, not a
      // device that cannot start — same rule as `SessionStorage.load`.
      return byProfile;
    }
    if (raw == null) return byProfile;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return byProfile;
      _byProfile = {
        for (final entry in decoded.entries)
          '${entry.key}': ProfilePreferences.fromJson(entry.value),
      };
    } on FormatException {
      // Unreadable is unset, as above.
    }
    return byProfile;
  }

  /// What [profileId] has chosen, or nothing at all — which is also the
  /// answer while nobody is reading, since the gate belongs to no profile.
  ProfilePreferences of(String? profileId) =>
      _byProfile[profileId] ?? ProfilePreferences.none;

  /// The direction a chapter opens in for [profileId], falling through to the
  /// device's default where they have never said.
  ReadingDirection directionFor(String? profileId) =>
      of(profileId).direction ?? deviceDirection;

  bool magnifyFor(String? profileId) => of(profileId).magnify ?? deviceMagnify;

  /// The language [profileId] reads in. The empty string is a choice — follow
  /// the device — and must not fall through to [deviceLanguage]; only never
  /// having chosen does.
  Locale? languageFor(String? profileId) {
    final chosen = of(profileId).language;
    return chosen == null ? deviceLanguage : supportedLocale(chosen);
  }

  Future<void> setDirection(String profileId, ReadingDirection direction) =>
      _update(profileId, (was) => was.copyWith(direction: direction));

  Future<void> setMagnify(String profileId, bool enabled) =>
      _update(profileId, (was) => was.copyWith(magnify: enabled));

  /// [locale] null is a real choice — follow the device — and is stored as
  /// one, which is why it cannot go through [ProfilePreferences.copyWith].
  Future<void> setLanguage(String profileId, Locale? locale) => _update(
    profileId,
    (was) => ProfilePreferences(
      direction: was.direction,
      magnify: was.magnify,
      language: locale?.languageCode ?? '',
    ),
  );

  /// Takes [profileId]'s preferences with it. What removing a profile has to
  /// do, for the reason its lock is cleared there too: a row left behind
  /// points at nobody, and would come back to somebody who signs in again
  /// under the same id expecting a device they have never used.
  Future<void> forget(String profileId) async {
    if (!_byProfile.containsKey(profileId)) return;
    _byProfile = {
      for (final entry in _byProfile.entries)
        if (entry.key != profileId) entry.key: entry.value,
    };
    await _flush();
  }

  Future<void> _update(
    String profileId,
    ProfilePreferences Function(ProfilePreferences) change,
  ) async {
    _byProfile = {..._byProfile, profileId: change(of(profileId))};
    await _flush();
  }

  /// An empty map is **no row**, not a row holding `{}`.
  ///
  /// Failures are swallowed here rather than in the keychain, which is where
  /// that decision belongs: the choice is still in memory for this run and
  /// the next change tries again.
  Future<void> _flush() async {
    try {
      if (_byProfile.isEmpty) {
        await _keychain.delete(_key);
        return;
      }
      await _keychain.write(
        _key,
        jsonEncode({
          for (final entry in _byProfile.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    } on Exception {
      // As above.
    }
  }
}

/// The store, built before `runApp` and injected there. The default is an
/// unloaded one on the built-in defaults, which is what a test gets.
final profilePreferencesStoreProvider = Provider<ProfilePreferencesStore>(
  (ref) => ProfilePreferencesStore(),
);

/// [Profile.id] of whoever is reading, or null at the gate.
///
/// Every preference below is a function of it, so entering somebody else is
/// what makes their settings the ones in force — including the first profile
/// entered in a container, which `SessionScope` deliberately does not rebuild
/// the app for.
///
/// The **id** and not the session, which is the same care
/// `kavitaClientProvider` takes for the same reason: `Profile` has no `==`,
/// so a session is a new instance on every JWT renewal — and a preference
/// has no business being recomputed because a token moved. Measured: three
/// notifiers rebuilt per renewal without the `select`, none with it. Nothing
/// is *lost* by the rebuild (the store is updated in memory before it is
/// persisted, so it answers with the new value either way), which is exactly
/// why this has to be pinned by counting rather than by a symptom — there
/// is no symptom until somebody adds one.
String? _readerId(Ref ref) => ref.watch(sessionProvider.select((s) => s?.id));

/// The direction a newly opened chapter starts in, for whoever is reading.
/// The reader can override it for the current chapter without changing this.
class DefaultReadingDirectionNotifier extends Notifier<ReadingDirection> {
  @override
  ReadingDirection build() =>
      ref.read(profilePreferencesStoreProvider).directionFor(_readerId(ref));

  Future<void> set(ReadingDirection direction) async {
    state = direction;
    final id = ref.read(sessionProvider)?.id;
    if (id == null) {
      // Nobody is reading, so there is nobody for this to belong to but the
      // device. No screen reaches it — Settings is inside a session — and it
      // is written down all the same, because the alternative is a `set` that
      // silently keeps nothing.
      await ref.read(readingSettingsProvider).save(direction);
      return;
    }
    await ref.read(profilePreferencesStoreProvider).setDirection(id, direction);
  }
}

final defaultReadingDirectionProvider =
    NotifierProvider<DefaultReadingDirectionNotifier, ReadingDirection>(
      DefaultReadingDirectionNotifier.new,
    );

/// Whether a one-finger drag magnifies the page instead of turning it.
///
/// Unlike the reading direction there is no per-chapter override: the
/// direction is a property of the book, this is a property of the hand — and
/// hands are what this file is about, so it follows the person too.
class MagnifyNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(profilePreferencesStoreProvider).magnifyFor(_readerId(ref));

  Future<void> set(bool enabled) async {
    state = enabled;
    final id = ref.read(sessionProvider)?.id;
    if (id == null) {
      await ref.read(readingSettingsProvider).saveMagnify(enabled);
      return;
    }
    await ref.read(profilePreferencesStoreProvider).setMagnify(id, enabled);
  }
}

final magnifyProvider = NotifierProvider<MagnifyNotifier, bool>(
  MagnifyNotifier.new,
);

/// The language the app is shown in. Null follows the device.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() =>
      ref.read(profilePreferencesStoreProvider).languageFor(_readerId(ref));

  /// Writes the choice **twice**, and that is the one asymmetry in this file.
  ///
  /// A language is a person's, like the other two — and it is also the only
  /// preference read where there is no person: the picker and the sign-in
  /// form are drawn before anybody has been chosen. There is no screen on
  /// which to set the gate's language, and there should not be one, so the
  /// last language anybody chose on this device is what it is drawn in. That
  /// costs the household nothing and is the only available evidence of what
  /// they read in; a profile that has since chosen for itself is unaffected,
  /// because its own choice is looked up first.
  Future<void> set(Locale? locale) async {
    state = locale;
    final store = ref.read(profilePreferencesStoreProvider);
    await store.rememberDeviceLanguage(
      locale,
      ref.read(localeSettingsProvider),
    );
    final id = ref.read(sessionProvider)?.id;
    if (id != null) await store.setLanguage(id, locale);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
