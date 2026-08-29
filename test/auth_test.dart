import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/auth/session.dart';

const _a = ServerEntry(
  baseUrl: 'https://a.example',
  username: 'romain',
  token: 'token-a',
  refreshToken: 'refresh-a',
  apiKey: 'key-a',
);
const _b = ServerEntry(
  baseUrl: 'https://b.example',
  username: 'romain',
  token: 'token-b',
  refreshToken: 'refresh-b',
  apiKey: 'key-b',
);

ProviderContainer _container(AuthState initial) => ProviderContainer.test(
  overrides: [initialAuthStateProvider.overrideWithValue(initial)],
);

void main() {
  // AuthNotifier writes through to secure storage, which needs the binding;
  // the platform channel then fails harmlessly and is swallowed.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only a server with tokens counts as an active session', () {
    const signedOut = ServerEntry(
      baseUrl: 'https://a.example',
      username: 'romain',
    );
    const state = AuthState(
      servers: [signedOut],
      activeUrl: 'https://a.example',
    );
    expect(state.active, isNull);
    expect(signedOut.hasSession, isFalse);
    expect(_a.hasSession, isTrue);
  });

  test('signing out keeps the server but drops its tokens', () async {
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
    expect(kept.hasSession, isFalse, reason: 'the password is needed again');
    // The other server keeps its own session untouched.
    expect(
      state.servers.firstWhere((s) => s.baseUrl == 'https://b.example').token,
      'token-b',
    );
  });

  test('switching server keeps tokens so returning is one tap', () async {
    final container = _container(
      const AuthState(servers: [_a], activeUrl: 'https://a.example'),
    );

    await container.read(authProvider.notifier).switchServer();
    expect(container.read(sessionProvider), isNull);
    expect(container.read(authProvider).servers.single.hasSession, isTrue);

    await container.read(authProvider.notifier).resume(_a);
    expect(container.read(sessionProvider)?.token, 'token-a');
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

  test('refreshed tokens are stored on the active server only', () async {
    final container = _container(
      const AuthState(servers: [_a, _b], activeUrl: 'https://a.example'),
    );

    await container
        .read(authProvider.notifier)
        .updateTokens(token: 'token-a2', refreshToken: 'refresh-a2');

    final state = container.read(authProvider);
    expect(state.active?.token, 'token-a2');
    expect(state.active?.refreshToken, 'refresh-a2');
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
