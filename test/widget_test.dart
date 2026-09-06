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
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/login/login_screen.dart';
import 'package:patra/src/features/profiles/profile_picker_screen.dart';

import 'test_support.dart';

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
      '/api/Series/currently-reading' => json(const <Object>[]),
      '/api/Series/on-deck' => json([
        {
          'id': 5,
          'name': 'Blame!',
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

final _profile = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 1,
  username: 'romain',
  token: 'token',
  apiKey: 'key',
);

Widget _app({
  AuthState auth = const AuthState(),
  Directory? downloadsRoot,
  SignIn? signIn,
}) {
  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = _StubAdapter();
  client.bareHttpClient.httpClientAdapter = _StubAdapter();

  return ProviderScope(
    overrides: [
      // Through `atLaunch`, as main() does: these tests say what the device
      // remembered, and the app answers with the screen that opens on it.
      initialAuthStateProvider.overrideWithValue(auth.atLaunch),
      kavitaClientProvider.overrideWithValue(client),
      if (signIn != null) signInProvider.overrideWithValue(signIn),
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

  testWidgets('with no remembered profile, the login form is shown', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tests run under the default 'en' locale.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // Fields carry their label above them, in the section-label style.
    expect(find.text('SERVER ADDRESS'), findsOneWidget);
    expect(
      find.text('Leaf by leaf. A reader for your Kavita library.'),
      findsOneWidget,
    );
  });

  testWidgets('a lone profile needing a password lands on its own form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        auth: AuthState(
          // Remembered but signed out: no active session, and no key left.
          profiles: [Profile(baseUrl: 'https://a.example', username: 'rb')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No picker: there is nobody to choose between, and asking a question
    // with one answer is a tap this device never had to make.
    expect(find.byType(ProfilePickerScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    // The address and the name are already here; the password is the whole
    // of what is missing.
    expect(find.text('rb'), findsOneWidget);
    expect(find.text('SERVER ADDRESS'), findsNothing);
    expect(find.text('PASSWORD'), findsOneWidget);
  });

  testWidgets('the last profile needing a password is not a dead end', (
    tester,
  ) async {
    // One profile left, and it is not mine: the form comes up prefilled for
    // somebody else, on an address I may have nothing to do with. Before
    // there was a way out of it — the list this screen replaced carried an
    // add slot — and there has to be one still, or the device is somebody
    // else's for good.
    await tester.pumpWidget(
      _app(
        auth: AuthState(
          profiles: [Profile(baseUrl: 'https://a.example', username: 'lea')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SERVER ADDRESS'), findsNothing);
    await tester.tap(find.text('Use another server'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // A blank form: the address is asked for, and the name went with it —
    // a username from another server names nobody.
    expect(find.text('SERVER ADDRESS'), findsOneWidget);
    expect(find.text('lea'), findsNothing);
  });

  testWidgets('a device with several profiles opens on the picker', (
    tester,
  ) async {
    // The shape this ticket exists for: somebody read last, and on a shared
    // device that is a previous reader rather than the current one.
    await tester.pumpWidget(
      _app(
        auth: AuthState(
          profiles: [
            _profile,
            Profile(
              baseUrl: 'https://kavita.example',
              accountId: 2,
              username: 'lea',
              apiKey: 'key-lea',
            ),
          ],
          activeId: _profile.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePickerScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('romain'), findsOneWidget);
    expect(find.text('lea'), findsOneWidget);
  });

  testWidgets('a lone profile opens in itself even after a switch', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('patra-lone-test');
    addTearDown(() => root.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // `switchProfile` writes "nobody is active" through to the keychain, and
    // a single-profile device has nobody to switch to — so this is what its
    // every start would look like if `atLaunch` did not answer for it.
    await tester.pumpWidget(
      _app(auth: AuthState(profiles: [_profile]), downloadsRoot: root),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePickerScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
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
        auth: AuthState(profiles: [_profile], activeId: _profile.id),
        downloadsRoot: root,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final tab in ['Home', 'Library', 'Downloads', 'Settings']) {
      expect(find.text(tab), findsOneWidget, reason: '$tab tab is present');
    }
    // The home screen's one list rendered what the stub server is serving.
    expect(find.text('ON DECK'), findsOneWidget);
    expect(find.text('Blame!'), findsOneWidget);
    // Nothing to continue, so the hero is absent rather than empty.
    expect(find.text('CONTINUE'), findsNothing);

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
          auth: AuthState(profiles: [_profile], activeId: _profile.id),
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

  group('opening a remembered profile', () {
    final remembered = Profile(
      baseUrl: 'https://kavita.example',
      accountId: 1,
      username: 'romain',
      apiKey: 'the-auth-key',
    );

    /// The other face on the device, so these run on the picker rather than
    /// on the one-profile shortcut past it.
    final other = Profile(
      baseUrl: 'https://kavita.example',
      accountId: 2,
      username: 'lea',
      apiKey: 'key-lea',
    );

    testWidgets('costs one tap and no password', (tester) async {
      final root = Directory.systemTemp.createTempSync('patra-resume-test');
      addTearDown(() => root.deleteSync(recursive: true));
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      Map<String, String>? sentWith;
      await tester.pumpWidget(
        _app(
          auth: AuthState(profiles: [remembered, other]),
          downloadsRoot: root,
          signIn:
              ({
                required String baseUrl,
                required String username,
                required Credential credential,
                ClientIdentity identity = const ClientIdentity.unknown(),
              }) async {
                sentWith = {
                  'username': username,
                  'credential': switch (credential) {
                    PasswordCredential(:final value) => 'password $value',
                    AuthKeyCredential(:final value) => 'key $value',
                  },
                };
                return const LoginResult(
                  username: 'romain',
                  token: 'fresh-token',
                  apiKey: 'the-auth-key',
                );
              },
        ),
      );
      await tester.pumpAndSettle();

      // Both faces open with a tap: neither is marked as wanting a password.
      expect(find.text('Sign in'), findsNothing);
      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      expect(sentWith, {
        'username': 'romain',
        'credential': 'key the-auth-key',
      });
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('asks for the password again once the key is refused', (
      tester,
    ) async {
      // This is the one path here that *awaits* a write: dropping the
      // credential is what the rethrow waits on, and an unmocked keychain
      // never answers on Linux.
      mockSecureStorage();
      await tester.pumpWidget(
        _app(
          auth: AuthState(profiles: [remembered, other]),
          signIn:
              ({
                required String baseUrl,
                required String username,
                required Credential credential,
                ClientIdentity identity = const ClientIdentity.unknown(),
              }) async {
                throw DioException(
                  requestOptions: RequestOptions(path: '/api/Account/login'),
                  response: Response(
                    requestOptions: RequestOptions(path: '/api/Account/login'),
                    statusCode: 401,
                  ),
                  type: DioExceptionType.badResponse,
                );
              },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('romain'));
      // Not `pumpAndSettle`: the form lands with the password field focused,
      // and a blinking cursor is an animation that never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Not the bad-credentials wording: no password was sent, so nothing
      // the person typed was rejected.
      expect(
        find.text(
          'The saved sign-in for romain on kavita.example was refused. '
          'Your password is needed again.',
        ),
        findsOneWidget,
        reason: 'it names the person: a server can hold several profiles',
      );
      // The form is up knowing this person's server and name: the only thing
      // missing is the password, so the address is not asked for at all.
      expect(find.text('SERVER ADDRESS'), findsNothing);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('romain'), findsOneWidget);
    });

    testWidgets('opens anyway when the server cannot be reached', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync('patra-offline-test');
      addTearDown(() => root.deleteSync(recursive: true));
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          auth: AuthState(profiles: [remembered, other]),
          downloadsRoot: root,
          signIn:
              ({
                required String baseUrl,
                required String username,
                required Credential credential,
                ClientIdentity identity = const ClientIdentity.unknown(),
              }) async {
                throw DioException(
                  requestOptions: RequestOptions(path: '/api/Account/login'),
                  type: DioExceptionType.connectionError,
                );
              },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('romain'));
      await tester.pumpAndSettle();

      // What a saved chapter on a train is for: the key is already here, so
      // being offline is not the same fact as being refused.
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  testWidgets('two accounts on one server are two faces', (tester) async {
    // One address, two people, each with their own credential — and the name
    // is what tells them apart, since the host under both would be the same
    // word twice.
    await tester.pumpWidget(
      _app(
        auth: AuthState(
          profiles: [
            _profile,
            Profile(
              baseUrl: 'https://kavita.example',
              accountId: 2,
              username: 'lea',
              apiKey: 'key-lea',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('romain'), findsOneWidget);
    expect(find.text('lea'), findsOneWidget);
    expect(find.text('kavita.example'), findsNothing);
  });

  group('adding a profile from the picker', () {
    /// Opens the picker on [profiles] and taps its add slot.
    Future<void> add(WidgetTester tester, List<Profile> profiles) async {
      await tester.pumpWidget(_app(auth: AuthState(profiles: profiles)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('asks for a name and a password when one server is known', (
      tester,
    ) async {
      await add(tester, [
        _profile,
        Profile(
          baseUrl: 'https://kavita.example',
          accountId: 2,
          username: 'lea',
          apiKey: 'key-lea',
        ),
      ]);

      // Nobody should have to type an address the device already knows —
      // which on a family tablet is every address there is.
      expect(find.text('SERVER ADDRESS'), findsNothing);
      expect(find.text('USERNAME'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      // …and the way out of that assumption, for the second Kavita nobody
      // could otherwise reach.
      expect(find.text('Use another server'), findsOneWidget);
    });

    testWidgets('is a drill-down, so the system back button comes back', (
      tester,
    ) async {
      await add(tester, [
        _profile,
        Profile(
          baseUrl: 'https://kavita.example',
          accountId: 2,
          username: 'lea',
          apiKey: 'key-lea',
        ),
      ]);
      expect(find.byType(LoginScreen), findsOneWidget);

      // What Android's back button does. Reached with `go` this used to
      // leave Patra altogether, which is the failure CLAUDE.md's rule about
      // push and go is written to prevent.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePickerScreen), findsOneWidget);
      expect(find.text('Add a profile'), findsOneWidget);
    });

    testWidgets('asks for the address too when several servers are known', (
      tester,
    ) async {
      await add(tester, [
        _profile,
        Profile(
          baseUrl: 'https://other.example',
          accountId: 1,
          username: 'romain',
          apiKey: 'key-other',
        ),
      ]);

      expect(find.text('SERVER ADDRESS'), findsOneWidget);
      expect(find.text('USERNAME'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
    });
  });

  group('the server address field refuses what dio could not use', () {
    /// Types an address and submits; returns with the form settled.
    Future<void> submit(WidgetTester tester, String address) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), address);
      await tester.enterText(fields.at(1), 'romain');
      await tester.enterText(fields.at(2), 'hunter2');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }

    const invalid = 'Enter a full address, starting with http:// or https://';

    testWidgets('a host with a port parses as a scheme, and is caught', (
      tester,
    ) async {
      // `Uri.tryParse('kavita.local:5000')` reports hasScheme = true with a
      // *scheme* of "kavita.local", so the old check passed it to dio, which
      // failed later with something nobody could act on.
      await submit(tester, 'kavita.local:5000');
      expect(find.text(invalid), findsOneWidget);
    });

    testWidgets('a scheme we cannot speak, and a scheme with no host', (
      tester,
    ) async {
      for (final address in ['ftp://kavita.lan', 'http://', 'notaurl']) {
        await submit(tester, address);
        expect(find.text(invalid), findsOneWidget, reason: address);
      }
    });

    testWidgets('a local server on plain http is a valid address', (
      tester,
    ) async {
      await submit(tester, 'http://192.168.1.10:5000');

      expect(find.text(invalid), findsNothing);
      // It got as far as the network, which in a test answers 400 — so the
      // screen shows the classified message rather than a dio dump.
      expect(find.textContaining('DioException'), findsNothing);
      expect(
        find.textContaining('192.168.1.10'),
        findsWidgets,
        reason: 'the failure should name the server that was tried',
      );
    });

    testWidgets('the form says cleartext is allowed', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('can use http://'),
        findsOneWidget,
        reason: 'nothing else on this screen says a local server may be http',
      );
    });
  });
}
