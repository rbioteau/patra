import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/external_links.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/lock/biometrics.dart';
import 'package:patra/src/lock/profile_lock.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/profile_avatar.dart';

import 'test_support.dart';

Profile _profile({
  int accountId = 1,
  String username = 'romain',
  String baseUrl = 'https://kavita.example',
}) => Profile(
  baseUrl: baseUrl,
  accountId: accountId,
  username: username,
  apiKey: 'key',
  token: 'token',
);

/// Answers everything, so the screen's own reachability probe settles — and
/// names a version, so the card draws the longest second line it can:
/// dot, host, ` · `, and the release.
class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async =>
      ResponseBody.fromString(
        // `/api/Plugin/version` answers a bare string, not an object.
        options.path == '/api/Plugin/version'
            ? jsonEncode('0.9.1.4')
            : jsonEncode(const <Object>[]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  List<Profile>? profiles,
  Size size = const Size(1200, 2800),
  double textScale = 1,
  MemoryLinks? links,
}) async {
  final root = mockPathProvider();
  final people = profiles ?? [_profile()];
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final client = KavitaClient(
    baseUrl: people.first.baseUrl,
    token: 'token',
    username: people.first.username,
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _Adapter();
  client.bareHttpClient.httpClientAdapter = _Adapter();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        testKeychain(),
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: people, activeId: people.first.id),
        ),
        kavitaClientProvider.overrideWithValue(client),
        profileLockStoreProvider.overrideWithValue(await lockStore()),
        biometricsProvider.overrideWithValue(FakeBiometrics()),
        downloadsRootProvider.overrideWithValue(root),
        if (links != null) externalLinksProvider.overrideWithValue(links),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: patraTheme(),
        // `copyWith`, never a fresh `MediaQueryData`: a bare one leaves
        // `MediaQuery.sizeOf` at zero, and the five screens that ask it
        // which shape to draw would silently take the wrong branch.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const SettingsScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Where a widget's top edge sits in the screen's own coordinates, for
/// asserting that one thing is drawn before another down the list.
double _topOf(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  testWidgets('the card names the active profile, not the server', (
    tester,
  ) async {
    await _pumpSettings(tester);

    // The person in the title, the server underneath it. It was the other
    // way round while this was a card about a server.
    final name = find.text('romain');
    // One `Text.rich` now: the host shares its line with the release.
    final host = find.textContaining('kavita.example');
    expect(name, findsOneWidget);
    expect(host, findsOneWidget);
    expect(_topOf(tester, name), lessThan(_topOf(tester, host)));
    expect(find.byType(ProfileAvatar), findsWidgets);

    // The verb is gone: a face that opens opens the picker, and the chevron
    // is all that has to say so.
    expect(find.text('Switch profile'), findsNothing);
  });

  testWidgets('the card does not overflow a narrow screen at large type', (
    tester,
  ) async {
    // 320pt wide — the narrowest phone this ships to — with the system font
    // at double size, which is what used to run "Switch profile" off the row.
    // `tablet_layout_test.dart` pins the other end of the same spectrum.
    await _pumpSettings(
      tester,
      size: const Size(640, 2400),
      textScale: 2,
      profiles: [
        _profile(
          username: 'a-rather-long-account-name',
          baseUrl: 'https://kavita.a-rather-long-hostname.example',
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    // And it met the longest second line it can draw, rather than a short
    // one that would have fitted anything: dot, host, and the release.
    expect(find.textContaining('Kavita 0.9.1.4'), findsOneWidget);
  });

  testWidgets('tapping the card asks for another profile', (tester) async {
    await _pumpSettings(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(container.read(authProvider).activeId, isNotNull);

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();

    // Switching drops the active profile and keeps its key, which is what
    // sends the app back to the picker.
    expect(container.read(authProvider).activeId, isNull);
    expect(container.read(authProvider).profiles, hasLength(1));
  });

  testWidgets('forgetting the active profile sits under its own card', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      profiles: [_profile(), _profile(accountId: 2, username: 'other')],
    );

    final forget = find.text('Forget this profile');
    expect(forget, findsOneWidget);
    // Out of the foot of the screen, where it sat past the licences.
    expect(
      _topOf(tester, forget),
      lessThan(_topOf(tester, find.text('GENERAL'))),
    );
    // And above the other faces, not below them: a destructive button drawn
    // under a list of people reads as acting on the last one, and this one
    // acts on the card at the top.
    expect(
      _topOf(tester, forget),
      lessThan(_topOf(tester, find.text('OTHER PROFILES ON THIS DEVICE'))),
    );
  });

  testWidgets('one heading covers the profiles', (tester) async {
    await _pumpSettings(
      tester,
      profiles: [_profile(), _profile(accountId: 2, username: 'other')],
    );

    expect(find.text('PROFILES'), findsOneWidget);
    expect(find.text('SERVER'), findsNothing);
    // The other profiles keep their own sub-heading inside it.
    expect(find.text('OTHER PROFILES ON THIS DEVICE'), findsOneWidget);
  });

  testWidgets('the two rows that leave say so, and carry the right address', (
    tester,
  ) async {
    final links = MemoryLinks();
    await _pumpSettings(tester, links: links);

    // The chevron means "opens here"; these hand the reader to a browser.
    for (final row in [
      find.widgetWithText(InkWell, 'Source code'),
      find.widgetWithText(InkWell, 'Privacy policy'),
    ]) {
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.open_in_new)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
        findsNothing,
      );
    }
    // The licences still open in the app, and still say so.
    expect(
      find.descendant(
        of: find.widgetWithText(InkWell, 'Licenses'),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Source code'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(links.opened, [
      'https://github.com/rbioteau/patra',
      'https://rbioteau.github.io/patra/privacy.html',
    ]);
  });

  testWidgets('the screen ends on whose work it is', (tester) async {
    await _pumpSettings(tester);

    final copyright = find.text('\u00a9 2026 Romain Bioteau');
    expect(copyright, findsOneWidget);
    // Centred, unlike the rows above it: they line up on the gutter with
    // each other, and this is a signature under the lot. Asserted on the
    // property rather than on painted pixels — the `Text` fills the width
    // either way, so its box says nothing about where the words sit.
    expect(tester.widget<Text>(copyright).textAlign, TextAlign.center);
    // The last thing on the screen, under the licences it follows.
    expect(
      _topOf(tester, copyright),
      greaterThan(_topOf(tester, find.text('Licenses'))),
    );
  });
}
