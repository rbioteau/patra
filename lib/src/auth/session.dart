import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/client_device.dart';
import '../api/client_identity.dart';
import '../api/kavita_client.dart';

/// A Kavita server the user has connected to at least once.
///
/// Tokens are stored so a saved server can be reopened without retyping a
/// password; the password itself is never persisted. An empty [token] means
/// the entry is remembered but signed out.
class ServerEntry {
  const ServerEntry({
    required this.baseUrl,
    required this.username,
    this.token = '',
    this.refreshToken = '',
    this.apiKey = '',
  });

  final String baseUrl;
  final String username;
  final String token;
  final String refreshToken;
  final String apiKey;

  bool get hasSession => token.isNotEmpty;

  /// Host part of [baseUrl], for display; falls back to the raw value so a
  /// malformed address still labels its row.
  String get host {
    final parsed = Uri.tryParse(baseUrl)?.host ?? '';
    return parsed.isEmpty ? baseUrl : parsed;
  }

  ServerEntry copyWith({
    String? username,
    String? token,
    String? refreshToken,
    String? apiKey,
  }) => ServerEntry(
    baseUrl: baseUrl,
    username: username ?? this.username,
    token: token ?? this.token,
    refreshToken: refreshToken ?? this.refreshToken,
    apiKey: apiKey ?? this.apiKey,
  );

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'token': token,
    'refreshToken': refreshToken,
    'apiKey': apiKey,
  };

  static ServerEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final baseUrl = json['baseUrl'];
    if (baseUrl is! String || baseUrl.isEmpty) return null;
    return ServerEntry(
      baseUrl: baseUrl,
      username: json['username'] as String? ?? '',
      token: json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
    );
  }
}

/// The active server, once it holds a live session.
typedef Session = ServerEntry;

class AuthState {
  const AuthState({this.servers = const [], this.activeUrl});

  final List<ServerEntry> servers;
  final String? activeUrl;

  /// Null while signed out, which is what the router redirect keys off.
  Session? get active {
    for (final server in servers) {
      if (server.baseUrl == activeUrl && server.hasSession) return server;
    }
    return null;
  }
}

/// Persists servers in the platform keychain/keystore.
class SessionStorage {
  static const _storage = FlutterSecureStorage();
  static const _serversKey = 'servers';
  static const _activeKey = 'activeServer';

  static Future<AuthState> load() async {
    final Map<String, String> values;
    try {
      values = await _storage.readAll();
    } on Exception {
      // Unreadable keystore (device restore, keystore corruption…): fall
      // back to the login screen rather than crash-looping at startup.
      return const AuthState();
    }

    final raw = values[_serversKey];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        final servers = <ServerEntry>[
          if (decoded is List)
            for (final entry in decoded) ?ServerEntry.fromJson(entry),
        ];
        return AuthState(servers: servers, activeUrl: values[_activeKey]);
      } on FormatException {
        return const AuthState();
      }
    }

    // Migration from the single-server layout shipped earlier.
    final baseUrl = values['baseUrl'];
    final token = values['token'];
    if (baseUrl == null || token == null) return const AuthState();
    final migrated = AuthState(
      servers: [
        ServerEntry(
          baseUrl: baseUrl,
          username: values['username'] ?? '',
          token: token,
          refreshToken: values['refreshToken'] ?? '',
          apiKey: values['apiKey'] ?? '',
        ),
      ],
      activeUrl: baseUrl,
    );
    await save(migrated);
    return migrated;
  }

  static Future<void> save(AuthState state) async {
    try {
      await _storage.write(
        key: _serversKey,
        value: jsonEncode([for (final s in state.servers) s.toJson()]),
      );
      final active = state.activeUrl;
      if (active == null) {
        await _storage.delete(key: _activeKey);
      } else {
        await _storage.write(key: _activeKey, value: active);
      }
    } on Exception {
      // A write we cannot make is not worth losing the running session over.
    }
  }
}

/// Auth state restored from storage before the app started; injected in main().
final initialAuthStateProvider = Provider<AuthState>(
  (ref) => const AuthState(),
);

/// How the app identifies itself to a server; resolved before the app started
/// and injected in main(). Unidentified by default, which is what tests get.
final clientIdentityProvider = Provider<ClientIdentity>(
  (ref) => const ClientIdentity.unknown(),
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => ref.read(initialAuthStateProvider);

  static String _normalize(String baseUrl) =>
      baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// Authenticates against [baseUrl] and makes it the active server.
  Future<void> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final url = _normalize(baseUrl);
    final user = await KavitaClient.login(
      baseUrl: url,
      username: username,
      password: password,
      identity: ref.read(clientIdentityProvider),
    );
    final entry = ServerEntry(
      baseUrl: url,
      username: user.username.isEmpty ? username : user.username,
      token: user.token,
      refreshToken: user.refreshToken,
      apiKey: user.apiKey,
    );
    await _commit(AuthState(servers: _upsert(entry), activeUrl: url));
  }

  /// Reopens a saved server that still holds tokens.
  Future<void> resume(ServerEntry server) async {
    if (!server.hasSession) return;
    await _commit(AuthState(servers: state.servers, activeUrl: server.baseUrl));
  }

  /// Called by the API client after a successful token refresh.
  Future<void> updateTokens({
    required String token,
    required String refreshToken,
  }) async {
    final active = state.active;
    if (active == null) return;
    final updated = active.copyWith(token: token, refreshToken: refreshToken);
    await _commit(
      AuthState(servers: _upsert(updated), activeUrl: state.activeUrl),
    );
  }

  /// Leaves the current server without forgetting it: the entry keeps its
  /// address and username, and asks for a password next time.
  Future<void> signOut() async {
    final active = state.active;
    final servers = active == null
        ? state.servers
        : _upsert(
            ServerEntry(baseUrl: active.baseUrl, username: active.username),
          );
    await _commit(AuthState(servers: servers, activeUrl: null));
  }

  /// Goes back to the server list while keeping tokens, so switching back is
  /// a single tap.
  Future<void> switchServer() async {
    await _commit(AuthState(servers: state.servers, activeUrl: null));
  }

  Future<void> forget(String baseUrl) async {
    final servers = [
      for (final server in state.servers)
        if (server.baseUrl != baseUrl) server,
    ];
    await _commit(
      AuthState(
        servers: servers,
        activeUrl: state.activeUrl == baseUrl ? null : state.activeUrl,
      ),
    );
  }

  List<ServerEntry> _upsert(ServerEntry entry) => [
    entry,
    for (final server in state.servers)
      if (server.baseUrl != entry.baseUrl) server,
  ];

  Future<void> _commit(AuthState next) async {
    state = next;
    await SessionStorage.save(next);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// The live session, or null while signed out.
final sessionProvider = Provider<Session?>(
  (ref) => ref.watch(authProvider).active,
);

/// True once a request failed to reach the server; reset by the next success.
/// Drives the offline banner and the greying-out of unsaved chapters.
final offlineProvider = NotifierProvider<OfflineNotifier, bool>(
  OfflineNotifier.new,
);

class OfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool offline) {
    if (state != offline) state = offline;
  }
}

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
      identity: ref.read(clientIdentityProvider),
      onTokensRefreshed: (token, refreshToken) => ref
          .read(authProvider.notifier)
          .updateTokens(token: token, refreshToken: refreshToken),
      onSessionExpired: () => ref.read(authProvider.notifier).signOut(),
      onReachabilityChanged: (reachable) =>
          ref.read(offlineProvider.notifier).set(!reachable),
    );
    _lastClient?.close();
    _lastClient = client;
    // Once per session, not per request: naming the device is cosmetic and the
    // server has better things to do than field an identity reminder behind
    // every cover.
    unawaited(announceDevice(client));
    return client;
  },
);
