import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/app.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/session_scope.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/features/library/library_screen.dart';
import 'package:patra/src/features/profiles/profile_picker_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/offline_indicator.dart';

import 'test_support.dart';

/// A server whose shelves say whose session this is.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.series);

  /// The one series this account has on deck.
  final String series;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
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
      '/api/Series/on-deck' => json([
        {
          'id': 5,
          'name': series,
          'libraryId': 1,
          'pages': 200,
          'pagesRead': 40,
        },
      ]),
      _ => json(const <Object>[]),
    };
  }

  @override
  void close({bool force = false}) {}
}

const _shelves = {'romain': 'Blame!', 'lea': 'Nausicaä'};

Profile _profile(String username, int accountId) => Profile(
  baseUrl: 'https://kavita.example',
  accountId: accountId,
  username: username,
  apiKey: 'key-$username',
);

final _romain = _profile('romain', 1);
final _lea = _profile('lea', 2);

/// The two faces on this device, which is also where a sign-in reads back
/// which account it has just been asked for.
final _profiles = [_romain, _lea];

/// Who the client belongs to once nobody is reading: a shelf drawn through it
/// shows neither person's series.
final _nobody = _profile('', 0);

/// Signs in whoever is asking, with a token that names their account.
///
/// The id comes off the profile the device already holds rather than being
/// restated here: a token naming anybody else would resolve onto a *second*
/// profile for the same person, and these tests would then be counting three
/// faces.
Future<LoginResult> _signIn({
  required String baseUrl,
  required String username,
  required Credential credential,
  ClientIdentity identity = const ClientIdentity.unknown(),
}) async {
  final profile = _profiles.firstWhere((p) => p.username == username);
  return LoginResult(
    username: username,
    token: signedToken(profile.accountId!),
    apiKey: profile.apiKey,
  );
}

/// The whole app, under the scope that owns its container — which is the
/// thing under test: these are about what a switch leaves behind.
Widget _app({required List<Profile> profiles, required Directory root}) {
  return SessionScope(
    auth: AuthState(profiles: profiles).atLaunch(),
    overrides: [
      signInProvider.overrideWithValue(_signIn),
      downloadsRootProvider.overrideWithValue(root),
      // Built from the session, as the real provider is: a stub client handed
      // in whole would be the same one in both sessions, and these tests are
      // about telling the two apart.
      kavitaClientProvider.overrideWith((ref) {
        // Falls back rather than throwing, as the real provider does with its
        // doomed client: a session that has ended is recomputed here while
        // the shell it belonged to is still on screen, and a stub that threw
        // would fail the test on the way to the picker rather than say
        // anything about the switch.
        final session = ref.watch(sessionProvider) ?? _nobody;
        final client = KavitaClient(
          baseUrl: session.baseUrl,
          token: session.token,
          username: session.username,
          apiKey: session.apiKey,
        );
        final adapter = _Adapter(_shelves[session.username] ?? '?');
        client.httpClient.httpClientAdapter = adapter;
        client.bareHttpClient.httpClientAdapter = adapter;
        return client;
      }),
    ],
    child: const PatraApp(),
  );
}

/// A screen with room for the shelves, so nothing overflows mid-test.
Directory _room(WidgetTester tester, String name) {
  mockPathProvider();
  mockSecureStorage();
  final root = Directory.systemTemp.createTempSync(name);
  addTearDown(() => root.deleteSync(recursive: true));
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  return root;
}

/// Whether any of the splash is on screen: it paints the ink, and takes
/// itself out of the tree rather than leaving a transparent overlay behind.
Finder _splash() =>
    find.byWidgetPredicate((w) => w is ColoredBox && w.color == patraInk);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the face on the home bar opens the picker', (tester) async {
    final root = _room(tester, 'patra-switch-face');
    await tester.pumpWidget(_app(profiles: [_romain, _lea], root: root));
    await tester.pumpAndSettle();

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();
    expect(find.text('Blame!'), findsOneWidget);

    // Beside the offline indicator, and it has not taken its place: this one
    // is a face, and being offline is still said in the same bar.
    expect(find.byType(OfflineIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Switch profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePickerScreen), findsOneWidget);
    // Switching keeps every key, so coming back is a tap and not a password.
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('entering another profile starts the app over', (tester) async {
    final root = _room(tester, 'patra-switch-teardown');
    await tester.pumpWidget(_app(profiles: [_romain, _lea], root: root));
    await tester.pumpAndSettle();

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();

    final before = tester.container();
    // A provider that carries the previous person's data and no session of
    // its own: it survives every selective teardown that forgets to name it.
    before.read(selectedLibraryProvider.notifier).select(7);

    await tester.tap(find.byTooltip('Switch profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lea'));
    await tester.pumpAndSettle();

    final after = tester.container();
    expect(after, isNot(same(before)), reason: 'a new container, not a reset');
    expect(
      () => before.read(selectedLibraryProvider),
      throwsStateError,
      reason: 'and the old one is gone rather than merely unused',
    );
    expect(
      after.read(selectedLibraryProvider),
      isNull,
      reason: 'nothing of the previous profile survives the switch',
    );
    // The shelves are this profile's, and the previous one is nowhere.
    expect(find.text('Nausicaä'), findsOneWidget);
    expect(find.text('Blame!'), findsNothing);
  });

  testWidgets('a lone profile still has a face, because it is the way in', (
    tester,
  ) async {
    // Not the tap `atLaunch` spares a single-profile device: that rule is
    // about a cold start. With no sign-out button left, this face is the only
    // way such a device ever gains a second profile — the add slot is on the
    // picker, and this is the door to it.
    final root = _room(tester, 'patra-switch-lone');
    await tester.pumpWidget(_app(profiles: [_romain], root: root));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePickerScreen), findsNothing);
    await tester.tap(find.byTooltip('Switch profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePickerScreen), findsOneWidget);
    expect(find.text('Add a profile'), findsOneWidget);
  });

  testWidgets('Settings removes a profile nobody is signed in as', (
    tester,
  ) async {
    // What makes "profile management lives in Settings" true rather than half
    // true: removing only the active profile would mean signing into each
    // person in turn to tidy up, and a profile nothing can sign into any more
    // could never be removed at all.
    final root = _room(tester, 'patra-switch-other');
    await tester.pumpWidget(_app(profiles: [_romain, _lea], root: root));
    await tester.pumpAndSettle();

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('OTHER PROFILES ON THIS DEVICE'), findsOneWidget);
    expect(find.text('lea'), findsOneWidget);

    await tester.tap(find.byTooltip('Forget'));
    await tester.pumpAndSettle();
    expect(find.text('Forget lea on kavita.example?'), findsOneWidget);
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();

    // Gone, and the session it was removed from is untouched: removing
    // somebody else is not leaving yourself.
    expect(find.text('lea'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Default reading direction'), findsOneWidget);
  });

  testWidgets('removing a profile is in Settings, and needs confirming', (
    tester,
  ) async {
    final root = _room(tester, 'patra-switch-forget');
    await tester.pumpWidget(_app(profiles: [_romain, _lea], root: root));
    await tester.pumpAndSettle();

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final settings = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Forget this profile'),
      300,
      scrollable: settings,
    );
    // Signing out was neither of the two verbs, and it is gone: what used to
    // stand here is the one that removes the profile outright.
    expect(find.text('Sign out'), findsNothing);

    await tester.tap(find.text('Forget this profile'));
    await tester.pumpAndSettle();
    // Named, both halves: this server holds two profiles and one of them is
    // being removed.
    expect(find.text('Forget romain on kavita.example?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget this profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();

    // Signed out of a profile the device no longer holds, with the other one
    // on that server untouched.
    expect(find.byType(ProfilePickerScreen), findsOneWidget);
    expect(find.text('romain'), findsNothing);
    expect(find.text('lea'), findsOneWidget);
  });

  testWidgets('the Downloads tab is the profile\'s own', (tester) async {
    // Two people on one server share every chapter id there is, so a store
    // filed by chapter alone put one person's saved reading in the other's
    // list — readable there, and writing its progress back over theirs.
    final root = _room(tester, 'patra-switch-downloads');
    await saveChapterFixture(
      root,
      _romain.id,
      chapterId: 42,
      seriesName: 'Blame!',
    );
    await saveChapterFixture(
      root,
      _lea.id,
      chapterId: 42,
      seriesName: 'Nausicaä',
    );
    await tester.pumpWidget(_app(profiles: [_romain, _lea], root: root));
    await tester.pumpAndSettle();

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Blame!'), findsOneWidget);
    expect(find.text('Nausicaä'), findsNothing);

    // Back to Home for the face: it is on that bar and nowhere else.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Nausicaä'), findsOneWidget);
    expect(find.text('Blame!'), findsNothing);
  });

  testWidgets('a switch is not a launch', (tester) async {
    final root = _room(tester, 'patra-switch-splash');
    await tester.pumpWidget(_app(profiles: [_romain, _lea], root: root));
    await tester.pumpAndSettle();

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lea'));
    // One frame, not a settle: the whole app is built again here, and the
    // question is whether the frond starts unfurling itself in front of it.
    await tester.pump();

    expect(_splash(), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    // The one frame above leaves the new app's own first requests in flight.
    await tester.pumpAndSettle();
  });
}
