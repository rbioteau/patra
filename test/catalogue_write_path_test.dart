import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/app.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/catalogue/catalogue_provider.dart';
import 'package:patra/src/catalogue/catalogue_reads.dart' as catalogue;
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/session_scope.dart';

import 'test_support.dart';

/// A server whose library list, series pages and series detail can each be
/// dictated by the test — including a paging run that dies partway.
class _Adapter implements HttpClientAdapter {
  _Adapter({
    this.libraries = const [1],
    this.seriesPages = const {},
    this.onDeck = const [],
    this.serverDown = false,
  });

  /// A server nothing can reach: every fetch fails, so whatever a screen
  /// shows can only have come off the device.
  final bool serverDown;

  /// The library ids the server lists.
  final List<int> libraries;

  /// Library id → the pages `all-v2` answers with, in order. A null page is
  /// a request that fails, which is what a run dying on page 3 looks like.
  final Map<int, List<List<Map<String, Object>>?>> seriesPages;

  final List<Map<String, Object>> onDeck;

  /// How many pages of each library were asked for.
  final asked = <int, int>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    if (serverDown) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route',
      );
    }
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    if (options.path == '/api/Library/libraries') {
      return json([
        for (final id in libraries) {'id': id, 'name': 'L$id', 'type': 0},
      ]);
    }
    if (options.path == '/api/Series/all-v2') {
      final id = _libraryOf(options.data);
      final page = asked[id] = (asked[id] ?? 0) + 1;
      final pages = seriesPages[id] ?? const [];
      final answer = page <= pages.length ? pages[page - 1] : const [];
      if (answer == null) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 500),
        );
      }
      return json(answer);
    }
    if (options.path == '/api/Series/on-deck') return json(onDeck);
    if (options.path == '/api/Series/volumes') {
      return json([
        {
          'id': 1,
          'name': 'Tome 1',
          'minNumber': 1,
          'pages': 20,
          'pagesRead': 3,
          'chapters': [
            {'id': 10, 'title': '1', 'minNumber': 1, 'pages': 20},
          ],
        },
      ]);
    }
    if (options.path == '/api/Series/metadata') {
      return json({
        'summary': 'A city',
        'writers': [
          {'name': 'Nihei'},
        ],
      });
    }
    if (options.path.startsWith('/api/Series/')) {
      return json({'id': 5, 'name': 'Blame!', 'libraryId': 1, 'pages': 200});
    }
    return json(const <Object>[]);
  }

  /// The library id out of the filter body `all-v2` is posted with.
  int _libraryOf(Object? data) {
    final statements = ((data! as Map)['statements'] as List)
        .cast<Map<String, dynamic>>();
    return int.parse(statements.single['value'] as String);
  }

  @override
  void close({bool force = false}) {}
}

final _romain = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-romain',
  token: 'token-romain',
);

final _lea = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 2,
  username: 'lea',
  apiKey: 'key-lea',
  token: 'token-lea',
);

Map<String, Object> _seriesJson(int id, {String name = 'Blame!'}) => {
  'id': id,
  'name': name,
  'libraryId': 1,
  'libraryName': 'L1',
  'pages': 200,
  'pagesRead': 40,
};

Directory _root() {
  final root = Directory.systemTemp.createTempSync('patra-catalogue-write');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return root;
}

/// A container reading as [profile], with the real catalogue providers doing
/// the profile scoping — that scoping is half of what is under test, so this
/// overrides the **root** and never the store.
ProviderContainer _container({
  required Directory root,
  required _Adapter adapter,
  Profile? profile,
}) {
  final who = profile ?? _romain;
  final client = KavitaClient(
    baseUrl: who.baseUrl,
    token: who.token,
    username: who.username,
    apiKey: who.apiKey,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;
  final container = ProviderContainer.test(
    overrides: [
      initialAuthStateProvider.overrideWithValue(
        AuthState(profiles: [_romain, _lea], activeId: who.id),
      ),
      kavitaClientProvider.overrideWithValue(client),
      catalogueRootProvider.overrideWithValue(root),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('every fetch writes what it fetched', () {
    test('the library list, and then every library it named', () async {
      final root = _root();
      final adapter = _Adapter(
        libraries: [1, 2],
        seriesPages: {
          1: [
            [_seriesJson(5)],
          ],
          2: [
            [_seriesJson(9, name: 'Berserk')],
          ],
        },
      );
      final container = _container(root: root, adapter: adapter);

      await container.read(catalogue.libraries.refreshable);
      // The eager fill is fire-and-forget behind the answer, and sequential:
      // a library never opened has to be navigable offline all the same.
      await pumpEventQueue();

      final spine = await CatalogueStore(
        root: root,
        profileId: _romain.id,
      ).loadSpine();
      expect(spine.libraries.map((l) => l.id), [1, 2]);
      expect(spine.series[1]!.single.id, 5);
      expect(spine.series[2]!.single.name, 'Berserk');
    });

    test('a series list, its volumes, its row and its description', () async {
      final root = _root();
      final container = _container(
        root: root,
        adapter: _Adapter(
          seriesPages: {
            1: [
              [_seriesJson(5)],
            ],
          },
        ),
      );

      await container.read(catalogue.seriesForLibrary(1).refreshable);
      await container.read(catalogue.volumes(5).refreshable);
      await container.read(catalogue.series(5).refreshable);
      await container.read(catalogue.seriesMetadata(5).refreshable);

      final store = CatalogueStore(root: root, profileId: _romain.id);
      expect((await store.loadSpine()).series[1]!.single.id, 5);
      final stored = (await store.loadSeries(5))!;
      expect(stored.volumes!.single.chapters.single.id, 10);
      expect(stored.series!.name, 'Blame!');
      expect(stored.metadata!.writers, ['Nihei']);
    });

    test('the On deck shelf, which is the whole of Home', () async {
      final root = _root();
      final container = _container(
        root: root,
        adapter: _Adapter(onDeck: [_seriesJson(5)]),
      );

      await container.read(catalogue.onDeck.refreshable);

      final stored = await CatalogueStore(
        root: root,
        profileId: _romain.id,
      ).loadOnDeck();
      expect(stored.single.id, 5);
    });
  });

  group('the tab and the eager fill are one filling, not two', () {
    test('a library the tab has paged is not paged again', () async {
      // The bookkeeping between them had no test at all: nothing could tell
      // "the tab's own fetch stored this library" from "the eager fill did",
      // so `markStored` could have been dropped in silence. What it costs is
      // not correctness but a household's 2000-series library paged twice on
      // the one visit that opens the tab.
      final root = _root();
      final adapter = _Adapter(
        libraries: [1, 2],
        seriesPages: {
          1: [
            [_seriesJson(5)],
          ],
          2: [
            [_seriesJson(9, name: 'Berserk')],
          ],
        },
      );
      final container = _container(root: root, adapter: adapter);

      // The order the Library tab produces: it asks for the selected
      // library and for the list at once, and the selected one lands first.
      await container.read(catalogue.seriesForLibrary(1).refreshable);
      await container.read(catalogue.libraries.refreshable);
      await pumpEventQueue();

      expect(
        adapter.asked[1],
        1,
        reason: 'the fill must skip the library the tab has just stored',
      );
      expect(
        adapter.asked[2],
        1,
        reason: 'and still page the one nothing has opened',
      );
      // Both are in the spine either way: what is under test is who paged
      // them, not whether they are there.
      final spine = await CatalogueStore(
        root: root,
        profileId: _romain.id,
      ).loadSpine();
      expect(spine.series.keys, containsAll(<int>[1, 2]));
    });
  });

  group('only a complete answer replaces', () {
    test('a run that reaches the end of the paging does', () async {
      final root = _root();
      // 100 is the page size, so a full page is followed by another request
      // and a short one ends the run.
      final adapter = _Adapter(
        seriesPages: {
          1: [
            [for (var id = 100; id < 200; id++) _seriesJson(id)],
            [_seriesJson(9)],
          ],
        },
      );
      final container = _container(root: root, adapter: adapter);

      await container.read(catalogue.seriesForLibrary(1).refreshable);

      final spine = await CatalogueStore(
        root: root,
        profileId: _romain.id,
      ).loadSpine();
      expect(spine.series[1], hasLength(101));
    });

    test('a run that dies partway leaves the catalogue alone', () async {
      final root = _root();
      // What the device already holds, written the way a complete fetch
      // would have written it.
      final held = CatalogueStore(root: root, profileId: _romain.id);
      await held.putSeriesList(1, [
        Series.fromJson(_seriesJson(5)),
        Series.fromJson(_seriesJson(6)),
        Series.fromJson(_seriesJson(7)),
      ]);

      final container = _container(
        root: root,
        adapter: _Adapter(
          seriesPages: {
            1: [
              [for (var id = 100; id < 200; id++) _seriesJson(id)],
              null,
            ],
          },
        ),
      );

      await expectLater(
        container.read(catalogue.seriesForLibrary(1).refreshable),
        throwsA(isA<DioException>()),
      );

      // The paging loop is what says the answer was complete: it returns only
      // once a short page has ended the run, so a run that died never reached
      // the body that stores it. 200 series must not replace 250.
      final spine = await CatalogueStore(
        root: root,
        profileId: _romain.id,
      ).loadSpine();
      expect(spine.series[1]!.map((s) => s.id), [5, 6, 7]);
    });

    test(
      'and the eager fill skips that library rather than the rest',
      () async {
        final root = _root();
        final adapter = _Adapter(
          libraries: [1, 2],
          seriesPages: {
            1: [null],
            2: [
              [_seriesJson(9, name: 'Berserk')],
            ],
          },
        );
        final container = _container(root: root, adapter: adapter);

        await container.read(catalogue.libraries.refreshable);
        await pumpEventQueue();

        final spine = await CatalogueStore(
          root: root,
          profileId: _romain.id,
        ).loadSpine();
        expect(spine.series, isNot(contains(1)));
        expect(spine.series[2]!.single.name, 'Berserk');
      },
    );
  });

  group('when the catalogue is read back', () {
    test('the store main() warmed is the one the session reads', () async {
      // What `main()` does before `runApp` where `atLaunch` produced a
      // session: read the spine whole, then hand the store it read into over
      // this family's one key. Nothing else would make the awaited read worth
      // anything — a second store built from the root would read it again.
      final root = _root();
      final warmed = CatalogueStore(root: root, profileId: _romain.id);
      await warmed.putLibraries([
        const Library(id: 1, name: 'Remembered', type: LibraryType.manga),
      ]);

      final container = ProviderContainer.test(
        overrides: [
          testKeychain(),
          initialAuthStateProvider.overrideWithValue(
            AuthState(profiles: [_romain], activeId: _romain.id),
          ),
          catalogueRootProvider.overrideWithValue(root),
          profileCatalogueProvider(_romain.id).overrideWithValue(warmed),
        ],
      );
      addTearDown(container.dispose);

      final reading = container.read(catalogueStoreProvider);
      expect(reading, same(warmed));
      expect(reading.spine!.libraries.single.name, 'Remembered');
      // And nobody else's: the override is one key of the family, so anybody
      // entered later gets a store of their own from the root.
      expect(
        container.read(profileCatalogueProvider(_lea.id)),
        isNot(same(warmed)),
      );
    });

    testWidgets('entering a profile from the picker reads its spine', (
      tester,
    ) async {
      mockPathProvider();
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final root = _root();

      // What a *previous* session left behind, written through a store of its
      // own: handing the scope the instance that wrote it would leave the
      // spine in memory and this test would pass with nothing reading a file.
      await CatalogueStore(root: root, profileId: _romain.id).putLibraries([
        const Library(id: 1, name: 'Remembered', type: LibraryType.manga),
      ]);

      // A server nothing can reach, so the library below cannot have been
      // fetched: `main()` awaits the spine only where `atLaunch` produced a
      // session, and this device has two profiles and lands on the picker.
      final client = KavitaClient(
        baseUrl: _romain.baseUrl,
        token: _romain.token,
        username: _romain.username,
        apiKey: _romain.apiKey,
      );
      final adapter = _Adapter(serverDown: true);
      client.httpClient.httpClientAdapter = adapter;
      client.bareHttpClient.httpClientAdapter = adapter;

      await tester.pumpWidget(
        SessionScope(
          auth: AuthState(profiles: [_romain, _lea]).atLaunch(),
          overrides: [
            catalogueRootProvider.overrideWithValue(root),
            kavitaClientProvider.overrideWithValue(client),
            signInProvider.overrideWithValue(
              ({
                required String baseUrl,
                required String username,
                required Credential credential,
                ClientIdentity identity = const ClientIdentity.unknown(),
              }) async => LoginResult(
                username: username,
                token: signedToken(1),
                apiKey: _romain.apiKey,
              ),
            ),
          ],
          child: const PatraApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      // The scope reads it behind the tap: there is no first frame to protect
      // on this path, because the tap is already a request.
      final spine = tester.container().read(catalogueStoreProvider).spine;
      expect(spine!.libraries.single.name, 'Remembered');
    });
  });

  group('whose catalogue is being written', () {
    test('the store is the session\'s, and survives it ending', () {
      final container = _container(root: _root(), adapter: _Adapter());

      final during = container.read(catalogueStoreProvider);
      expect(during.profileId, _romain.id);

      // The shell is still on screen while the router redirects, and Riverpod
      // flushes a dirty provider that has listeners at the end of the frame —
      // so this is recomputed with no session by screens still writing
      // through it.
      container.read(authProvider.notifier).switchProfile();
      expect(container.read(sessionProvider), isNull);
      expect(container.read(catalogueStoreProvider), same(during));
    });

    test('a handover does not carry one into the next container', () async {
      final root = _root();
      final mine = _container(
        root: root,
        adapter: _Adapter(
          seriesPages: {
            1: [
              [_seriesJson(5)],
            ],
          },
        ),
      );
      await mine.read(catalogue.seriesForLibrary(1).refreshable);

      // What `SessionScope` builds when the tablet is handed over: a fresh
      // container on the same device-owned overrides.
      final hers = _container(root: root, adapter: _Adapter(), profile: _lea);

      expect(hers.read(catalogueStoreProvider).profileId, _lea.id);
      expect(
        (await hers.read(catalogueStoreProvider).loadSpine()).isEmpty,
        isTrue,
      );
      // And the keep-alive is per container, so a container that has served
      // nobody cannot hand back the previous person's store either.
      final nobody = ProviderContainer.test(
        overrides: [
          initialAuthStateProvider.overrideWithValue(
            AuthState(profiles: [_romain, _lea]),
          ),
          catalogueRootProvider.overrideWithValue(root),
        ],
      );
      addTearDown(nobody.dispose);
      expect(
        () => nobody.read(catalogueStoreProvider),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'the no-session StateError',
            contains('No active session'),
          ),
        ),
      );
    });
  });
}
