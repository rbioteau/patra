import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/catalogue/catalogue_provider.dart';
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// Answers everything with an empty body: this screen only reaches the server
/// for the card's dot and version, and neither is what is under test.
class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async =>
      ResponseBody.fromString(
        jsonEncode(const <String, Object>{}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Profile _profile(String username, int accountId) => Profile(
  baseUrl: 'https://kavita.example',
  accountId: accountId,
  username: username,
  apiKey: 'key-$username',
  token: 'token-$username',
);

final _romain = _profile('romain', 1);
final _lea = _profile('lea', 2);

/// One saved chapter in [profile]'s store, sized so the confirmation has a
/// round number to say: two mebibytes reads back as "2 MB".
Future<void> _save(Directory root, Profile profile, int chapterId) =>
    saveChapterFixture(
      root,
      profile.id,
      chapterId: chapterId,
      bytes: 2 * 1024 * 1024,
    );

/// Where the catalogue goes under a test's one temp directory.
Directory _catalogueRoot(Directory root) => Directory('${root.path}/catalogue');

/// A library and a series list in [profile]'s catalogue, written **through**
/// the store — a file dropped into the layout by hand is one the store's own
/// version stamp would have to be guessed at, which makes reading it back
/// vacuous.
Future<CatalogueStore> _remember(Directory root, Profile profile) async {
  final store = CatalogueStore(
    root: _catalogueRoot(root),
    profileId: profile.id,
  );
  await store.putLibraries([
    const Library(id: 1, name: 'Mangas', type: LibraryType.manga),
  ]);
  return store;
}

Future<Directory> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  mockPathProvider();
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final root = Directory.systemTemp.createTempSync('patra-forget-profile');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'token-romain',
    username: 'romain',
    apiKey: 'key-romain',
  );
  client.httpClient.httpClientAdapter = _Adapter();
  client.bareHttpClient.httpClientAdapter = _Adapter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(),
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [_romain, _lea], activeId: _romain.id),
        ),
        // The real service provider, so what it files under is what the
        // session says — which is the whole of this feature.
        downloadsRootProvider.overrideWithValue(root),
        // Beside the saved chapters, never inside them: both stores file by
        // profile, and one root would put a spine where `scan` sweeps.
        catalogueRootProvider.overrideWithValue(_catalogueRoot(root)),
        kavitaClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return root;
}

/// The button at the foot of Settings, brought into view: a `ListView` only
/// builds what it shows, and this screen has a row more than it used to.
Future<void> _reachForgetButton(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the confirmation names the saved reading about to go', (
    tester,
  ) async {
    final root = await _pump(tester);
    await _save(root, _romain, 101);
    await _save(root, _romain, 102);

    await _reachForgetButton(tester, 'Forget this profile');
    await tester.tap(find.text('Forget this profile'));
    await tester.pumpAndSettle();

    expect(find.text('Forget romain on kavita.example?'), findsOneWidget);
    expect(find.text('2 saved chapters (4 MB) will be deleted too.'), findsOne);
  });

  testWidgets('a profile with nothing saved says nothing about it', (
    tester,
  ) async {
    final root = await _pump(tester);
    // Léa's, not the profile being removed.
    await _save(root, _lea, 101);

    await _reachForgetButton(tester, 'Forget this profile');
    await tester.tap(find.text('Forget this profile'));
    await tester.pumpAndSettle();

    expect(find.textContaining('will be deleted too'), findsNothing);
  });

  testWidgets('confirming deletes that profile\'s saved chapters alone', (
    tester,
  ) async {
    final root = await _pump(tester);
    await _save(root, _romain, 101);
    await _save(root, _lea, 101);

    // Léa is the one being removed, from the row Settings draws for every
    // other profile this device remembers.
    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Forget'));
    await tester.pumpAndSettle();

    final mine = DownloadsService(root: root, profileId: _romain.id);
    final hers = DownloadsService(root: root, profileId: _lea.id);
    expect((await mine.scan()).keys, [101]);
    expect((await hers.profileRoot()).existsSync(), isFalse);
  });

  testWidgets('confirming deletes that profile\'s catalogue too', (
    tester,
  ) async {
    final root = await _pump(tester);
    final mine = await _remember(root, _romain);
    final hers = await _remember(root, _lea);

    // Léa's, from the row Settings draws for every other profile this device
    // remembers. Her catalogue is not named in the confirmation — that copy
    // lists what a person chose to keep and what losing it costs them, and
    // every byte of a catalogue is one refresh away from coming back.
    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('catalogue'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Forget'));
    await tester.pumpAndSettle();

    expect((await hers.profileRoot()).existsSync(), isFalse);
    expect((await mine.profileRoot()).existsSync(), isTrue);
  });

  test('the store survives the session it belonged to ending', () {
    // The shell is still on screen while the router redirects, and Riverpod
    // flushes a dirty provider that has listeners at the end of the frame —
    // so this is recomputed with no session by screens that are still reading
    // through it. Same keep-alive as `kavitaClientProvider`'s client.
    final container = ProviderContainer.test(
      overrides: [
        testKeychain(),
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [_romain], activeId: _romain.id),
        ),
      ],
    );

    final during = container.read(downloadsServiceProvider);
    expect(during.profileId, _romain.id);

    container.read(authProvider.notifier).switchProfile();

    expect(container.read(sessionProvider), isNull);
    expect(container.read(downloadsServiceProvider), same(during));
  });

  testWidgets('the French confirmation counts and sizes in French', (
    tester,
  ) async {
    final root = await _pump(tester, locale: const Locale('fr'));
    await _save(root, _romain, 101);

    await _reachForgetButton(tester, 'Oublier ce profil');
    await tester.tap(find.text('Oublier ce profil'));
    await tester.pumpAndSettle();

    expect(
      find.text('1 chapitre enregistré (2 Mo) sera aussi supprimé.'),
      findsOne,
    );
  });
}
