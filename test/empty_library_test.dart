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

/// A server with one library and nothing in it.
class _Adapter implements HttpClientAdapter {
  final scans = <RequestOptions>[];

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
      return ResponseBody.fromString('', 200);
    }
    return switch (options.path) {
      '/api/Library/libraries' => json([
        {'id': 7, 'name': 'Mangas', 'type': 0},
      ]),
      // The library has been created on the server but never scanned.
      _ => json(const <Object>[]),
    };
  }

  @override
  void close({bool force = false}) {}
}

Future<_Adapter> _pump(WidgetTester tester, {required bool admin}) async {
  mockPathProvider();
  final adapter = _Adapter();
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;

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
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('an empty library says why, and who can do something about it', () {
    testWidgets('it points at the server, and names the library', (
      tester,
    ) async {
      await _pump(tester, admin: false);

      expect(find.text('This library is empty'), findsOneWidget);
      // The name is picked out of the sentence rather than concatenated, so
      // the sentence keeps its shape in every language; it still has to be
      // in there.
      expect(find.textContaining('Mangas'), findsWidgets);
      expect(find.textContaining('scan it from Kavita'), findsOneWidget);
    });

    testWidgets('a non-admin is not offered a button that can only 403', (
      tester,
    ) async {
      final adapter = await _pump(tester, admin: false);

      // Every scan endpoint is behind Kavita's AdminPolicy — scan,
      // scan-multiple, scan-all, and scan-folder, which is [AllowAnonymous]
      // but checks the account itself. There is no non-admin path.
      expect(find.text('Ask server to scan'), findsNothing);
      expect(adapter.scans, isEmpty);
    });

    testWidgets('an admin can ask, and the library id goes in the query', (
      tester,
    ) async {
      final adapter = await _pump(tester, admin: true);

      expect(find.text('Ask server to scan'), findsOneWidget);
      await tester.tap(find.text('Ask server to scan'));
      await tester.pumpAndSettle();

      expect(adapter.scans, hasLength(1));
      // The action takes a bare int, which is where ASP.NET binds a
      // primitive from — a body would be silently ignored.
      expect(adapter.scans.single.queryParameters['libraryId'], 7);

      // The scan is a background job: it is requested here, never finished
      // here, and the copy has to say so.
      expect(find.textContaining('Scan requested'), findsOneWidget);
    });
  });
}
