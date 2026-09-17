library;
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../keychain.dart';
import 'locale_settings.dart';
import 'reading_settings.dart';

/// How many unread chapters to include in a batch download.
enum BatchDownloadSize {
  three(3),
  five(5),
  ten(10),
  twenty(20);

  const BatchDownloadSize(this.value);

  final int value;

  static const defaultSize = BatchDownloadSize.five;

  static BatchDownloadSize fromValue(int value) => switch (value) {
    3 => BatchDownloadSize.three,
    5 => BatchDownloadSize.five,
    10 => BatchDownloadSize.ten,
    20 => BatchDownloadSize.twenty,
    _ => defaultSize,
  };
}

/// Which settings follow the person and which stay with the device.
/// person**: they are how somebody reads, and two people sharing a tablet
/// each get their own.
/// So does the direction one **series** or one **library** is read in, which
/// is why it is kept here beside their other preferences rather than anywhere
/// the server could see it — see `features/reader/reading_direction.dart` for
/// the chain that those are the first two rungs of.
/// **The image cache budget belongs to the device**: it is disk, and the iPad
/// owns its disk — it lives
/// in `cache_settings.dart` and is handed to every container `SessionScope`
/// builds, alongside the downloads root and the locks.
///
/// Nothing here is sent to the server, deliberately. Kavita keeps preferences
/// of its own and none of them is the reading direction — syncing would cover
/// one setting of four and buy a conflict to resolve for something a tap
/// already fixes.
///
/// **The device keeps a default of each all the same**, and it is not a
/// duplicate of the person's: it is what a profile that has never chosen
/// starts from, and — for the language — what the gate is drawn in, since the
/// picker stands in front of every session and has nobody to ask. Those
/// defaults are the flat keys `ReadingSettingsStore` and `LocaleSettingsStore`
/// have always written, which is what makes this an upgrade nobody notices:
/// a device that was set before it held profiles keeps every setting it had,
/// a device that was set before it held profiles keeps every setting it had,
/// for everybody, until somebody chooses otherwise for themselves.

/// What one profile has chosen for itself. A null field is a choice never
/// made, and the device's own default stands in for it.
class ProfilePreferences {
  const ProfilePreferences({
    this.magnify,
    this.widthFactor,
    this.bookTextSize,
    this.bookLineHeight,
    this.bookReadingFace,
    this.language,
    this.batchDownloadSize,
    this.seriesDirections = const {},
    this.libraryDirections = const {},
  });

  static const none = ProfilePreferences();
  final ReadingFace? bookReadingFace;

  /// Whether a one-finger drag magnifies the page instead of turning it.
  final bool? magnify;

  /// How wide a chapter opens, as a fraction of the screen: `1.0` is the
  /// whole screen. Only the vertical direction lays its strip out at one.
  ///
  /// The range is `StripGeometry`'s to hold and not this file's — a
  /// preference and a pinch both set it, and they must not clamp it
  /// differently — so what is stored is whatever was asked for.
  final double? widthFactor;

  /// The size a book's words are set at, in points — a property of the
  /// person's eyes and not of the work, so it is one number for every book
  /// (#75) rather than one per series the way a direction is.
  final double? bookTextSize;

  /// The room between a book's lines, as a share of [bookTextSize]: the half
  /// of the same choice that decides whether dense text is readable.
  final double? bookLineHeight;

  /// How many unread chapters to include in a batch download. Offered as
  /// 3, 5, 10, or 20; default is 5.
  final BatchDownloadSize? batchDownloadSize;
  /// device", which is a choice a person can make and come back to. It is not
  /// the same as never having chosen: that is null, and the device's default
  /// stands. `MaterialApp` already reads a null `locale` as "resolve against
  /// the system", so the two readings of null had to be told apart somewhere,
  /// and here is where.
  final String? language;

  /// The direction each series is read in, keyed by series id: the first rung
  /// of the chain a chapter's direction is resolved through (ADR-0007).
  ///
  /// A choice about a work, kept with the person who made it — it is never
  /// sent to the server, which has no such preference, and it goes with the
  /// profile when the profile goes. A series nobody has set is simply absent,
  /// which is not the same as being set to what the default happens to hold:
  /// a series that is set stops following a default that later changes.
  final Map<int, ReadingDirection> seriesDirections;

  /// The direction each library is read in, keyed by library id: the second
  /// rung of the same chain, and what corrects a library the guess is wrong
  /// about wholesale (#65).
  ///
  /// A library is a set of works rather than one work, so it is the rung
  /// **under** the
  /// series' own and above everything a person chose for all of their
  /// reading — a library whose type is wrong is wrong for every series in it,
  /// and one tap here is what puts that right. Kept beside the series map it
  /// mirrors, for the same reasons and in the same row: a choice about works
  /// never sent to a server, gone with the profile that made it.
  final Map<int, ReadingDirection> libraryDirections;
  ProfilePreferences copyWith({
    bool? magnify,
    double? widthFactor,
    double? bookTextSize,
    double? bookLineHeight,
    ReadingFace? bookReadingFace,
    String? language,
    BatchDownloadSize? batchDownloadSize,
    Map<int, ReadingDirection>? seriesDirections,
    Map<int, ReadingDirection>? libraryDirections,
  }) => ProfilePreferences(
    magnify: magnify ?? this.magnify,
    widthFactor: widthFactor ?? this.widthFactor,
    bookTextSize: bookTextSize ?? this.bookTextSize,
    bookLineHeight: bookLineHeight ?? this.bookLineHeight,
    bookReadingFace: bookReadingFace ?? this.bookReadingFace,
    language: language ?? this.language,
    batchDownloadSize: batchDownloadSize ?? this.batchDownloadSize,
    seriesDirections: seriesDirections ?? this.seriesDirections,
    libraryDirections: libraryDirections ?? this.libraryDirections,
  );

  Map<String, dynamic> toJson() => {
    if (magnify != null) 'magnify': magnify,
    if (widthFactor != null) 'widthFactor': widthFactor,
    if (bookTextSize != null) 'bookTextSize': bookTextSize,
    if (bookLineHeight != null) 'bookLineHeight': bookLineHeight,
    if (bookReadingFace != null) 'bookReadingFace': bookReadingFace!.name,
    if (language != null) 'language': language,
    if (batchDownloadSize != null) 'batchDownloadSize': batchDownloadSize!.value,
    if (seriesDirections.isNotEmpty)
      'seriesDirections': _directionsJson(seriesDirections),
    if (libraryDirections.isNotEmpty)
      'libraryDirections': _directionsJson(libraryDirections),
  };

  /// Defensive like every other read from the keychain: this is loaded before
  /// `runApp`, so a row of the wrong shape must cost its profile a preference
  /// and never cost the device its app. Losing one is the safe direction —
  /// the person is then on the device's default and can choose again.
  static ProfilePreferences fromJson(Object? json) {
    if (json is! Map) return none;
    final magnify = json['magnify'];
    final widthFactor = json['widthFactor'];
    final bookTextSize = json['bookTextSize'];
    final bookLineHeight = json['bookLineHeight'];
    final bookReadingFace = json['bookReadingFace'];
    final language = json['language'];
    final batchDownloadSize = json['batchDownloadSize'];
    return ProfilePreferences(
      magnify: magnify is bool ? magnify : null,
      widthFactor: widthFactor is num ? widthFactor.toDouble() : null,
      bookTextSize: bookTextSize is num ? bookTextSize.toDouble() : null,
      bookLineHeight: bookLineHeight is num ? bookLineHeight.toDouble() : null,
      bookReadingFace: ReadingFace.named(
        bookReadingFace is String ? bookReadingFace : null,
      ),
      // A code this build no longer ships is not a choice it can honour, so
      // it reads as never having chosen and the device's default stands —
      // the same answer `supportedLocale` gives the device's own.
      language:
          language is String &&
              (language.isEmpty || supportedLocale(language) != null)
          ? language
          : null,
      batchDownloadSize:
          batchDownloadSize is int
              ? BatchDownloadSize.fromValue(batchDownloadSize)
              : null,
      seriesDirections: _directions(json['seriesDirections']),
      libraryDirections: _directions(json['libraryDirections']),
    );
  }

  /// One direction map as the wire carries it: the series' and the library's
  /// are the same shape, because the second was built to mirror the first.
  static Map<String, dynamic> _directionsJson(
    Map<int, ReadingDirection> directions,
  ) => {
    for (final entry in directions.entries) '${entry.key}': entry.value.name,
  };

  /// One entry at a time, and an entry of the wrong shape is dropped rather
  /// than thrown: what a malformed row costs is the series or the library it
  /// cannot read, never the profile its other choices or the device its app.
  static Map<int, ReadingDirection> _directions(Object? json) => json is! Map
      ? const {}
      : {
          for (final entry in json.entries)
            if (int.tryParse('${entry.key}') case final int id)
              if (entry.value case final String name)
                if (ReadingSettingsStore.directionNamed(name)
                    case final ReadingDirection direction)
                  id: direction,
        };
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
    this.deviceMagnify = false,
    this.deviceWidthFactor = 1.0,
    this.deviceBookTextSize = defaultBookTextSize,
    this.deviceBookLineHeight = defaultBookLineHeight,
    this.deviceBatchDownloadSize = BatchDownloadSize.defaultSize,
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

  final bool deviceMagnify;

  /// The width a chapter opens at for a profile that has never chosen: the
  /// whole screen, which is how a chapter has always opened.
  ///
  /// Frozen for the run like the two above and for the same reason nothing
  /// on any screen moves it — but unlike them there is **no flat key behind
  /// it**, because this device never held one: `1.0` is not a default a
  /// household chose once and has to keep, it is what the app did before
  /// there was anything to choose. It is a field and not a constant so that
  /// every preference here is answered the same way, and so a test can say
  /// what a person who has not chosen gets.
  final double deviceWidthFactor;

  /// How a book is set for a profile that has never chosen: the size and the
  /// leading a page of words is comfortable at, which is what every book was
  /// set at before there was anything to choose (#75).
  ///
  /// No flat key behind either, for the same reason the width has none: this
  /// device never held a text size, so there is no household choice to keep.
  final double deviceBookTextSize;
  final double deviceBookLineHeight;

  /// How many unread chapters to include in a batch download for a profile
  /// that has never chosen. Defaults to 5.
  final BatchDownloadSize deviceBatchDownloadSize;

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

  /// What [profileId] has chosen, or nothing at all — which is also the
  /// answer while nobody is reading, since the gate belongs to no profile.
  ProfilePreferences of(String? profileId) =>
      _byProfile[profileId] ?? ProfilePreferences.none;

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
  /// rung of the chain, and the only one a person can drop.
  ReadingDirection? seriesDirectionFor(String? profileId, int seriesId) =>
      of(profileId).seriesDirections[seriesId];

  bool magnifyFor(String? profileId) => of(profileId).magnify ?? deviceMagnify;

  /// The width a chapter opens at for [profileId], falling through to the
  /// device's default where they have never said.
  double widthFactorFor(String? profileId) =>
      of(profileId).widthFactor ?? deviceWidthFactor;

  /// The size [profileId]'s books are set at, falling through to the device's
  /// default where they have never said. One number for every book: this is a
  /// choice about a person's eyes, not about one work (#75).
  ///
  /// Clamped to the range the sheet offers, which is what keeps the page and
  /// the sheet from disagreeing: a row written by a build whose range was a
  /// wider one is answered with the nearest size this one can set, rather
  /// than with a page drawn at a number no slider can reach.
  double bookTextSizeFor(String? profileId) =>
      (of(profileId).bookTextSize ?? deviceBookTextSize).clamp(
        minBookTextSize,
        maxBookTextSize,
      );

  /// The room between the lines of [profileId]'s books, as a share of the
  /// size their words are set at.
  double bookLineHeightFor(String? profileId) =>
      (of(profileId).bookLineHeight ?? deviceBookLineHeight).clamp(
        minBookLineHeight,
        maxBookLineHeight,
      );

  /// The face [profileId]'s books are set in, falling through to the device's
  /// default where they have never chosen: the sans a book has been set in
  /// all along, so a profile that has never chosen one sees no difference
  /// (#92).
  ///
  /// There is nothing to clamp — the sheet offers exactly the faces there
  /// are, and a name this build does not know was already answered by
  /// [ReadingFace.named] on the way in.
  ReadingFace bookReadingFaceFor(String? profileId) =>
      of(profileId).bookReadingFace ?? defaultBookReadingFace;

  /// The language [profileId] reads in. The empty string is a choice — follow
  /// the device — and must not fall through to [deviceLanguage]; only never
  /// having chosen does.
  Locale? languageFor(String? profileId) {
    final chosen = of(profileId).language;
    return chosen == null ? deviceLanguage : supportedLocale(chosen);
  }
  /// How many unread chapters to include in a batch download for [profileId],
  /// falling through to the device's default where they have never said.
  BatchDownloadSize batchDownloadSizeFor(String? profileId) =>
      of(profileId).batchDownloadSize ?? deviceBatchDownloadSize;

  /// [size] is the batch download size from now on, for [profileId] alone.
  Future<void> setBatchDownloadSize(
    String profileId,
    BatchDownloadSize size,
  ) => _update(
    profileId,
    (was) => was.copyWith(batchDownloadSize: size),
  );

  /// [seriesId] is read in [direction] from now on, for [profileId] alone.
  ///
  /// The profile's own default is deliberately left where it is: setting one
  /// series is not setting every series, and promoting a choice to a default
  /// is a second tap the sheet offers rather than something this does behind
  /// somebody's back. The series map lives in the one row per profile, so
  /// `forget` takes it with everything else that profile chose.
  Future<void> setSeriesDirection(
    String profileId,
    int seriesId,
    ReadingDirection direction,
  ) => _update(
    profileId,
    (was) => was.copyWith(
      seriesDirections: {...was.seriesDirections, seriesId: direction},
    ),
  );

  /// [seriesId] goes back to following the default, for [profileId] alone.
  Future<void> clearSeriesDirection(String profileId, int seriesId) => _update(
    profileId,
    (was) => was.copyWith(
      seriesDirections: {...was.seriesDirections}..remove(seriesId),
    ),
  );

  /// What [profileId] has chosen for every series in [libraryId], if
  /// anything: the rung under one series' own choice and above everything
  /// they chose for all of their reading (#65).
  ReadingDirection? libraryDirectionFor(String? profileId, int libraryId) =>
      of(profileId).libraryDirections[libraryId];

  /// Every series in [libraryId] is read in [direction] from now on, for
  /// [profileId] alone — until a series says otherwise of its own.
  ///
  /// The profile's own default is left where it is for the reason setting one
  /// series does not move it: this is a choice about a library, and promoting
  /// it
  /// to everything they read is a different tap the sheet offers separately.
  Future<void> setLibraryDirection(
    String profileId,
    int libraryId,
    ReadingDirection direction,
  ) => _update(
    profileId,
    (was) => was.copyWith(
      libraryDirections: {...was.libraryDirections, libraryId: direction},
    ),
  );

  /// [libraryId] goes back to following what stands below it, for [profileId]
  /// alone.
  Future<void> clearLibraryDirection(String profileId, int libraryId) =>
      _update(
        profileId,
        (was) => was.copyWith(
          libraryDirections: {...was.libraryDirections}..remove(libraryId),
        ),
      );

  Future<void> setMagnify(String profileId, bool enabled) =>
      _update(profileId, (was) => was.copyWith(magnify: enabled));

  Future<void> setWidthFactor(String profileId, double factor) =>
      _update(profileId, (was) => was.copyWith(widthFactor: factor));

  /// Every book is set at [size] from now on, for [profileId] alone.
  Future<void> setBookTextSize(String profileId, double size) =>
      _update(profileId, (was) => was.copyWith(bookTextSize: size));

  /// Every book's lines are [height] apart from now on, as a share of the
  /// size of its words, for [profileId] alone.
  Future<void> setBookLineHeight(String profileId, double height) =>
      _update(profileId, (was) => was.copyWith(bookLineHeight: height));

  /// Every book is set in [face] from now on, for [profileId] alone.
  Future<void> setBookReadingFace(String profileId, ReadingFace face) =>
      _update(profileId, (was) => was.copyWith(bookReadingFace: face));

  /// [locale] null is a real choice — follow the device — and is stored as
  /// one, which is why it cannot go through [ProfilePreferences.copyWith].
  ///
  /// Which is also why it is the one write that names every field: a field
  /// left out of this constructor is a preference silently dropped by the
  /// next change of language, so **a field added to [ProfilePreferences] has
  /// to be added here too**.
  Future<void> setLanguage(String profileId, Locale? locale) => _update(
    profileId,
    (was) => ProfilePreferences(
      magnify: was.magnify,
      widthFactor: was.widthFactor,
      bookTextSize: was.bookTextSize,
      bookLineHeight: was.bookLineHeight,
      bookReadingFace: was.bookReadingFace,
      language: locale?.languageCode ?? '',
      seriesDirections: was.seriesDirections,
      libraryDirections: was.libraryDirections,
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
/// has no business being recomputed because a token moved. Measured: one
/// rebuild per notifier per renewal without the `select`, none with it.
/// Nothing
/// is *lost* by the rebuild (the store is updated in memory before it is
/// persisted, so it answers with the new value either way), which is exactly
/// why this has to be pinned by counting rather than by a symptom — there
/// is no symptom until somebody adds one.
/// [Profile.id] of whoever is reading, or null at the gate.
///
/// Public because the chain a chapter's direction is resolved through lives
/// with the reader (`features/reader/reading_direction.dart`) and is a
/// function of the same thing every preference here is.
final readingProfileIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider.select((s) => s?.id)),
);

/// One map of directions a person holds — one direction per series, or one
/// per library — written through to the store under whoever is reading.
///
/// The two rungs are the same shape all the way down: a map of id to
/// direction in the one keychain row, replaced whole on every change, keyed on
/// the work or on the library. So what writes them is one thing too, because a
/// rule about how a direction is remembered — who it belongs to, what happens
/// with nobody reading — is a rule both of them have to keep, and stated twice
/// it is a rule one of them will lose.
///
/// What each map *is*, and which rung of the chain it is, stays with the two
/// notifiers below, since that is the part that differs.
abstract class DirectionMapNotifier
    extends Notifier<Map<int, ReadingDirection>> {
  /// The map [preferences] holds for this rung.
  Map<int, ReadingDirection> held(ProfilePreferences preferences);

  /// Writes [direction] for [id], for [profileId] alone.
  Future<void> write(String profileId, int id, ReadingDirection direction);

  /// Drops whatever [profileId] holds for [id].
  Future<void> drop(String profileId, int id);

  @override
  Map<int, ReadingDirection> build() => held(
    ref
        .read(profilePreferencesStoreProvider)
        .of(ref.watch(readingProfileIdProvider)),
  );

  /// [id] — a series or a library — is read in [direction] from now on, for
  /// whoever is reading.
  Future<void> set(int id, ReadingDirection direction) async {
    state = {...state, id: direction};
    final profileId = ref.read(sessionProvider)?.id;
    if (profileId == null) {
      // Nobody is reading, so there is nobody this could belong to: unlike a
      // profile's own default there is no flat key of the device's it could
      // fall back to, since this is a map, and one written under nobody's id
      // would come back to whoever next reads here. What is left is the
      // chapter in hand keeping the direction it was given for as long as it
      // is open, and the store never hearing of it — which no screen ever
      // sees, because the reader stands inside a session.
      return;
    }
    await write(profileId, id, direction);
  }

  /// [id] goes back to following what stands below it.
  Future<void> clear(int id) async {
    if (!state.containsKey(id)) return;
    state = {...state}..remove(id);
    final profileId = ref.read(sessionProvider)?.id;
    if (profileId == null) return;
    await drop(profileId, id);
  }
}

/// The direction each series is read in, for whoever is reading: ADR-0007's
/// first rung, and the only one a screen can set for one work at a time.
///
/// One map and not a provider per series, because what is stored is one map
/// in one keychain row and what a screen asks for is one series at a time —
/// and because a series nobody has set is simply absent from it, which is not
/// the same as being set to whatever the default happens to hold.
class SeriesDirectionsNotifier extends DirectionMapNotifier {
  @override
  Map<int, ReadingDirection> held(ProfilePreferences preferences) =>
      preferences.seriesDirections;

  @override
  Future<void> write(
    String profileId,
    int seriesId,
    ReadingDirection direction,
  ) => ref
      .read(profilePreferencesStoreProvider)
      .setSeriesDirection(profileId, seriesId, direction);

  @override
  Future<void> drop(String profileId, int seriesId) => ref
      .read(profilePreferencesStoreProvider)
      .clearSeriesDirection(profileId, seriesId);
}

final seriesDirectionsProvider =
    NotifierProvider<SeriesDirectionsNotifier, Map<int, ReadingDirection>>(
      SeriesDirectionsNotifier.new,
    );

/// The direction each library is read in, for whoever is reading: #65's rung,
/// under one series' own choice and above everything a person chose for all of
/// their reading, and the one that answers a library the detected direction is
/// wrong about **wholesale** — a library shelved as manga holding manhua is
/// wrong for every series in it, and the profile's own default is the wrong
/// shape to correct that, since it is a choice about a person's reading rather
/// than about one library.
///
/// One map in the one keychain row, like the series' beside it: a library
/// nobody has set is absent from it, which is not the same as being set to
/// whatever stands below it happens to hold.
class LibraryDirectionsNotifier extends DirectionMapNotifier {
  @override
  Map<int, ReadingDirection> held(ProfilePreferences preferences) =>
      preferences.libraryDirections;

  @override
  Future<void> write(
    String profileId,
    int libraryId,
    ReadingDirection direction,
  ) => ref
      .read(profilePreferencesStoreProvider)
      .setLibraryDirection(profileId, libraryId, direction);

  @override
  Future<void> drop(String profileId, int libraryId) => ref
      .read(profilePreferencesStoreProvider)
      .clearLibraryDirection(profileId, libraryId);
}

final libraryDirectionsProvider =
    NotifierProvider<LibraryDirectionsNotifier, Map<int, ReadingDirection>>(
      LibraryDirectionsNotifier.new,
    );

/// Whether a one-finger drag magnifies the page instead of turning it.
///
/// Unlike the reading direction there is no per-chapter override: the
/// direction is a property of the book, this is a property of the hand — and
/// hands are what this file is about, so it follows the person too.
class MagnifyNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(profilePreferencesStoreProvider).magnifyFor(ref.watch(readingProfileIdProvider));

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

/// How wide a chapter opens for whoever is reading: a fraction of the screen,
/// `1.0` being the whole of it — which is how a chapter has opened all along,
/// and so the one value that changes nothing for somebody who never chooses.
///
/// Only the vertical direction lays a strip out at one; where it does not
/// apply the row says so and stays settable, for the reason magnifying's
/// does. What writes it is a choice — the reader's own sheet or Settings —
/// and never reading: the pinch that narrows the strip for one chapter is a
/// live adjustment on top of this and leaves it where it was (#50).
class WidthFactorNotifier extends Notifier<double> {
  @override
  double build() =>
      ref.read(profilePreferencesStoreProvider).widthFactorFor(ref.watch(readingProfileIdProvider));

  /// The width while a finger is still on the slider: what the chapter in
  /// front of the reader is drawn at, but not yet a choice.
  ///
  /// A slider reports every step of a drag and a drag is dozens of steps, so
  /// persisting each one would be dozens of whole-map writes to the keychain
  /// for values nobody has settled on. [set] is the one that writes, from the
  /// end of the gesture. It is the same two things the pinch will keep apart
  /// (#50): the number a chapter is being drawn at, and the number a person
  /// has chosen.
  void preview(double factor) => state = factor;

  Future<void> set(double factor) async {
    state = factor;
    final id = ref.read(sessionProvider)?.id;
    if (id == null) {
      // Nobody is reading, so there is nobody this could belong to. Unlike
      // the direction and magnifying there is no flat key of the device's
      // to fall back to either, since `1.0` is not a default this device
      // ever chose — see [ProfilePreferencesStore.deviceWidthFactor]. No
      // screen reaches this: Settings stands inside a session, and the gate
      // has no width to set.
      return;
    }
    await ref.read(profilePreferencesStoreProvider).setWidthFactor(id, factor);
  }
}

final widthFactorProvider = NotifierProvider<WidthFactorNotifier, double>(
  WidthFactorNotifier.new,
);

/// The language the app is shown in. Null follows the device.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() =>
      ref.read(profilePreferencesStoreProvider).languageFor(ref.watch(readingProfileIdProvider));

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

/// How large the words of a book are set for whoever is reading, in points.
///
/// One number for **every** book, and a number of the person's rather than of
/// the work's: what is being chosen is the size somebody reads at, and
/// setting it once is the whole point (#75). Of the profile, with the
/// device's default behind it, like every preference here.
class BookTextSizeNotifier extends Notifier<double> {
  @override
  double build() => ref
      .read(profilePreferencesStoreProvider)
      .bookTextSizeFor(ref.watch(readingProfileIdProvider));

  /// The size while a finger is still on the slider: what the page in front
  /// of the reader is set at, but not yet a choice — see
  /// [WidthFactorNotifier.preview], whose reason is this one's too.
  void preview(double size) => state = size;

  Future<void> set(double size) async {
    state = size;
    final id = ref.read(sessionProvider)?.id;
    if (id == null) return;
    await ref.read(profilePreferencesStoreProvider).setBookTextSize(id, size);
  }
}

final bookTextSizeProvider = NotifierProvider<BookTextSizeNotifier, double>(
  BookTextSizeNotifier.new,
);

/// The room between a book's lines for whoever is reading, as a share of the
/// size of its words: the half of the same choice that decides whether dense
/// text is readable.
class BookLineHeightNotifier extends Notifier<double> {
  @override
  double build() => ref
      .read(profilePreferencesStoreProvider)
      .bookLineHeightFor(ref.watch(readingProfileIdProvider));

  void preview(double height) => state = height;

  Future<void> set(double height) async {
    state = height;
    final id = ref.read(sessionProvider)?.id;
    if (id == null) return;
    await ref
        .read(profilePreferencesStoreProvider)
        .setBookLineHeight(id, height);
  }
}

final bookLineHeightProvider = NotifierProvider<BookLineHeightNotifier, double>(
  BookLineHeightNotifier.new,
);

/// The face a book is set in for whoever is reading: one of the four the app
/// ships, and one for **every** book (#92).
///
/// A choice is a whole one, so there is no [preview] beside it the way there
/// is for a size or a leading — nothing drags a face along a scale and lets
/// go. The page is redrawn in it the moment it is picked, and the place the
/// reader holds in the page is carried across the reflow by the page itself.
class BookReadingFaceNotifier extends Notifier<ReadingFace> {
  @override
  ReadingFace build() => ref
      .read(profilePreferencesStoreProvider)
      .bookReadingFaceFor(ref.watch(readingProfileIdProvider));

  Future<void> set(ReadingFace face) async {
    state = face;
    final id = ref.read(sessionProvider)?.id;
    if (id == null) return;
    await ref
        .read(profilePreferencesStoreProvider)
        .setBookReadingFace(id, face);
  }
}
final bookReadingFaceProvider =
    NotifierProvider<BookReadingFaceNotifier, ReadingFace>(
      BookReadingFaceNotifier.new,
    );

/// How many unread chapters to include in a batch download, for whoever is
/// reading. Offered as 3, 5, 10, or 20; default is 5.
class BatchDownloadSizeNotifier extends Notifier<BatchDownloadSize> {
  @override
  BatchDownloadSize build() => ref
      .read(profilePreferencesStoreProvider)
      .batchDownloadSizeFor(ref.watch(readingProfileIdProvider));

  Future<void> set(BatchDownloadSize size) async {
    state = size;
    final id = ref.read(sessionProvider)?.id;
    if (id == null) return;
    await ref
        .read(profilePreferencesStoreProvider)
        .setBatchDownloadSize(id, size);
  }
}

final batchDownloadSizeProvider =
    NotifierProvider<BatchDownloadSizeNotifier, BatchDownloadSize>(
      BatchDownloadSizeNotifier.new,
    );
