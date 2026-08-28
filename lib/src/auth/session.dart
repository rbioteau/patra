import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/kavita_client.dart';

class Session {
  const Session({
    required this.baseUrl,
    required this.username,
    required this.token,
    required this.refreshToken,
    required this.apiKey,
  });

  final String baseUrl;
  final String username;
  final String token;
  final String refreshToken;
  final String apiKey;

  Session copyWith({String? token, String? refreshToken}) => Session(
    baseUrl: baseUrl,
    username: username,
    token: token ?? this.token,
    refreshToken: refreshToken ?? this.refreshToken,
    apiKey: apiKey,
  );
}

/// Persists the session in the platform keychain/keystore.
class SessionStorage {
  static const _storage = FlutterSecureStorage();

  static Future<Session?> load() async {
    final Map<String, String> values;
    try {
      values = await _storage.readAll();
    } on Exception {
      // Unreadable keystore (device restore, keystore corruption…): fall
      // back to the login screen rather than crash-looping at startup.
      return null;
    }
    final baseUrl = values['baseUrl'];
    final token = values['token'];
    if (baseUrl == null || token == null) return null;
    return Session(
      baseUrl: baseUrl,
      username: values['username'] ?? '',
      token: token,
      refreshToken: values['refreshToken'] ?? '',
      apiKey: values['apiKey'] ?? '',
    );
  }

  static Future<void> save(Session session) async {
    await _storage.write(key: 'baseUrl', value: session.baseUrl);
    await _storage.write(key: 'username', value: session.username);
    await _storage.write(key: 'token', value: session.token);
    await _storage.write(key: 'refreshToken', value: session.refreshToken);
    await _storage.write(key: 'apiKey', value: session.apiKey);
  }

  static Future<void> clear() => _storage.deleteAll();
}

/// Session restored from storage before the app started; injected in main().
final initialSessionProvider = Provider<Session?>((ref) => null);

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() => ref.read(initialSessionProvider);

  Future<void> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final normalized = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final user = await KavitaClient.login(
      baseUrl: normalized,
      username: username,
      password: password,
    );
    final session = Session(
      baseUrl: normalized,
      username: user.username,
      token: user.token,
      refreshToken: user.refreshToken,
      apiKey: user.apiKey,
    );
    await SessionStorage.save(session);
    state = session;
  }

  /// Called by the API client after a successful token refresh.
  Future<void> updateTokens({
    required String token,
    required String refreshToken,
  }) async {
    final current = state;
    if (current == null) return;
    final session = current.copyWith(token: token, refreshToken: refreshToken);
    await SessionStorage.save(session);
    state = session;
  }

  Future<void> logout() async {
    await SessionStorage.clear();
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(
  SessionNotifier.new,
);

/// Kept across rebuilds so screens still unmounting after a logout get a
/// usable (if doomed) client instead of a build-time crash, and so a
/// replaced client can be closed.
KavitaClient? _lastClient;

/// The API client for the current session. Screens behind the login redirect
/// can assume a session exists.
///
/// Watches only the session's identity (server + user), NOT its tokens: the
/// client patches its own tokens on refresh, and rebuilding here would
/// invalidate every data provider mid-use for a routine refresh.
final kavitaClientProvider = Provider<KavitaClient>(
  // The no-session StateError is control flow, not a transient failure:
  // opt out of Riverpod 3's automatic retry with backoff.
  retry: (retryCount, error) => null,
  (ref) {
    final identity = ref.watch(
      sessionProvider.select((s) => s == null ? null : (s.baseUrl, s.apiKey)),
    );
    if (identity == null) {
      // Logout in progress: the router is redirecting, but watching screens
      // may rebuild once more before unmounting.
      final previous = _lastClient;
      if (previous != null) return previous;
      throw StateError('No active session');
    }
    final session = ref.read(sessionProvider)!;
    final client = KavitaClient(
      baseUrl: session.baseUrl,
      token: session.token,
      refreshToken: session.refreshToken,
      apiKey: session.apiKey,
      onTokensRefreshed: (token, refreshToken) => ref
          .read(sessionProvider.notifier)
          .updateTokens(token: token, refreshToken: refreshToken),
      onSessionExpired: () => ref.read(sessionProvider.notifier).logout(),
    );
    _lastClient?.close();
    _lastClient = client;
    return client;
  },
);
