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

    testWidgets('an admin is not sent to Kavita for a button that is here', (
      tester,
    ) async {
      await _pump(tester, admin: true);

      // Two role-specific sentences rather than one: for a non-admin Kavita
      // really is the only route, and for an admin the fix is two lines
      // below.
      expect(find.textContaining('scan it from Kavita'), findsNothing);
      expect(find.textContaining('then ask for a scan'), findsOneWidget);
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

    testWidgets('the button is allowed the app\'s whole control width', (
      tester,
    ) async {
      await _pump(tester, admin: true);

      // It had a 200 of its own, which left the label 146pt once the padding,
      // the icon and its gap were taken — and "Demander une analyse" is 146pt
      // at 14pt semibold, so French wrapped onto two lines where the English
      // label had 27pt to spare. The cap is a maximum rather than a width, so
      // raising it to the shared token costs English nothing and only lets a
      // longer language have the room.
      //
      // What this can actually assert is the **cap**, not the wrapping: the
      // test font draws every glyph as a square of the font size, so both
      // labels are wider than any cap here and the button renders at exactly
      // its maximum. That makes the number observable and a tighter bespoke
      // one impossible to reintroduce quietly; it says nothing about Space
      // Grotesk, where the French label is 146pt against the 214pt this
      // leaves it.
      expect(
        tester.getSize(find.byType(OutlinedButton)).width,
        controlMaxWidth,
      );
    });
  });
}
