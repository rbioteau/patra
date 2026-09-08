import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/catalogue/catalogue_overlay.dart';
import 'package:patra/src/catalogue/catalogue_provider.dart';
import 'package:patra/src/catalogue/catalogue_store.dart';
import 'package:patra/src/features/library/library_screen.dart';

import 'test_support.dart';

const _library = Library(id: 7, name: 'Mangas', type: LibraryType.manga);

Series _series(int id) => Series(
  id: id,
  name: 'Blame! $id',
  libraryId: 7,
  libraryName: 'Mangas',
  pages: 100,
  pagesRead: 10,
  format: MangaFormat.archive,
  latestReadDate: null,
);

/// A server that answers the library list once and then never again.
///
/// What a pull-to-refresh with the connection gone actually looks like, which
/// is the state the first branch of the rule is about.
class _AnswersThenHangs implements HttpClientAdapter {
  final _gate = Completer<void>();
  var calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    calls++;
    // Never completes: the refresh is still in flight when the test looks.
    if (calls > 1) await _gate.future;
    return ResponseBody.fromString(
      jsonEncode([
        {'id': 7, 'name': 'Server', 'type': 0},
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A container reading through [store], against whatever [adapter] is.
///
/// The client is a real one on a stubbed adapter rather than a stubbed
/// client, because what the overlay has to answer for is a *resolved
/// failure* — and only a real client produces the one `serverRetry` stops at.
ProviderContainer _container(HttpClientAdapter adapter, CatalogueStore store) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [
      kavitaClientProvider.overrideWithValue(client),
      catalogueStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// The same, against a server that is not there at all.
({ProviderContainer container, UnreachableServer adapter}) _offline(
  CatalogueStore store,
) {
  final adapter = UnreachableServer();
  return (container: _container(adapter, store), adapter: adapter);
}

CatalogueStore _store() {
  final root = Directory.systemTemp.createTempSync('patra-overlay-test');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return CatalogueStore(root: root, profileId: 'test');
}

/// The overlay's value once the fetch behind it has finished failing.
///
/// The listener is not optional. Both the overlay and the fetch it watches
/// are `autoDispose`, so a `read` nobody is listening to disposes the fetch
/// the instant it is awaited — and the next read starts a *fresh* one, which
/// is `loading` and not the resolved failure the overlay has to answer for.
Future<AsyncValue<T>> resolved<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> overlay,
  Future<Object?> fetch,
) async {
  final subscription = container.listen<AsyncValue<T>>(overlay, (_, _) {});
  addTearDown(subscription.close);
  await expectLater(fetch, throwsA(isA<DioException>()));
  return subscription.read();
}

void main() {
  group('the precedence rule', () {
    test('live wins, even where the catalogue has an answer too', () {
      expect(overlaid(const AsyncData([1]), const AsyncData([2])).value, [
        1,
      ], reason: 'the server is the authority whenever it has spoken');
    });

    test('a live refresh in flight keeps the value it is refreshing', () async {
      // `hasValue` and not `isLoading` is what "live wins" has to ask: a
      // refresh carries the answer it is refreshing, and dropping to the
      // catalogue mid-pull would swap the list under the person pulling it.
      //
      // Driven through a real refresh rather than a hand-built AsyncValue,
      // which also pins the assumption the rule rests on: that Riverpod does
      // carry the previous value across one.
      final store = _store();
      await store.putLibraries(const [_library]);
      final container = _container(_AnswersThenHangs(), store);
      final subscription = container.listen<AsyncValue<List<Library>>>(
        librariesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container.read(librariesFetchProvider.future);
      expect(subscription.read().value!.single.name, 'Server');

      container.invalidate(librariesFetchProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        subscription.read().value!.single.name,
        'Server',
        reason: 'the catalogue must not take over mid-refresh',
      );
    });

    test('stored draws as data, not as loading', () {
      final overlay = overlaid(
        AsyncError<List<int>>('nope', StackTrace.empty),
        const AsyncData([2]),
      );
      expect(overlay.value, [2]);
      expect(overlay.isLoading, isFalse);
      expect(
        overlay.hasError,
        isFalse,
        reason: 'a screen with something to draw is not in an error state',
      );
    });

    test('the live error, once the catalogue has answered with nothing', () {
      final overlay = overlaid(
        AsyncError<List<int>>('nope', StackTrace.empty),
        const AsyncData(null),
      );
      expect(overlay.hasError, isTrue);
      expect(
        overlay.isResolvedFailure,
        isTrue,
        reason: 'this is what keeps the offline empty states drawing',
      );
    });

    test('a catalogue still being read is loading, not the live error', () {
      // Otherwise a cold offline start flashes its error state and then
      // replaces it with the shelves a moment later.
      final overlay = overlaid(
        AsyncError<List<int>>('nope', StackTrace.empty),
        const AsyncLoading(),
      );
      expect(overlay.isLoading, isTrue);
      expect(overlay.hasError, isFalse);
    });

    test('loading, where nobody has answered at all', () {
      expect(
        overlaid(
          const AsyncLoading<List<int>>(),
          const AsyncData(null),
        ).isLoading,
        isTrue,
      );
    });
  });

  group('the libraries', () {
    test('offline, the catalogue is what the tab draws', () async {
      final store = _store();
      await store.putLibraries(const [_library]);
      final (container: container, adapter: adapter) = _offline(store);

      // The fetch has to have finished failing: the overlay must answer for a
      // resolved failure, not for one still being retried.
      final overlay = await resolved(
        container,
        librariesProvider,
        container.read(librariesFetchProvider.future),
      );
      expect(overlay.value, isNotNull);
      expect(overlay.value!.single.name, 'Mangas');
      expect(overlay.hasError, isFalse);
      expect(adapter.requests, greaterThan(0));
    });

    test('offline with an empty catalogue, the failure still shows', () async {
      final store = _store();
      // Read before the assertion, as a screen's own first frame does: an
      // empty catalogue is only an *answer* once the device has been asked.
      await store.loadSpine();
      final (container: container, adapter: _) = _offline(store);
      final overlay = await resolved(
        container,
        librariesProvider,
        container.read(librariesFetchProvider.future),
      );
      expect(overlay.isResolvedFailure, isTrue);
    });

    test('the type and the current library come off the overlay', () async {
      // Both used to read the raw fetch, so offline a comic library said
      // "chapitre" and the scan menu had no library to act on.
      final store = _store();
      await store.putLibraries(const [
        Library(id: 7, name: 'Comics', type: LibraryType.comic),
      ]);
      final (container: container, adapter: _) = _offline(store);
      await resolved(
        container,
        librariesProvider,
        container.read(librariesFetchProvider.future),
      );

      expect(container.read(libraryTypeProvider(7)), LibraryType.comic);
      expect(container.read(currentLibraryProvider), 7);
    });
  });

  group('one library\'s series', () {
    test('offline, the catalogue is what the grid draws', () async {
      final store = _store();
      await store.putSeriesList(7, [_series(1), _series(2)]);
      final (container: container, adapter: _) = _offline(store);

      final overlay = await resolved(
        container,
        seriesForLibraryProvider(7),
        container.read(seriesForLibraryFetchProvider(7).future),
      );
      expect(overlay.value, hasLength(2));
      expect(overlay.hasError, isFalse);
    });

    test('a library the catalogue has never held keeps its failure', () async {
      final store = _store();
      await store.putSeriesList(7, [_series(1)]);
      final (container: container, adapter: _) = _offline(store);

      final overlay = await resolved(
        container,
        seriesForLibraryProvider(9),
        container.read(seriesForLibraryFetchProvider(9).future),
      );
      expect(overlay.isResolvedFailure, isTrue);
    });

    test('a library stored as empty is an answer, not an absence', () async {
      // An empty library is a state the screen has copy for; falling through
      // to the failure would replace that copy with a retry button.
      final store = _store();
      await store.putSeriesList(7, const []);
      final (container: container, adapter: _) = _offline(store);

      final overlay = await resolved(
        container,
        seriesForLibraryProvider(7),
        container.read(seriesForLibraryFetchProvider(7).future),
      );
      expect(overlay.hasValue, isTrue);
      expect(overlay.value, isEmpty);
    });
  });

  test('a spine written mid-session is the one the overlay reads', () async {
    // The ordinary "went offline while using the app" case, and the one a
    // cached spine breaks: the store replaces its `Spine` on every write, so
    // an overlay holding the instance it first read has never heard of the
    // library the prefetch stored a minute later.
    final store = _store();
    await store.putLibraries(const [_library]);
    final (container: container, adapter: _) = _offline(store);

    final before = await resolved(
      container,
      seriesForLibraryProvider(7),
      container.read(seriesForLibraryFetchProvider(7).future),
    );
    expect(before.isResolvedFailure, isTrue, reason: 'nothing stored yet');

    // What the eager fill does, online, while somebody is on another tab.
    await store.putSeriesList(7, [_series(1)]);

    // And what tapping the pill does once the connection has gone.
    container.invalidate(seriesForLibraryFetchProvider(7));
    final after = await resolved(
      container,
      seriesForLibraryProvider(7),
      container.read(seriesForLibraryFetchProvider(7).future),
    );
    expect(
      after.value,
      hasLength(1),
      reason: 'the spine is re-read whenever the fetch moves',
    );
  });

  test('a populated catalogue is not a resolved failure, which is what '
      'Home\'s offline gate reads', () async {
    // `librariesProvider` is one question both tabs ask, deliberately, so
    // that they cannot disagree about which libraries exist — which means
    // Home's `nothingCameBack` gate (`hero == null && onDeck.isResolvedFailure
    // && libraries.isResolvedFailure`) consults the catalogue from the moment
    // this overlay exists. Pinned here as the mechanism; the screen itself is
    // #33's.
    final store = _store();
    await store.putLibraries(const [_library]);
    final (container: container, adapter: _) = _offline(store);
    final overlay = await resolved(
      container,
      librariesProvider,
      container.read(librariesFetchProvider.future),
    );
    expect(overlay.isResolvedFailure, isFalse);
  });

  test('nothing in lib watches a fetch provider', () {
    // The regression this exists to catch is a screen reading the raw fetch
    // and so losing the catalogue for itself alone — silently, one screen at
    // a time, and looking exactly like working code.
    //
    // **No exceptions**, which is the whole reason `spineOverlay` takes the
    // fetch as an argument: the one legitimate watch happens inside
    // `catalogue_overlay.dart`, on a provider it was handed, so there is no
    // file to whitelist. An earlier version of this test exempted the
    // declaring file — which is `library_screen.dart`, the file holding
    // every consumer it was meant to police.
    //
    // `invalidate`, `refresh` and `read(...future)` are deliberately not
    // matched: pull-to-refresh has to reach the fetch, since an overlay has
    // no future to await.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in RegExp(
        r'(watch|listen)\(\s*(\w+FetchProvider)',
      ).allMatches(file.readAsStringSync())) {
        offenders.add('${file.path}: ${match.group(1)}(${match.group(2)})');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'watch the overlay, not the fetch behind it',
    );
  });
}
