import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/client_device.dart';
import '../api/client_identity.dart';
import '../api/kavita_client.dart';
import '../api/models.dart';

/// Host part of a server address, for display, falling back to the raw value
/// so a malformed one still names itself in a row or an error message.
String serverHost(String baseUrl) {
  final parsed = Uri.tryParse(baseUrl)?.host ?? '';
  return parsed.isEmpty ? baseUrl : parsed;
}

/// A Kavita server the user has connected to at least once.
///
/// One secret is stored, the account's auth key, so a saved server can be
/// reopened without retyping a password; the password itself is never
/// persisted, and neither is the JWT the key mints. An empty [apiKey] means
/// the entry is remembered but signed out.
class ServerEntry {
  const ServerEntry({
    required this.baseUrl,
    required this.username,
    this.apiKey = '',
    this.token = '',
    this.isAdmin = false,
  });

  final String baseUrl;
  final String username;

  /// The account's Kavita auth key: the whole of what is remembered about
  /// how to be this person.
  ///
  /// It does not expire — the `opds` and `image-only` keys are created with
  /// `ExpiresAtUtc = null` — which is the point: a refresh token dies in
  /// about a day on Kavita's 0.9.0.x line, so a device picked up each evening
  /// would land on "sign in again" nearly every time it was opened
  /// (ADR-0004). Its owner rotating it in Kavita's web UI is what ends it,
  /// and the only signal is a 401.
  final String apiKey;

  /// The JWT for the session in progress. **Never persisted**: it is minted
  /// from [apiKey] on entry and discarded with the session, so it is empty on
  /// every entry loaded from storage.
  final String token;

  /// Whether this account holds Kavita's `Admin` role, as the login response
  /// reported it.
  ///
  /// Persisted rather than asked for again, because a resumed session never
  /// logs in a second time. It is therefore as old as the last sign-in: an
  /// entry saved before this existed, or an account promoted since, reads
  /// false until the next one — which costs an admin a button, and never
  /// offers a non-admin one that could only fail.
  final bool isAdmin;

  /// Whether this server can be opened without asking for a password.
  ///
  /// The auth key and nothing else: [token] is session state, so an entry
  /// just read back from storage always has one and never the other.
  bool get hasCredential => apiKey.isNotEmpty;

  /// Host part of [baseUrl], for display; falls back to the raw value so a
  /// malformed address still labels its row.
  String get host => serverHost(baseUrl);

  ServerEntry copyWith({
    String? username,
    String? apiKey,
    String? token,
    bool? isAdmin,
  }) => ServerEntry(
    baseUrl: baseUrl,
    username: username ?? this.username,
    apiKey: apiKey ?? this.apiKey,
    token: token ?? this.token,
    isAdmin: isAdmin ?? this.isAdmin,
  );

  /// What reaches the keychain — [token] deliberately absent, and read back
  /// as empty by [fromJson].
  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'apiKey': apiKey,
    'isAdmin': isAdmin,
  };

  static ServerEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final baseUrl = json['baseUrl'];
    if (baseUrl is! String || baseUrl.isEmpty) return null;
    return ServerEntry(
      baseUrl: baseUrl,
      username: json['username'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      isAdmin: json['isAdmin'] as bool? ?? false,
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
      if (server.baseUrl == activeUrl && server.hasCredential) return server;
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

    // Migration from the single-server layout shipped earlier. The address is
    // the whole of what makes an entry worth keeping — a server with no key
    // is remembered and signed out, which is a state this app draws, rather
    // than one it forgets. The stored token and refresh token are dropped on
    // the way through: they are the credentials that are no longer kept.
    final baseUrl = values['baseUrl'];
    if (baseUrl == null) return const AuthState();
    final apiKey = values['apiKey'] ?? '';
    final migrated = AuthState(
      servers: [
        ServerEntry(
          baseUrl: baseUrl,
          username: values['username'] ?? '',
          apiKey: apiKey,
        ),
      ],
      // A server that cannot be entered is not the active one.
      activeUrl: apiKey.isEmpty ? null : baseUrl,
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

/// Thrown by [AuthNotifier.resume] when the server refuses the stored auth
/// key, and by nothing else.
///
/// The screen has to tell this apart from every other way a sign-in can fail
/// — it is the one that lands on the password form, and the one whose message
/// must not be `ConnectionFailure`'s "wrong username or password", since no
/// password was sent. `resume` is what saw the 401, so it says so here rather
/// than leaving the screen to infer it from state it did not throw.
class SignInExpired implements Exception {
  const SignInExpired(this.cause);

  /// The 401 underneath, kept so nothing is lost on the way up.
  final DioException cause;

  @override
  String toString() => 'SignInExpired: the server refused the stored auth key';
}

/// Signing in, with whichever [Credential] this is.
typedef SignIn = Future<LoginResult> Function({
  required String baseUrl,
  required String username,
  required Credential credential,
  ClientIdentity identity,
});

/// How [AuthNotifier] signs in.
///
/// A provider rather than a direct call, because entering a remembered server
/// is a request now: without a seam here every test of resuming would need a
/// network, and there is nothing else in this notifier that reaches one.
final signInProvider = Provider<SignIn>((ref) => KavitaClient.login);

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
    final user = await ref.read(signInProvider)(
      baseUrl: url,
      username: username,
      credential: Credential.password(password),
      identity: ref.read(clientIdentityProvider),
    );
    await _enter(url, username, user);
  }

  /// Reopens a saved server, signing in again with its stored auth key.
  ///
  /// No password, and no clock: the key does not expire, so this works
  /// however long the app has been closed. What it costs is one request
  /// before anything else works — hidden behind the launch animation, which
  /// keeps the app mounted from the first frame precisely so its own first
  /// requests are made and answered while the splash plays.
  ///
  /// Three failures, and they are three different facts. A server that
  /// cannot be **reached** is not a credential that has been refused: the
  /// entry is opened anyway on the key it already holds, because offline
  /// there is nothing to ask and nothing to ask it of — what such a session
  /// reads is what it saved, and this is the one failure that does not
  /// throw. A **401** is the key itself being refused, rotated in
  /// Kavita's web UI or belonging to an account that is gone — and it is the
  /// only answer that means that, since Kavita reports every credential-side
  /// failure of this endpoint, `LoginRole` included, as a bare 401. The entry
  /// stays remembered and loses its secret, so the next tap asks for a
  /// password. Anything else (a 500, a proxy answering in Kavita's place)
  /// says nothing about the credential and leaves it alone: throwing away a
  /// working key over a fault that fixes itself would cost a password for
  /// nothing. Those two throw — the 401 as [SignInExpired], which is the
  /// screen's cue to ask for a password, and everything else as it came.
  Future<void> resume(ServerEntry server) async {
    if (!server.hasCredential) return;
    final LoginResult user;
    try {
      user = await ref.read(signInProvider)(
        baseUrl: server.baseUrl,
        username: server.username,
        credential: Credential.authKey(server.apiKey),
        identity: ref.read(clientIdentityProvider),
      );
    } on DioException catch (error) {
      if (KavitaClient.isUnreachable(error)) {
        await _commit(
          AuthState(servers: state.servers, activeUrl: server.baseUrl),
        );
        return;
      }
      if (error.response?.statusCode == 401) {
        await _dropCredential(server);
        throw SignInExpired(error);
      }
      rethrow;
    }
    await _enter(server.baseUrl, server.username, user);
  }

  /// Makes [url] the active server on the strength of a sign-in that just
  /// succeeded, whichever credential paid for it.
  Future<void> _enter(String url, String username, LoginResult user) async {
    final entry = ServerEntry(
      baseUrl: url,
      username: user.username.isEmpty ? username : user.username,
      apiKey: user.apiKey,
      token: user.token,
      isAdmin: user.isAdmin,
    );
    await _commit(AuthState(servers: _upsert(entry), activeUrl: url));
  }

  /// Keeps the server and forgets how to be this person on it.
  Future<void> _dropCredential(ServerEntry server) => _commit(
    AuthState(
      servers: _upsert(
        ServerEntry(baseUrl: server.baseUrl, username: server.username),
      ),
      activeUrl: state.activeUrl == server.baseUrl ? null : state.activeUrl,
    ),
  );

  /// Called by the API client once it has minted a fresh JWT from the key.
  /// The new token is session state like the one it replaces — this only
  /// puts it where the client provider will read it next.
  Future<void> updateToken(String token) async {
    final active = state.active;
    if (active == null) return;
    await _commit(
      AuthState(
        servers: _upsert(active.copyWith(token: token)),
        activeUrl: state.activeUrl,
      ),
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

  /// Goes back to the server list while keeping each server's auth key, so
  /// switching back is a single tap.
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

/// How a provider that talks to the server retries a failure.
///
/// Riverpod 3 retries a failed provider on its own, with exponential backoff
/// and **no ceiling**. That is right for a blip and wrong for being offline:
/// a device with no network will not have one 200ms later, and every attempt
/// drops the provider back to `AsyncLoading`, so the screen returns to its
/// skeleton instead of settling on the offline state the app already knows
/// how to show. Measured before this existed: opening the home screen with
/// no network made 3 requests, then 33 within the minute, for ever — which
/// is what an offline start looked like, and why the device redrew forever.
///
/// Bounded instead: three attempts inside ~600ms catch a momentary blip, and
/// then it stops. Coming back online is the user's move — pull to refresh,
/// or the retry button — rather than a timer nobody can see.
///
/// Pass it as `retry:` to every provider that reaches the network.
Duration? serverRetry(int retryCount, Object error) =>
    retryCount >= 2 ? null : Duration(milliseconds: 200 * (1 << retryCount));

/// A live check that the server is actually there, behind the indicator on
/// the settings screen.
///
/// [offlineProvider] cannot answer this on its own: it only moves when a
/// request *fails*, so a device that loses its connection while sitting on a
/// screen keeps whatever the last request said. That is how a dot came to
/// mean "nobody has told us otherwise" while showing "connected".
///
/// The call runs through the client, so its own success or failure feeds
/// [offlineProvider] in passing and the banner agrees with the dot.
final serverReachableProvider = FutureProvider.autoDispose<bool>(
  // Like every other provider that reaches the network. Without it, anything
  // that escapes the catch below — the `StateError` from a client with no
  // session, say — hands the provider to Riverpod's unbounded retry, which
  // is the loop `serverRetry` exists to stop.
  retry: serverRetry,
  (ref) async {
    final client = ref.watch(kavitaClientProvider);
    try {
      await client.health();
      return true;
    } on DioException catch (error) {
      // A server that answers at all is reachable, whatever it answers: a
      // 500 from Kavita or a 404 from a proxy in front of it is not the same
      // fact as a device with no network, and only the second is what a
      // connectivity dot is about. `KavitaClient.isUnreachable` is the line
      // the reachability interceptor draws, so the dot and the banner agree.
      return !KavitaClient.isUnreachable(error);
    }
  },
);

/// Which release of Kavita the active server is running, or null if it will
/// not say.
///
/// Deliberately a second request beside [serverReachableProvider] rather than
/// one that answers both questions, even though `/api/Plugin/version` shares
/// every property that made `/api/Health` the right probe. Two reasons, and
/// both are about the dot rather than about the version:
///
/// The auth key this endpoint takes can expire independently of the session,
/// and an expired one answers **401 from a server that is plainly up**. Fold
/// the two together and a credential paints the dot red and tells someone
/// their server is unreachable.
///
/// And [serverReachableProvider] deliberately calls a 500 or a 404
/// "reachable" — a server that answers at all is there, whatever it answers.
/// A version fetch cannot make that distinction, because those are exactly
/// the answers that carry no version.
///
/// So a failure here must never be able to move the dot. Null is every kind
/// of "we do not know": no answer yet, an old server that 404s the endpoint,
/// an expired key. The settings card renders all of them as no line at all,
/// which is why nothing here needs to tell them apart.
final serverVersionProvider = FutureProvider.autoDispose<String?>(
  retry: serverRetry,
  (ref) async {
    final client = ref.watch(kavitaClientProvider);
    try {
      return await client.serverVersion();
    } on DioException {
      return null;
    }
  },
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
      username: session.username,
      apiKey: session.apiKey,
      identity: ref.read(clientIdentityProvider),
      onTokenRenewed: (token) =>
          ref.read(authProvider.notifier).updateToken(token),
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
