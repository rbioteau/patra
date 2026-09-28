import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/image_cache_store.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/lock/biometrics.dart';
import 'package:patra/src/lock/profile_lock.dart';
import 'package:patra/src/settings/mobile_data.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// The Storage group of Settings: what the device holds, said once as a
/// meter, and the settings that decide what gets downloaded under it.

const _mb = 1024 * 1024;

final _profile = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key',
  token: 'token',
);

/// An image cache that holds [bytes] and remembers being cleared, without
/// the cache manager or an isolate a widget test cannot wait on.
class _Cache extends ImageCacheStore {
  _Cache(this.bytes);

  int bytes;
  var cleared = false;

  @override
  Future<int> size() async => bytes;

  @override
  Future<void> clear() async {
    cleared = true;
    bytes = 0;
  }
}

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async =>
      ResponseBody.fromString(
        '[]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Future<_Cache> _pump(
  WidgetTester tester, {
  int cacheBytes = 3 * _mb,
  List<int> savedBytes = const [],
}) async {
  tester.view.physicalSize = const Size(780, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final root = mockPathProvider();
  var id = 100;
  for (final bytes in savedBytes) {
    await saveChapterFixture(root, _profile.id, chapterId: id++, bytes: bytes);
  }
  final cache = _Cache(cacheBytes);
  final client = KavitaClient(
    baseUrl: _profile.baseUrl,
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _Adapter();
  client.bareHttpClient.httpClientAdapter = _Adapter();
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/downloads',
        builder: (_, _) => const Scaffold(body: Text('DOWNLOADS TAB')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(),
        testNetwork(),
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [_profile], activeId: _profile.id),
        ),
        kavitaClientProvider.overrideWithValue(client),
        profileLockStoreProvider.overrideWithValue(await lockStore()),
        biometricsProvider.overrideWithValue(FakeBiometrics()),
        downloadsRootProvider.overrideWithValue(root),
        imageCacheStoreProvider.overrideWithValue(cache),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: patraTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cache;
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text).first).dy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Storage comes straight after Profiles', (tester) async {
    await _pump(tester);
    expect(_top(tester, 'PROFILES'), lessThan(_top(tester, 'STORAGE')));
    expect(_top(tester, 'STORAGE'), lessThan(_top(tester, 'GENERAL')));
  });

  testWidgets('the meter says what the device holds, and of what', (
    tester,
  ) async {
    await _pump(tester, cacheBytes: 3 * _mb, savedBytes: [4 * _mb, 5 * _mb]);

    // Saved chapters and the image cache, added up once.
    expect(find.text('12 MB on this device'), findsOneWidget);
    expect(find.text('Saved chapters · 9 MB'), findsOneWidget);
    expect(find.text('Image cache · 3 MB'), findsOneWidget);

    // Two segments, each its share of the total: the downloads in their own
    // blue, the cache in the outline grey.
    final saved = tester.getSize(find.byKey(const ValueKey('meter-saved')));
    final cache = tester.getSize(find.byKey(const ValueKey('meter-cache')));
    expect(saved.width / cache.width, closeTo(3, 0.01));
    expect(
      (tester
                  .widget<AnimatedContainer>(
                    find.byKey(const ValueKey('meter-saved')),
                  )
                  .decoration!
              as BoxDecoration)
          .color,
      patraOffline,
    );
  });

  testWidgets('the saved chapters row opens the Downloads tab', (tester) async {
    await _pump(tester, savedBytes: [_mb, _mb]);
    await tester.tap(find.text('2 saved chapters'));
    await tester.pumpAndSettle();
    expect(find.text('DOWNLOADS TAB'), findsOneWidget);
  });

  testWidgets('clearing the cache says so and leaves saved chapters', (
    tester,
  ) async {
    final cache = await _pump(tester, savedBytes: [4 * _mb]);
    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();

    expect(cache.cleared, isTrue);
    expect(find.text('Image cache cleared'), findsOneWidget);
    expect(find.text('Image cache · 0 B'), findsOneWidget);
    expect(find.text('Saved chapters · 4 MB'), findsOneWidget);
    expect(find.text('4 MB on this device'), findsOneWidget);
  });

  testWidgets('an empty cache has nothing to clear', (tester) async {
    await _pump(tester, cacheBytes: 0);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Clear cache'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('the whole mobile data row is the switch', (tester) async {
    await _pump(tester);
    // The profile lock has a switch of its own; this is the one on the row.
    final toggle = find.descendant(
      of: find
          .ancestor(
            of: find.text('Download on mobile data'),
            matching: find.byType(InkWell),
          )
          .first,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(find.text('Download on mobile data'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)))
          .read(mobileDataDownloadsProvider)
          .value,
      isTrue,
    );
  });

  testWidgets('there is no batch size any more', (tester) async {
    // A selection picks any run by hand; a number chosen once for every
    // series had no place left to be used.
    await _pump(tester);
    expect(find.textContaining('Batch'), findsNothing);
  });
}
