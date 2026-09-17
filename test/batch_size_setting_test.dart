import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// The batch's size is offered in Settings, under Storage (#101): three by
/// default, and a person's choice once made.

final _profile = Profile(
  baseUrl: 'https://kavita.example',
  username: 'rb',
  token: 'token',
  apiKey: 'key',
);

/// Answers everything with an empty body, so the settings screen — whose
/// server card probes `/api/Health` on its way in — settles.
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

Future<ProfilePreferencesStore> _settings(WidgetTester tester) async {
  mockPathProvider();
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
  final store = await preferencesStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [_profile], activeId: _profile.id),
        ),
        kavitaClientProvider.overrideWithValue(client),
        profilePreferencesStoreProvider.overrideWithValue(store),
        testKeychain(),
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
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the batch size is offered under Storage, three by default', (
    tester,
  ) async {
    await _settings(tester);

    final row = find.text('Batch download size');
    expect(row, findsOneWidget);
    expect(find.text('3 chapters'), findsOneWidget);
    // Under Storage, not General: it is a choice about the disk.
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(tester.getTopLeft(find.text('STORAGE')).dy),
    );
  });

  testWidgets('picking a size is the person\'s choice from then on', (
    tester,
  ) async {
    final store = await _settings(tester);

    await tester.tap(find.text('Batch download size'));
    await tester.pumpAndSettle();
    // The sheet offers the four sizes #101 names.
    for (final size in ['5 chapters', '10 chapters', '20 chapters']) {
      expect(find.text(size), findsOneWidget);
    }
    await tester.tap(find.text('10 chapters'));
    await tester.pumpAndSettle();

    expect(find.text('10 chapters'), findsOneWidget);
    expect(find.text('3 chapters'), findsNothing);
    expect(store.batchDownloadSizeFor(_profile.id), BatchDownloadSize.ten);
    // The device's own default is untouched: it was this person's choice.
    expect(store.deviceBatchDownloadSize, BatchDownloadSize.three);
  });
}
