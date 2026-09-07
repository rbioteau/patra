import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/profiles/profile_picker_screen.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/lock/biometrics.dart';
import 'package:patra/src/lock/profile_lock.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

Profile _profile({
  int accountId = 1,
  String username = 'romain',
  bool isAdmin = false,
  bool ageRestricted = false,
}) => Profile(
  baseUrl: 'https://kavita.example',
  accountId: accountId,
  username: username,
  apiKey: 'key',
  token: 'token',
  isAdmin: isAdmin,
  ageRestricted: ageRestricted,
);

/// A sign-in that answers, and says it was asked. The whole point of the lock
/// is that this is never reached until the PIN has been given.
class _RecordingSignIn {
  final entered = <String>[];

  Future<LoginResult> call({
    required String baseUrl,
    required String username,
    required Credential credential,
    ClientIdentity identity = const ClientIdentity.unknown(),
  }) async {
    entered.add(username);
    return LoginResult(
      username: username,
      token: signedToken(1),
      apiKey: 'key',
    );
  }
}

/// Taps [pin] out on the pad, a digit at a time, as a thumb would.
Future<void> _type(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.widgetWithText(InkWell, digit));
    await tester.pumpAndSettle();
  }
}

Future<_RecordingSignIn> _picker(
  WidgetTester tester, {
  required ProfileLockStore locks,
  Biometrics? biometrics,
  List<Profile>? profiles,
}) async {
  mockPathProvider();
  // A sign-in that succeeds writes the profile back to the keychain, which
  // on a test binding never answers and hangs the pump rather than failing
  // it. Every test here lets one succeed.
  mockSecureStorage();
  final signIn = _RecordingSignIn();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: profiles ?? [_profile()]),
        ),
        profileLockStoreProvider.overrideWithValue(locks),
        biometricsProvider.overrideWithValue(
          biometrics ?? FakeBiometrics(),
        ),
        signInProvider.overrideWithValue(signIn.call),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: patraTheme(),
        home: const ProfilePickerScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return signIn;
}

/// Answers everything, so the settings screen's own probe settles.
class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async =>
      ResponseBody.fromString(
        jsonEncode(const <Object>[]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Future<void> _settings(
  WidgetTester tester, {
  required Profile profile,
  required ProfileLockStore locks,
}) async {
  final root = mockPathProvider();
  mockSecureStorage();
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final client = KavitaClient(
    baseUrl: profile.baseUrl,
    token: 'token',
    username: profile.username,
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _Adapter();
  client.bareHttpClient.httpClientAdapter = _Adapter();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: [profile], activeId: profile.id),
        ),
        kavitaClientProvider.overrideWithValue(client),
        profileLockStoreProvider.overrideWithValue(locks),
        biometricsProvider.overrideWithValue(FakeBiometrics()),
        downloadsRootProvider.overrideWithValue(root),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: patraTheme(),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const romain = 'https://kavita.example#1';

  group('a locked profile on the picker', () {
    testWidgets('says so, before it is tapped', (tester) async {
      await _picker(tester, locks: await lockStore({romain: '1234'}));

      // Marked where a reader choosing between faces is looking, and worded
      // under the name as well — the same pair a refused key gets, because
      // both are a cost the tap is about to have.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('an unlocked one is marked with nothing at all', (
      tester,
    ) async {
      await _picker(tester, locks: await lockStore());

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets('asks for its PIN, and signs in only once it has it', (
      tester,
    ) async {
      final signIn = await _picker(
        tester,
        locks: await lockStore({romain: '1234'}),
      );

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the PIN for romain'), findsOneWidget);
      expect(
        signIn.entered,
        isEmpty,
        reason: 'the key must not be spent before the PIN is given',
      );

      await _type(tester, '1234');

      expect(find.text('Enter the PIN for romain'), findsNothing);
      expect(signIn.entered, ['romain']);
    });

    testWidgets('refuses a wrong PIN and asks again in place', (tester) async {
      final signIn = await _picker(
        tester,
        locks: await lockStore({romain: '1234'}),
      );

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();
      await _type(tester, '9999');

      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(signIn.entered, isEmpty);

      // Nothing is counted and nothing is locked out: what this stands
      // between is family members, and the person mistyping is usually the
      // one it belongs to.
      await _type(tester, '1234');
      expect(signIn.entered, ['romain']);
    });

    testWidgets('is asked with no server at all', (tester) async {
      // The lock is enforced on this device, so being offline changes
      // nothing about it — which is the only way it could work on the train
      // the picker exists for. Nothing here reaches a network: a sign-in
      // that never answers would hang if one were tried.
      final signIn = await _picker(
        tester,
        locks: await lockStore({romain: '1234'}),
      );

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the PIN for romain'), findsOneWidget);
      expect(signIn.entered, isEmpty);
    });

    testWidgets('an unlocked profile is entered on the tap itself', (
      tester,
    ) async {
      final signIn = await _picker(tester, locks: await lockStore());

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter the PIN'), findsNothing);
      expect(signIn.entered, ['romain']);
    });
  });

  group('the device is asked first where it can be', () {
    testWidgets('a recognised face opens the profile with no PIN typed', (
      tester,
    ) async {
      final biometrics = FakeBiometrics(offered: true, recognises: true);
      final signIn = await _picker(
        tester,
        locks: await lockStore({romain: '1234'}),
        biometrics: biometrics,
      );

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      expect(biometrics.prompts, 1);
      expect(signIn.entered, ['romain']);
    });

    testWidgets('a refusal falls back to the PIN, which still opens it', (
      tester,
    ) async {
      final biometrics = FakeBiometrics(offered: true, recognises: false);
      final signIn = await _picker(
        tester,
        locks: await lockStore({romain: '1234'}),
        biometrics: biometrics,
      );

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      expect(biometrics.prompts, 1);
      // The pad is behind the prompt the whole time, so a refusal costs
      // nothing but the digits that were going to be typed anyway.
      expect(find.text('Enter the PIN for romain'), findsOneWidget);
      await _type(tester, '1234');
      expect(signIn.entered, ['romain']);
    });

    testWidgets('a device with no sensor is never asked, and says nothing', (
      tester,
    ) async {
      final biometrics = FakeBiometrics();
      await _picker(
        tester,
        locks: await lockStore({romain: '1234'}),
        biometrics: biometrics,
      );

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      expect(biometrics.prompts, 0);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
    });
  });

  group('the lock in Settings', () {
    testWidgets('says what it does and never claims to protect a lost device', (
      tester,
    ) async {
      await _settings(
        tester,
        profile: _profile(),
        locks: await lockStore(),
      );

      expect(find.text('Lock this profile'), findsOneWidget);
      final explained = tester
          .widget<Text>(
            find.textContaining('keeps the people you share this device with'),
          )
          .data!;
      expect(explained, contains('not protection for a lost or stolen device'));
    });

    testWidgets('is suggested to a profile the server holds back from nothing', (
      tester,
    ) async {
      await _settings(tester, profile: _profile(), locks: await lockStore());

      expect(find.textContaining('Worth doing on a shared device'), findsOne);
    });

    testWidgets('is suggested to an administrator', (tester) async {
      await _settings(
        tester,
        profile: _profile(isAdmin: true, ageRestricted: true),
        locks: await lockStore(),
      );

      expect(find.textContaining('Worth doing on a shared device'), findsOne);
    });

    testWidgets('is never suggested to a restricted profile', (tester) async {
      // The asymmetry is the point (ADR-0003): that account is already held
      // back by the server, and a lock on it would protect nothing.
      await _settings(
        tester,
        profile: _profile(ageRestricted: true),
        locks: await lockStore(),
      );

      expect(find.text('Lock this profile'), findsOneWidget);
      expect(
        find.textContaining('Worth doing on a shared device'),
        findsNothing,
      );
    });

    testWidgets('gives, changes and clears a PIN', (tester) async {
      final locks = await lockStore();
      await _settings(tester, profile: _profile(), locks: locks);

      await tester.tap(find.text('Lock this profile'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a PIN'), findsOneWidget);
      await _type(tester, '1234');
      expect(find.text('Enter it again'), findsOneWidget);
      await _type(tester, '1234');

      expect(locks.lockedIds, contains(romain));
      expect(locks.unlocks(romain, '1234'), isTrue);
      // The suggestion is answered rather than repeated at a locked profile.
      expect(
        find.textContaining('Worth doing on a shared device'),
        findsNothing,
      );

      await tester.tap(find.text('Change the PIN'));
      await tester.pumpAndSettle();
      await _type(tester, '5678');
      await _type(tester, '5678');
      expect(locks.unlocks(romain, '1234'), isFalse);
      expect(locks.unlocks(romain, '5678'), isTrue);

      await tester.tap(find.text('Lock this profile'));
      await tester.pumpAndSettle();
      expect(locks.lockedIds, isNot(contains(romain)));
    });

    testWidgets('goes with the profile when it is removed', (tester) async {
      // A lock outliving the profile it stood in front of would sit in the
      // keychain pointing at nobody — and would lock this same person out on
      // the day they sign back in, behind a PIN nothing remembers asking
      // them to choose.
      final locks = await lockStore({romain: '1234'});
      await _settings(tester, profile: _profile(), locks: locks);

      await tester.tap(find.text('Forget this profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Forget'));
      await tester.pumpAndSettle();

      expect(locks.lockedIds, isNot(contains(romain)));
    });

    testWidgets('two PINs that differ set nothing and start over', (
      tester,
    ) async {
      final locks = await lockStore();
      await _settings(tester, profile: _profile(), locks: locks);

      await tester.tap(find.text('Lock this profile'));
      await tester.pumpAndSettle();
      await _type(tester, '1234');
      await _type(tester, '5678');

      expect(find.text('Those two PINs are different.'), findsOneWidget);
      // Back to the first step: which of the two was mistyped is not
      // knowable, so neither is kept.
      expect(find.text('Choose a PIN'), findsOneWidget);
      expect(locks.lockedIds, isNot(contains(romain)));
    });
  });
}
