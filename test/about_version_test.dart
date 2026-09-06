import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

const _server = ServerEntry(
  baseUrl: 'https://kavita.example',
  username: 'rb',
  token: 'token',
  apiKey: 'key',
);

/// Answers everything with an empty body, so the settings screen — whose
/// server card probes `/api/Health` on its way in — settles instead of leaving
/// a request pending. What this test is about is the row below it.
class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    if (options.path == '/api/Health') {
      return ResponseBody.fromString(
        'Ok',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(const <Object>[]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _settings(WidgetTester tester, ClientIdentity identity) async {
  mockPathProvider();
  // Tall enough for the whole screen: the body is a lazy list, and the
  // sign-out button at the bottom of it is not built until there is room.
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _Adapter();
  client.bareHttpClient.httpClientAdapter = _Adapter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          const AuthState(
            servers: [_server],
            activeUrl: 'https://kavita.example',
          ),
        ),
        clientIdentityProvider.overrideWithValue(identity),
        kavitaClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('About names the version the binary reports', (tester) async {
    // Read off the binary, not compiled in: CI passes the release tag to
    // --build-name, so what is shown is the version that shipped.
    await _settings(
      tester,
      const ClientIdentity(deviceId: 'id', appVersion: '0.2.0'),
    );

    expect(find.text('Version 0.2.0'), findsOneWidget);
  });

  testWidgets('an unnamed build says so rather than nothing', (tester) async {
    // The fallback is deliberately not a copy of the current version — a
    // hardcoded one drifts silently, and an obviously absent number is a
    // better answer than a stale one.
    await _settings(tester, const ClientIdentity(deviceId: 'id'));

    expect(find.text('Version 0.0.0'), findsOneWidget);
  });

  testWidgets('signing out is offered in the middle, not against the edge', (
    tester,
  ) async {
    await _settings(
      tester,
      const ClientIdentity(deviceId: 'id', appVersion: '0.2.0'),
    );

    // By its own text: the storage section has an outlined button too.
    final button = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Sign out'),
    );
    final screen = tester.getRect(find.byType(Scaffold));
    expect(button.center.dx, closeTo(screen.center.dx, 1));
    // Still a button rather than a banner: a whole settings screen to fill is
    // what stops one reading as something to press.
    expect(button.width, lessThanOrEqualTo(280));
  });
}
