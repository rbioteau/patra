import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verso/l10n/generated/app_localizations.dart';
import 'package:verso/src/api/kavita_client.dart';
import 'package:verso/src/auth/session.dart';
import 'package:verso/src/features/library/library_screen.dart';
import 'package:verso/src/theme.dart';

import 'test_support.dart';

class _Adapter implements HttpClientAdapter {
  /// Flipped once the grid is on screen, so the refresh is the failing call.
  bool failing = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    if (failing) return ResponseBody.fromBytes(const [], 500);
    return switch (options.path) {
      '/api/Library/libraries' => json([
        {'id': 1, 'name': 'Manga', 'type': 0},
      ]),
      '/api/Series/all-v2' => json([
        {
          'id': 5,
          'name': 'Vinland Saga',
          'libraryId': 1,
          'libraryName': 'Manga',
          'pages': 300,
          'pagesRead': 0,
        },
      ]),
      _ => ResponseBody.fromBytes(const [], 404),
    };
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a pull to refresh against a dead server is not an error', (
    tester,
  ) async {
    mockPathProvider();
    final adapter = _Adapter();
    final client = KavitaClient(
      baseUrl: 'http://kavita.test',
      token: 'token',
      refreshToken: 'refresh',
      apiKey: 'key',
    );
    client.httpClient.httpClientAdapter = adapter;
    client.refreshHttpClient.httpClientAdapter = adapter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [kavitaClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: versoTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vinland Saga'), findsOneWidget);

    // RefreshIndicator waits on the future it is handed but never catches it.
    adapter.failing = true;
    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
