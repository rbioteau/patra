import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/branding/patra_font_licenses.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

final _profile = Profile(
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
  // button at the bottom of it is not built until there is room.
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
          AuthState(profiles: [_profile], activeId: _profile.id),
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

  testWidgets('About opens what the app is built from', (tester) async {
    // The faces' OFL notices go into Flutter's `LicenseRegistry` from
    // `registerPatraFontLicenses`, and every package's own licence travels in
    // the `NOTICES` asset the build writes. This row is the only thing that
    // reads either, so it is the whole of what the licences are worth to a
    // reader — and the attribution MIT and BSD ask for.
    await _settings(
      tester,
      const ClientIdentity(deviceId: 'id', appVersion: '0.2.0'),
    );

    expect(find.text('Licenses'), findsOneWidget);

    await tester.tap(find.text('Licenses'));
    // The route's own transition, and no further: the page keeps a frame
    // scheduled while it reads the registry, so `pumpAndSettle` would wait on
    // whatever the licences happen to be — and would hang outright once the
    // faces are registered, which another test in this file does.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('every notice the app ships reaches that page', (tester) async {
    // The row is worth nothing if the page behind it is empty, and a bundled
    // font ships with its OFL or it may not be distributed at all. So this
    // reads what actually ships — every `*-OFL.txt` in the bundle — rather
    // than a list kept in step by hand: a face dropped into `assets/fonts/`
    // and left out of the registry is the failure, and nothing else can see
    // it.
    registerPatraFontLicenses();

    // Collecting the registry is what reads each notice off the bundle: a
    // face named there with no file beside it throws here.
    final entries = await LicenseRegistry.licenses.toList();
    final shipped = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .where(
          (asset) =>
              asset.startsWith('assets/fonts/') && asset.endsWith('-OFL.txt'),
        )
        .map(
          (asset) => asset.substring(
            'assets/fonts/'.length,
            asset.length - '-OFL.txt'.length,
          ),
        )
        .toSet();

    expect(shipped, isNotEmpty);
    expect(entries.expand((entry) => entry.packages), containsAll(shipped));
    for (final entry in entries.where(
      (entry) => entry.packages.any(shipped.contains),
    )) {
      expect(
        entry.paragraphs.map((paragraph) => paragraph.text).join('\n'),
        contains('SIL Open Font License'),
        reason: '${entry.packages.first} ships without its notice',
      );
    }
  });

  testWidgets('an unnamed build says so rather than nothing', (tester) async {
    // The fallback is deliberately not a copy of the current version — a
    // hardcoded one drifts silently, and an obviously absent number is a
    // better answer than a stale one.
    await _settings(tester, const ClientIdentity(deviceId: 'id'));

    expect(find.text('Version 0.0.0'), findsOneWidget);
  });

  testWidgets(
    'forgetting a profile is offered in the middle, not at the edge',
    (tester) async {
      await _settings(
        tester,
        const ClientIdentity(deviceId: 'id', appVersion: '0.2.0'),
      );

      // By its own text: the storage section has an outlined button too.
      final button = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Forget this profile'),
      );
      final screen = tester.getRect(find.byType(Scaffold));
      expect(button.center.dx, closeTo(screen.center.dx, 1));
      // Still a button rather than a banner: a whole settings screen to fill is
      // what stops one reading as something to press.
      expect(button.width, lessThanOrEqualTo(280));
    },
  );
}
