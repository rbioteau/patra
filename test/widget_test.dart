import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/app.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/login/login_screen.dart';

/// A Kavita server with one library and one series.
class _StubAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    return switch (options.path) {
      '/api/Library/libraries' => json([
        {'id': 1, 'name': 'Mangas', 'type': 0},
      ]),
      '/api/Series/currently-reading' => json([
        {
          'id': 5,
          'name': 'Blame!',
          'libraryId': 1,
          'pages': 200,
          'pagesRead': 40,
        },
      ]),
      '/api/Series/on-deck' => json(const <Object>[]),
      _ => json(const <Object>[]),
    };
  }

  @override
  void close({bool force = false}) {}
}

const _server = ServerEntry(
  baseUrl: 'https://kavita.example',
  username: 'romain',
  token: 'token',
  refreshToken: 'refresh',
  apiKey: 'key',
);

Widget _app({AuthState auth = const AuthState(), Directory? downloadsRoot}) {
  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _StubAdapter();
  client.refreshHttpClient.httpClientAdapter = _StubAdapter();

  return ProviderScope(
    overrides: [
      initialAuthStateProvider.overrideWithValue(auth),
      kavitaClientProvider.overrideWithValue(client),
      if (downloadsRoot != null)
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: downloadsRoot),
        ),
    ],
    child: const PatraApp(),
  );
}

void main() {
  // Secure storage and the image cache both reach for the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('with no saved server, the login form is shown', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tests run under the default 'en' locale.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Server address'), findsOneWidget);
  });

  testWidgets('a remembered server is listed instead of the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        auth: const AuthState(
          // Remembered but signed out: no active session.
          servers: [ServerEntry(baseUrl: 'https://a.example', username: 'rb')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YOUR SERVERS'), findsOneWidget);
    expect(find.text('a.example'), findsOneWidget);
    expect(find.text('Add a server'), findsOneWidget);
    expect(find.text('Server address'), findsNothing);
  });

  testWidgets('an active session lands on the four-tab shell', (tester) async {
    final root = Directory.systemTemp.createTempSync('patra-widget-test');
    addTearDown(() => root.deleteSync(recursive: true));
    // Room for the shelves, so nothing overflows during the test.
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        auth: const AuthState(
          servers: [_server],
          activeUrl: 'https://kavita.example',
        ),
        downloadsRoot: root,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final tab in ['Home', 'Library', 'Downloads', 'Settings']) {
      expect(find.text(tab), findsOneWidget, reason: '$tab tab is present');
    }
    // The home shelf rendered the series the stub server is serving.
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('Blame!'), findsOneWidget);
    // An empty section renders nothing rather than an empty label.
    expect(find.text('ON DECK'), findsNothing);

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved chapters'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Default reading direction'), findsOneWidget);
    expect(find.text('Left to right'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('the navigation bar drops its labels when they do not fit', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('patra-nav-test');
    addTearDown(() => root.deleteSync(recursive: true));
    addTearDown(tester.view.reset);

    Future<NavigationBar> pumpAt(Size physicalSize) async {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = 3;
      await tester.pumpWidget(
        _app(
          auth: const AuthState(
            servers: [_server],
            activeUrl: 'https://kavita.example',
          ),
          downloadsRoot: root,
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<NavigationBar>(find.byType(NavigationBar));
    }

    // A phone in portrait: four labels cannot share the width.
    final narrow = await pumpAt(const Size(1240, 2772));
    expect(narrow.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);

    // A tablet, or the same phone in landscape: they fit.
    final wide = await pumpAt(const Size(3000, 2000));
    expect(wide.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
  });
}
