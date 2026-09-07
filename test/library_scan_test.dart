import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/library/library_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// A server with one library, and whatever is asked of that library.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.empty = false});

  /// Whether the library has anything in it. The scan menu exists for the
  /// case it does — the empty state has a button of its own.
  final bool empty;

  final scans = <RequestOptions>[];

  /// How many times the grid has asked for its series. What pins the
  /// asymmetry: the menu must not drop a populated grid to its skeleton.
  int seriesRequests = 0;

  int scanStatus = 200;

  /// Held so a scan can be caught mid-flight, or the library list before it
  /// has arrived.
  Completer<void>? scanGate;
  Completer<void>? librariesGate;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    if (options.path == '/api/Library/scan') {
      scans.add(options);
      await scanGate?.future;
      return ResponseBody.fromString('', scanStatus);
    }
    if (options.path == '/api/Library/libraries') {
      await librariesGate?.future;
      return json([
        {'id': 7, 'name': 'Mangas', 'type': 0},
      ]);
    }
    if (options.path == '/api/Series/all-v2') {
      seriesRequests++;
      return json(
        empty
            ? const <Object>[]
            : [
                {
                  'id': 5,
                  'name': 'Vinland Saga',
                  'libraryId': 7,
                  'libraryName': 'Mangas',
                  'pages': 300,
                  'pagesRead': 0,
                },
              ],
      );
    }
    return ResponseBody.fromBytes(const [], 404);
  }

  @override
  void close({bool force = false}) {}
}

/// The library screen, signed in as somebody who is or is not an admin.
Future<_Adapter> _pump(
  WidgetTester tester, {
  required bool admin,
  bool empty = false,
  _Adapter? adapter,
}) async {
  mockPathProvider();
  mockSecureStorage();
  final served = adapter ?? _Adapter(empty: empty);
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = served;
  client.bareHttpClient.httpClientAdapter = served;

  final profile = Profile(
    baseUrl: 'http://kavita.test',
    accountId: 1,
    username: 'romain',
    token: 'token',
    apiKey: 'key',
    isAdmin: admin,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [profile], activeId: profile.id),
        ),
        kavitaClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LibraryScreen(),
      ),
    ),
  );
  return served;
}

final _menu = find.byTooltip('Library actions');

/// The menu's one item, whatever it is currently worded as. Found by
/// predicate because its value type is private to the screen.
PopupMenuItem<dynamic> _item(WidgetTester tester) =>
    tester.widget<PopupMenuItem<dynamic>>(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LibraryScreen)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('an administrator can always ask for a scan', () {
    testWidgets('of a library that has content, from the app bar', (
      tester,
    ) async {
      final adapter = await _pump(tester, admin: true);
      await tester.pumpAndSettle();

      // The grid is populated: before this menu there was no way in at all.
      expect(find.text('Vinland Saga'), findsOneWidget);

      await tester.tap(_menu);
      await tester.pumpAndSettle();
      // Worded, never an icon: a refresh glyph would be taken for the
      // pull-to-refresh on the same screen, which asks Kavita what it
      // already knows rather than changing the answer.
      expect(find.text('Ask server to scan'), findsOneWidget);

      await tester.tap(find.text('Ask server to scan'));
      await tester.pumpAndSettle();

      expect(adapter.scans, hasLength(1));
      // The action takes a bare int, which is where ASP.NET binds a
      // primitive from — a body would be silently ignored.
      expect(adapter.scans.single.queryParameters['libraryId'], 7);
      expect(find.textContaining('Scan requested'), findsOneWidget);
    });

    testWidgets('and the grid it is looking at stays on screen', (
      tester,
    ) async {
      final adapter = await _pump(tester, admin: true);
      await tester.pumpAndSettle();
      expect(adapter.seriesRequests, 1);

      await tester.tap(_menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask server to scan'));
      await tester.pumpAndSettle();

      // Invalidating here would drop a populated grid to its skeleton for a
      // background job that has produced nothing yet. The confirmation says
      // to pull down instead.
      expect(adapter.seriesRequests, 1);
      expect(find.text('Vinland Saga'), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });

    testWidgets('the empty state keeps its own button, and does refresh', (
      tester,
    ) async {
      final adapter = await _pump(tester, admin: true, empty: true);
      await tester.pumpAndSettle();
      expect(adapter.seriesRequests, 1);

      // Two entry points, both drawn: the empty state explains why there is
      // nothing and offers the fix in place, the menu is for content that
      // has gone stale.
      expect(_menu, findsOneWidget);
      await tester.tap(find.text('Ask server to scan'));
      await tester.pumpAndSettle();

      expect(adapter.scans, hasLength(1));
      // Here there is nothing on screen to lose and every reason to look
      // again.
      expect(adapter.seriesRequests, 2);
    });
  });

  group('what the control is not offered for', () {
    testWidgets('a non-admin is offered no scan control anywhere', (
      tester,
    ) async {
      final adapter = await _pump(tester, admin: false);
      await tester.pumpAndSettle();

      // Every scan endpoint is behind Kavita's AdminPolicy, so a non-admin
      // could earn nothing from one but a 403 — the same rule that leaves an
      // EPUB row untappable.
      expect(_menu, findsNothing);
      expect(find.text('Ask server to scan'), findsNothing);
      expect(adapter.scans, isEmpty);
    });

    testWidgets('nor an admin whose library list has not arrived', (
      tester,
    ) async {
      final adapter = _Adapter()..librariesGate = Completer<void>();
      await _pump(tester, admin: true, adapter: adapter);
      await tester.pump();

      // A menu whose one item acts on "the current library" says nothing
      // while there is no current library.
      expect(_menu, findsNothing);

      adapter.librariesGate!.complete();
      await tester.pumpAndSettle();
      expect(_menu, findsOneWidget);
    });
  });

  group('what the item says when it cannot be tapped', () {
    testWidgets('offline it is disabled with its reason, not hidden', (
      tester,
    ) async {
      final adapter = await _pump(tester, admin: true);
      await tester.pumpAndSettle();
      _container(tester).read(offlineProvider.notifier).set(true);
      await tester.pumpAndSettle();

      // Hidden, it would read as the role having gone — which is the one
      // thing it must not be confused with.
      expect(_menu, findsOneWidget);
      await tester.tap(_menu);
      await tester.pumpAndSettle();

      expect(_item(tester).enabled, isFalse);
      expect(find.text('Needs the server — offline'), findsOneWidget);

      await tester.tap(find.text('Ask server to scan'));
      await tester.pumpAndSettle();
      expect(adapter.scans, isEmpty);
    });

    testWidgets('a scan asked for from the empty state disables the item', (
      tester,
    ) async {
      final adapter = _Adapter(empty: true)..scanGate = Completer<void>();
      await _pump(tester, admin: true, adapter: adapter);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ask server to scan'));
      await tester.pump();

      // One flag, keyed by library, so neither entry point can be running a
      // scan the other does not know about.
      await tester.tap(_menu);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_item(tester).enabled, isFalse);
      // The button's label and the menu item's, both saying it.
      expect(find.text('Scanning…'), findsNWidgets(2));

      adapter.scanGate!.complete();
      await tester.pumpAndSettle();
      expect(adapter.scans, hasLength(1));
    });
  });

  test(
    'a second ask while one is in flight sends nothing, and says so',
    () async {
      mockSecureStorage();
      final adapter = _Adapter()..scanGate = Completer<void>();
      final client = KavitaClient(
        baseUrl: 'http://kavita.test',
        token: 'token',
        username: 'romain',
        apiKey: 'key',
      );
      client.httpClient.httpClientAdapter = adapter;
      final container = ProviderContainer.test(
        overrides: [kavitaClientProvider.overrideWithValue(client)],
      );
      final notifier = container.read(libraryScanProvider(7).notifier);

      final first = notifier.scan();
      await pumpEventQueue();
      final second = await notifier.scan();

      // Not a failure, and not a request either: reporting success would
      // confirm a scan the server never saw, and on the empty-state path would
      // refresh the grid on its behalf.
      expect(second.asked, isFalse);
      expect(second.failure, isNull);
      expect(adapter.scans, hasLength(1));

      adapter.scanGate!.complete();
      expect((await first).asked, isTrue);
      expect((await first).failure, isNull);
    },
  );

  testWidgets('a 403 words the refusal and takes the role with it', (
    tester,
  ) async {
    final adapter = _Adapter()..scanStatus = 403;
    await _pump(tester, admin: true, adapter: adapter);
    await tester.pumpAndSettle();

    await tester.tap(_menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask server to scan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not allowed'), findsOneWidget);
    // The server has just said, fresher than the flag the last sign-in
    // left, that this profile is not an administrator — so the controls it
    // draws stop being drawn until a sign-in says otherwise.
    expect(_container(tester).read(sessionProvider)?.isAdmin, isFalse);
    expect(_menu, findsNothing);
  });
}
