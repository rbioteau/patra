import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/catalogue/catalogue_provider.dart';
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/keychain.dart';
import 'package:patra/src/lock/biometrics.dart';
import 'package:patra/src/lock/profile_lock.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';

/// Points path_provider at a temp directory for the duration of a test.
///
/// Widget tests that render covers pull in cached_network_image, whose cache
/// manager asks for the temporary directory; without a handler the channel
/// throws MissingPluginException asynchronously and fails the test at a
/// random moment.
Directory mockPathProvider() {
  final dir = Directory.systemTemp.createTempSync('patra-test');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => dir.path);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// The device's keychain, standing in for the real one: one map, and a test
/// can read back exactly what was written.
///
/// This replaces a mock of `flutter_secure_storage`'s **method channel**,
/// which fourteen suites used to carry. On a test binding that plugin has no
/// platform behind it — on Linux it reaches for libsecret through the desktop
/// implementation and simply never answers, so a `write` **hung** the test
/// rather than failing it, which reads as a stuck suite rather than a missing
/// stand-in. Nothing reaches the channel now: every store here takes a
/// [Keychain].
class MemoryKeychain implements Keychain {
  MemoryKeychain([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  /// So a test can tell "written once" from "written on every build".
  int writes = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<Map<String, String>> readAll() async => {...values};

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// A keychain in the tree, for a test that reaches one through a provider
/// rather than building a store itself.
///
/// The same move as [testCatalogue], and the only override needed: the four
/// stateless stores are derived from [keychainProvider], so standing in for
/// it stands in for all of them. Pass a [MemoryKeychain] where the test wants
/// to seed a row or read one back.
Override testKeychain([MemoryKeychain? keychain]) =>
    keychainProvider.overrideWithValue(keychain ?? MemoryKeychain());

/// A token Kavita could have signed for [accountId], which is what the app
/// reads its own account id back out of (`accountIdFrom`, the `nameid`
/// claim).
///
/// Shared because a stub that answers a sign-in with anything else makes a
/// *second* profile of the person who just signed in: `Profile.id` falls back
/// to the username when no id can be read, so the row the device already
/// held is not the row the sign-in resolves onto.
///
/// Nothing verifies the signature — the app deliberately does not either —
/// so the third segment is a word. `test/account_id_test.dart` builds its own
/// tokens rather than using this: what it tests is the reading of odd ones.
String signedToken(int accountId, {String signature = 'signature'}) {
  String segment(Object claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  return '${segment({'alg': 'HS512'})}.'
      '${segment({'nameid': '$accountId'})}.$signature';
}

/// A chapter already on disk under [profileId]'s store, written the way a
/// finished download is: page files first, `meta.json` last.
///
/// Shared because every fixture here has to go **through the service**. A
/// chapter directory written straight into the downloads root is what the
/// previous, profile-less layout wrote, and `scan` now deletes those rather
/// than listing them — so a hand-built path does not merely file the chapter
/// somewhere odd, it makes the test that reads it back quietly vacuous.
Future<SavedChapter> saveChapterFixture(
  Directory root,
  String profileId, {
  required int chapterId,
  String seriesName = 'Blame!',
  String title = 'Chapter 1',
  int pages = 1,
  int bytes = 3,
  int pagesRead = 0,
  int seriesId = 5,
  int volumeId = 1,
  int libraryId = 1,
}) async {
  final chapter = SavedChapter(
    chapterId: chapterId,
    seriesId: seriesId,
    volumeId: volumeId,
    libraryId: libraryId,
    seriesName: seriesName,
    title: title,
    pages: pages,
    bytes: bytes,
    pagesRead: pagesRead,
  );
  final dir = (await DownloadsService(
    root: root,
    profileId: profileId,
  ).chapterDir(chapterId))..createSync(recursive: true);
  for (var page = 0; page < pages; page++) {
    File('${dir.path}/${DownloadsService.pageFileName(page)}')
        .writeAsBytesSync(const [0]);
  }
  File('${dir.path}/meta.json').writeAsStringSync(jsonEncode(chapter.toJson()));
  return chapter;
}

/// The lock module's platform dependency, standing in for the keychain: one
/// value in, one value out, and a test can read back exactly what was
/// written. This is the seam the module is designed around — its rules are
/// exercised through it rather than through a plugin that has nothing behind
/// it on a test binding.
class MemoryLockVault implements LockVault {
  MemoryLockVault([this.value]);

  String? value;
  int writes = 0;
  int clears = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    writes++;
    this.value = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

/// A loaded store holding a lock per entry of [pins], on a vault of its own.
Future<ProfileLockStore> lockStore([
  Map<String, String> pins = const {},
]) async {
  final store = ProfileLockStore(vault: MemoryLockVault());
  for (final entry in pins.entries) {
    await store.set(entry.key, entry.value);
  }
  return store;
}

/// A device that offers biometrics, or does not, and recognises whoever asks,
/// or does not — the four cases the unlock surface has to answer for, none of
/// which a test binding can produce for itself.
class FakeBiometrics implements Biometrics {
  FakeBiometrics({this.offered = false, this.recognises = false});

  final bool offered;
  final bool recognises;

  /// How many times the OS prompt was asked for, so a test can tell "the
  /// prompt was never shown" from "it was shown and refused".
  int prompts = 0;

  @override
  Future<bool> available() async => offered;

  @override
  Future<bool> prompt(String reason) async {
    prompts++;
    return recognises;
  }
}

/// The preferences module's platform dependency, standing in for the
/// keychain — the same shape [MemoryLockVault] has, and there for the same
/// reason: the rules are exercised through the seam rather than through a
/// plugin that has nothing behind it on a test binding.
class MemoryPreferencesVault implements PreferencesVault {
  MemoryPreferencesVault([this.value]);

  String? value;
  int writes = 0;
  int clears = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    writes++;
    this.value = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

/// A loaded preferences store on a vault of its own, with [device] standing
/// for what the flat keys held before anybody had a profile.
Future<ProfilePreferencesStore> preferencesStore({
  MemoryPreferencesVault? vault,
  ReadingDirection deviceDirection = ReadingDirection.leftToRight,
  bool deviceMagnify = false,
  Locale? deviceLanguage,
}) async {
  final store = ProfilePreferencesStore(
    vault: vault ?? MemoryPreferencesVault(),
    deviceDirection: deviceDirection,
    deviceMagnify: deviceMagnify,
    deviceLanguage: deviceLanguage,
  );
  await store.load();
  return store;
}

/// One volume of one chapter, twelve pages into thirty — what a series that
/// has actually been opened leaves behind in `series/<id>.json`, and enough
/// for `resumePoint` to find a chapter genuinely under way.
///
/// Shared because more than one suite needs the same one: the catalogue's own
/// tests read it back through the store, and Home's offline tests need the
/// Continue card to have somewhere to resume from.
const catalogueVolumesFixture = [
  Volume(
    id: 1,
    name: '1',
    minNumber: 1,
    pages: 30,
    pagesRead: 12,
    chapters: [
      Chapter(
        id: 101,
        title: '',
        titleName: '',
        range: '12',
        minNumber: 12,
        pages: 30,
        pagesRead: 12,
        isSpecial: false,
        sortOrder: 12,
        format: MangaFormat.archive,
      ),
    ],
  ),
];

/// A catalogue on a temp directory, for a screen test that hands the tree a
/// client rather than signing one in.
///
/// Every fetch provider now writes what it fetched into the catalogue, and
/// the real store is keyed on the session — which these harnesses do not
/// have, exactly as they have no real client. Overriding the store is the
/// same move as overriding [kavitaClientProvider], and for the same reason:
/// what is under test is the screen, not the scoping. A test *about* the
/// scoping overrides [catalogueRootProvider] and lets the real provider key
/// the store.
Override testCatalogue({String profileId = 'test'}) {
  final root = Directory.systemTemp.createTempSync('patra-catalogue-test');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return catalogueStoreProvider.overrideWithValue(
    CatalogueStore(root: root, profileId: profileId),
  );
}

/// A server that is not there: every request fails to *reach* it.
///
/// Shared because more than one suite needs the state rather than the
/// response — a `DioException.connectionError` is what flips
/// `offlineProvider`, what `serverRetry` bounds, and what a resolved failure
/// is made of. [requests] is there so a test can tell "the catalogue
/// answered instead" from "nothing was ever asked", and [paths] so it can
/// tell what was *not* asked for — which is the only way to pin an endpoint
/// this app must never call.
class UnreachableServer implements HttpClientAdapter {
  final paths = <String>[];

  /// Derived rather than counted: two fields that can never legitimately
  /// disagree are one field and a bug waiting to be written.
  int get requests => paths.length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    paths.add(options.path);
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}
