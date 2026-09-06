import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';

import 'test_support.dart';

const _a = ServerEntry(
  baseUrl: 'https://a.example',
  username: 'romain',
  apiKey: 'key-a',
  token: 'token-a',
);
const _b = ServerEntry(
  baseUrl: 'https://b.example',
  username: 'romain',
  apiKey: 'key-b',
  token: 'token-b',
);

/// A stand-in for `/api/Account/login` that records what it was asked with.
class _FakeSignIn {
  _FakeSignIn({this.apiKey = 'key-a', this.fails});

  final String apiKey;

  /// Thrown instead of answering, when set.
  final Object? fails;

  final List<Map<String, String>> calls = [];

  Future<LoginResult> call({
    required String baseUrl,
    required String username,
    required Credential credential,
    ClientIdentity identity = const ClientIdentity.unknown(),
  }) async {
    calls.add({
      'baseUrl': baseUrl,
      'username': username,
      'credential': switch (credential) {
        PasswordCredential(:final value) => 'password $value',
        AuthKeyCredential(:final value) => 'key $value',
      },
    });
    if (fails != null) throw fails!;
    return LoginResult(
      username: username,
      token: 'fresh-token',
      apiKey: apiKey,
      roles: const ['Login'],
    );
  }
}

DioException _refused(int status) => DioException(
  requestOptions: RequestOptions(path: '/api/Account/login'),
  response: Response(
    requestOptions: RequestOptions(path: '/api/Account/login'),
    statusCode: status,
  ),
  type: DioExceptionType.badResponse,
);

DioException get _noNetwork => DioException(
  requestOptions: RequestOptions(path: '/api/Account/login'),
  type: DioExceptionType.connectionError,
);

ProviderContainer _container(AuthState initial, {_FakeSignIn? signIn}) =>
    ProviderContainer.test(
      overrides: [
        initialAuthStateProvider.overrideWithValue(initial),
        if (signIn != null) signInProvider.overrideWithValue(signIn.call),
      ],
    );

void main() {
  // AuthNotifier writes through to secure storage, and one of these paths
  // *awaits* the write before rethrowing — an unmocked keychain never answers
  // on Linux, which reads as a stuck suite rather than a failing test.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockSecureStorage);

  test('only a server holding its auth key counts as a session', () {
    const signedOut = ServerEntry(
      baseUrl: 'https://a.example',
      username: 'romain',
    );
    const state = AuthState(
      servers: [signedOut],
      activeUrl: 'https://a.example',
    );
    expect(state.active, isNull);
    expect(signedOut.hasCredential, isFalse);
    expect(_a.hasCredential, isTrue);
  });

  test('a server read back from storage can still be opened', () {
    // The JWT is session state and is gone; the key is what survives, and it
    // is what says this server opens without a password. Reading a stored
    // entry back is the whole reason `hasCredential` is not about the token.
    final stored = ServerEntry.fromJson(jsonDecode(jsonEncode(_a.toJson())))!;

    expect(stored.token, isEmpty, reason: 'the JWT is never written down');
    expect(stored.apiKey, 'key-a');
    expect(stored.hasCredential, isTrue);
  });

  group('the single-server layout shipped earlier', () {
    test('migrates to a server holding its key', () async {
      mockSecureStorage({
        'baseUrl': 'https://a.example',
        'username': 'romain',
        'token': 'a-stale-jwt',
        'refreshToken': 'a-stale-refresh',
        'apiKey': 'key-a',
      });

      final state = await SessionStorage.load();

      expect(state.servers.single.apiKey, 'key-a');
      expect(state.servers.single.token, isEmpty);
      expect(state.active?.baseUrl, 'https://a.example');
    });

    test('keeps a server with no key, remembered and signed out', () async {
      // The address is the whole of what makes an entry worth keeping, and
      // "remembered but signed out" is a state this app draws. Forgetting the
      // server outright would make someone retype an address they had saved.
      mockSecureStorage({
        'baseUrl': 'https://a.example',
        'username': 'romain',
        'token': 'a-stale-jwt',
      });

      final state = await SessionStorage.load();

      expect(state.servers.single.baseUrl, 'https://a.example');
      expect(state.servers.single.username, 'romain');
      expect(state.servers.single.hasCredential, isFalse);
      expect(state.active, isNull, reason: 'it cannot be entered');
    });
  });

  test('signing in stores the auth key and no other secret', () async {
    final storage = mockSecureStorage();
    final signIn = _FakeSignIn(apiKey: 'key-a');
    final container = _container(const AuthState(), signIn: signIn);

    await container
        .read(authProvider.notifier)
        .login(
          baseUrl: 'https://a.example/',
          username: 'romain',
          password: 'hunter2',
        );

    expect(container.read(sessionProvider)?.token, 'fresh-token');
    final written = jsonDecode(storage['servers']!) as List;
    expect(written.single, {
      'baseUrl': 'https://a.example',
      'username': 'romain',
      'apiKey': 'key-a',
      'isAdmin': false,
    });
  });

  test('resuming signs in with the auth key and no password', () async {
    final signIn = _FakeSignIn(apiKey: 'key-a');
    final container = _container(
      const AuthState(servers: [_a]),
      signIn: signIn,
    );

    await container.read(authProvider.notifier).resume(_a);

    expect(signIn.calls.single, {
      'baseUrl': 'https://a.example',
      'username': 'romain',
      'credential': 'key key-a',
    });
    expect(container.read(sessionProvider)?.token, 'fresh-token');
  });

  test('a key the server refuses leaves the server signed out', () async {
    // The key was rotated in Kavita's web UI, or the account is gone. The
    // server stays in the list, loses its secret, and the next tap asks for
    // a password — which is the only thing that can still get in.
    final container = _container(
      const AuthState(servers: [_a, _b]),
      signIn: _FakeSignIn(fails: _refused(401)),
    );

    // A type of its own, because the screen has to tell this apart from every
    // other way a sign-in fails: it is the one that asks for a password.
    await expectLater(
      container.read(authProvider.notifier).resume(_a),
      throwsA(
        isA<SignInExpired>().having(
          (e) => e.cause.response?.statusCode,
          'the 401 underneath',
          401,
        ),
      ),
    );

    final state = container.read(authProvider);
    expect(state.active, isNull);
    final kept = state.servers.firstWhere((s) => s.baseUrl == _a.baseUrl);
    expect(kept.username, 'romain', reason: 'the server is remembered');
    expect(kept.hasCredential, isFalse, reason: 'a password is needed again');
    expect(
      state.servers.firstWhere((s) => s.baseUrl == _b.baseUrl).apiKey,
      'key-b',
      reason: 'the other server is untouched',
    );
  });

  test('a server that answers badly keeps its key', () async {
    // A 500, or a proxy answering in Kavita's place, says nothing about the
    // credential. Throwing away a working key over it would cost a password
    // for a fault that fixes itself.
    final container = _container(
      const AuthState(servers: [_a]),
      signIn: _FakeSignIn(fails: _refused(500)),
    );

    await expectLater(
      container.read(authProvider.notifier).resume(_a),
      throwsA(isA<DioException>()),
      reason: 'not SignInExpired: nothing was refused',
    );
    expect(container.read(authProvider).servers.single.apiKey, 'key-a');
  });

  test('resuming with no network opens the server anyway', () async {
    // Nothing to ask and nothing to ask it of: what such a session reads is
    // what it saved. The key is already here, so being offline is not the
    // same fact as being refused.
    final container = _container(
      const AuthState(servers: [_a]),
      signIn: _FakeSignIn(fails: _noNetwork),
    );

    await container.read(authProvider.notifier).resume(_a);

    expect(container.read(sessionProvider)?.baseUrl, 'https://a.example');
    expect(container.read(sessionProvider)?.apiKey, 'key-a');
  });

  test('signing out keeps the server but drops its key', () async {
    final container = _container(
      const AuthState(servers: [_a, _b], activeUrl: 'https://a.example'),
    );
    expect(container.read(sessionProvider)?.baseUrl, 'https://a.example');

    await container.read(authProvider.notifier).signOut();

    final state = container.read(authProvider);
    expect(state.active, isNull);
    expect(state.servers, hasLength(2));
    final kept = state.servers.firstWhere(
      (s) => s.baseUrl == 'https://a.example',
    );
    expect(kept.username, 'romain', reason: 'the entry is remembered');
    expect(kept.hasCredential, isFalse, reason: 'the password is needed again');
    // The other server keeps its own credential untouched.
    expect(
      state.servers.firstWhere((s) => s.baseUrl == 'https://b.example').apiKey,
      'key-b',
    );
  });

  test('switching server keeps the key so returning is one tap', () async {
    final signIn = _FakeSignIn(apiKey: 'key-a');
    final container = _container(
      const AuthState(servers: [_a], activeUrl: 'https://a.example'),
      signIn: signIn,
    );

    await container.read(authProvider.notifier).switchServer();
    expect(container.read(sessionProvider), isNull);
    expect(container.read(authProvider).servers.single.hasCredential, isTrue);

    await container.read(authProvider.notifier).resume(_a);
    expect(container.read(sessionProvider)?.token, 'fresh-token');
  });

  test('forgetting the active server clears the session', () async {
    final container = _container(
      const AuthState(servers: [_a, _b], activeUrl: 'https://a.example'),
    );

    await container.read(authProvider.notifier).forget('https://a.example');

    expect(container.read(sessionProvider), isNull);
    expect(
      container.read(authProvider).servers.single.baseUrl,
      'https://b.example',
    );
  });

  test('a renewed token reaches the active server only', () async {
    final container = _container(
      const AuthState(servers: [_a, _b], activeUrl: 'https://a.example'),
    );

    await container.read(authProvider.notifier).updateToken('token-a2');

    final state = container.read(authProvider);
    expect(state.active?.token, 'token-a2');
    expect(state.active?.apiKey, 'key-a', reason: 'identity is unchanged');
    expect(
      state.servers.firstWhere((s) => s.baseUrl == 'https://b.example').token,
      'token-b',
    );
  });

  test('host is what the server list displays', () {
    expect(_a.host, 'a.example');
    expect(
      const ServerEntry(baseUrl: 'http://192.168.1.20:5000', username: '').host,
      '192.168.1.20',
    );
    // A malformed address parses with no host: show it raw rather than blank.
    expect(
      const ServerEntry(baseUrl: 'not a url', username: '').host,
      'not a url',
    );
  });
}
