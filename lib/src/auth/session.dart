import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/account_id.dart';
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

/// One person's Kavita account on one server — a **server** is an address, and
/// a profile is somebody on it.
///
/// A device holds several, and several of them can share one address: that is
/// what a family tablet is. Everything the *server* owns then comes out right
/// by construction — reading progress, library access and age restriction are
/// kept per account and cannot be divided any other way (ADR-0003) — but
/// nothing the **device** owns is scoped yet: saved chapters are still filed
/// by chapter id alone, so two profiles on one server currently share one
/// offline library. That is #13, and until it lands this class is the only
/// half of the separation that exists.
///
/// One secret is stored, the account's auth key, so a profile can be reopened
/// without retyping a password; the password itself is never persisted, and
/// neither is the JWT the key mints. An empty [apiKey] means the profile is
/// remembered but signed out.
class Profile {
  const Profile({
    required this.baseUrl,
    required this.username,
    this.accountId,
    this.apiKey = '',
    this.token = '',
    this.isAdmin = false,
  });

  final String baseUrl;

  /// Kavita's own id for this account, read out of the JWT the session was
  /// minted with (`accountIdFrom`) rather than asked for — so it is there on a
  /// resume and not only on the sign-in that first learned it.
  ///
  /// Null only where a token carried no readable one; [id] says what that
  /// costs.
  final int? accountId;

  /// What the server calls this person, for the row and for the sign-in body.
  /// A label rather than an identity: it can change on the server, and [id]
  /// is deliberately built without it.
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
  /// every profile loaded from storage.
  final String token;

  /// Whether this account holds Kavita's `Admin` role, as the login response
  /// reported it.
  ///
  /// Persisted rather than asked for again, because a resumed session never
  /// logs in a second time. It is therefore as old as the last sign-in: a
  /// profile saved before this existed, or an account promoted since, reads
  /// false until the next one — which costs an admin a button, and never
  /// offers a non-admin one that could only fail.
  final bool isAdmin;

  /// Which profile this is, and the only thing anything else keys on.
  ///
  /// The normalized address plus Kavita's id for the account, because a user
  /// id is only unique on the server that issued it: `https://a.example#3`.
  /// The **username is deliberately not part of it** — someone who renames
  /// themselves in Kavita is the same person, and has to be recognised rather
  /// than added a second time.
  ///
  /// Where a token carried no readable id the name stands in
  /// (`https://a.example#@romain`), so such a device still remembers one
  /// profile per person rather than one per sign-in. What that costs is
  /// exactly the rename this key exists to survive, and it is accepted: a
  /// real Kavita signs `nameid` on every token it issues, so this is a guard
  /// and not a path.
  String get id => '$baseUrl#${accountId ?? '@${username.toLowerCase()}'}';

  /// Whether this profile can be entered without asking for a password.
  ///
  /// The auth key and nothing else: [token] is session state, so a profile
  /// just read back from storage always has one and never the other.
  bool get hasCredential => apiKey.isNotEmpty;

  /// What names this profile on screen: the person, falling back to the host
  /// where there is no name to show. One definition, because a row and the
  /// dialog that removes it have to call the same profile the same thing.
  String get displayName => username.isEmpty ? host : username;

  /// Host part of [baseUrl], for display; falls back to the raw value so a
  /// malformed address still labels its row.
  String get host => serverHost(baseUrl);

  /// A copy with the session state and the label changed. [baseUrl] and
  /// [accountId] are not among them on purpose: they are the identity, and
  /// something that changed them would be a different profile.
  Profile copyWith({
    String? username,
    String? apiKey,
    String? token,
    bool? isAdmin,
  }) => Profile(
    baseUrl: baseUrl,
    accountId: accountId,
    username: username ?? this.username,
    apiKey: apiKey ?? this.apiKey,
    token: token ?? this.token,
    isAdmin: isAdmin ?? this.isAdmin,
  );

  /// What reaches the keychain — [token] deliberately absent, and read back
  /// as empty by [fromJson]. [id] is absent too: it is derived from the two
  /// fields above it, so there is no way for a stored key to disagree with
  /// the profile it belongs to.
  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'accountId': accountId,
    'username': username,
    'apiKey': apiKey,
    'isAdmin': isAdmin,
  };

  /// Defensive to the last field, and not out of habit: this is read from
  /// `main()` **before** `runApp`, so a value of the wrong type would throw a
  /// `TypeError` — an `Error`, which no `on Exception` up the chain catches —
  /// and a single bad row in the keychain would fail every start of the app
  /// for good. A row that cannot be read is a profile that has to be signed
  /// into again; it is never a device that cannot open Patra.
  static Profile? fromJson(Object? json) {
    if (json is! Map) return null;
    final baseUrl = json['baseUrl'];
    if (baseUrl is! String || baseUrl.isEmpty) return null;
    final accountId = json['accountId'];
    return Profile(
      baseUrl: baseUrl,
      accountId: accountId is int ? accountId : int.tryParse('$accountId'),
      username: json['username'] is String ? json['username'] as String : '',
      apiKey: json['apiKey'] is String ? json['apiKey'] as String : '',
      isAdmin: json['isAdmin'] == true,
    );
  }
}

/// The profile the app is currently reading as, once it holds a live session.
typedef Session = Profile;

class AuthState {
  const AuthState({this.profiles = const [], this.activeId});

  final List<Profile> profiles;

  /// [Profile.id] of the profile being read as, or null while signed out.
  final String? activeId;

  /// Null while signed out, which is what the router redirect keys off.
  Session? get active {
    for (final profile in profiles) {
      if (profile.id == activeId && profile.hasCredential) return profile;
    }
    return null;
  }
}

/// Persists profiles in the platform keychain/keystore.
class SessionStorage {
  static const _storage = FlutterSecureStorage();
  static const _profilesKey = 'profiles';
  static const _activeKey = 'activeProfile';

  /// What the two layouts before this one wrote: a list of servers keyed by
  /// address, and before that a single server spread over five keys.
  ///
  /// **Deleted on first load and never read.** Neither can say which *account*
  /// its key belongs to — that id only ever arrives in a token, and no layout
  /// kept one — so a migrated profile would carry the name-based fallback id
  /// and be created a second time under its real id at its very next sign-in,
  /// leaving a row nothing would ever enter again. Deleting is also the safer
  /// half of the choice: each of these holds an auth key, and an auth key is a
  /// whole Kavita account (ADR-0004), so one nothing will ever use again has
  /// no business sitting in the keychain. What that costs is the whole row and
  /// not merely its secret: the address and the name go with it, so every
  /// server is found and typed once more. Keeping them and dropping only the
  /// key would land in the "remembered but signed out" state this app already
  /// draws — and it would mean reading a layout this one is defined as never
  /// reading, for a device that has been through one upgrade.
  static const _retiredKeys = [
    'servers',
    'activeServer',
    'baseUrl',
    'username',
    'apiKey',
    'token',
    'refreshToken',
  ];

  static Future<AuthState> load() async {
    final Map<String, String> values;
    try {
      values = await _storage.readAll();
    } on Exception {
      // Unreadable keystore (device restore, keystore corruption…): fall
      // back to the login screen rather than crash-looping at startup.
      return const AuthState();
    }

    await _forgetRetired(values);

    final raw = values[_profilesKey];
    if (raw == null) return const AuthState();
    try {
      final decoded = jsonDecode(raw);
      return AuthState(
        profiles: [
          if (decoded is List)
            for (final profile in decoded) ?Profile.fromJson(profile),
        ],
        activeId: values[_activeKey],
      );
    } on FormatException {
      return const AuthState();
    }
  }

  /// Deletes what the earlier layouts left behind, once, on the first load
  /// that finds any of it. A keychain we cannot write to is not worth failing
  /// a startup over — the keys are dead either way, and the next load tries
  /// again.
  static Future<void> _forgetRetired(Map<String, String> values) async {
    for (final key in _retiredKeys) {
      if (!values.containsKey(key)) continue;
      try {
        await _storage.delete(key: key);
      } on Exception {
        // Nothing reads them; leaving one behind changes nothing this run.
      }
    }
  }

  static Future<void> save(AuthState state) async {
    try {
      await _storage.write(
        key: _profilesKey,
        value: jsonEncode([for (final p in state.profiles) p.toJson()]),
      );
      final active = state.activeId;
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
/// A provider rather than a direct call, because entering a remembered profile
/// is a request now: without a seam here every test of resuming would need a
/// network, and there is nothing else in this notifier that reaches one.
final signInProvider = Provider<SignIn>((ref) => KavitaClient.login);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => ref.read(initialAuthStateProvider);

  static String _normalize(String baseUrl) =>
      baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// Signs in with a password, and makes whoever that turns out to be the
  /// active profile.
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

  /// Reopens a remembered profile, signing in again with its stored auth key.
  ///
  /// No password, and no clock: the key does not expire, so this works
  /// however long the app has been closed. What it costs is one request
  /// before anything else works — hidden behind the launch animation, which
  /// keeps the app mounted from the first frame precisely so its own first
  /// requests are made and answered while the splash plays.
  ///
  /// Three failures, and they are three different facts. A server that
  /// cannot be **reached** is not a credential that has been refused: the
  /// profile is entered anyway on the key it already holds, because offline
  /// there is nothing to ask and nothing to ask it of — what such a session
  /// reads is what it saved, and this is the one failure that does not
  /// throw. A **401** is the key itself being refused, rotated in
  /// Kavita's web UI or belonging to an account that is gone — and it is the
  /// only answer that means that, since Kavita reports every credential-side
  /// failure of this endpoint, `LoginRole` included, as a bare 401. The
  /// profile stays remembered and loses its secret, so the next tap asks for a
  /// password. Anything else (a 500, a proxy answering in Kavita's place)
  /// says nothing about the credential and leaves it alone: throwing away a
  /// working key over a fault that fixes itself would cost a password for
  /// nothing. Those two throw — the 401 as [SignInExpired], which is the
  /// screen's cue to ask for a password, and everything else as it came.
  Future<void> resume(Profile profile) async {
    if (!profile.hasCredential) return;
    final LoginResult user;
    try {
      user = await ref.read(signInProvider)(
        baseUrl: profile.baseUrl,
        username: profile.username,
        credential: Credential.authKey(profile.apiKey),
        identity: ref.read(clientIdentityProvider),
      );
    } on DioException catch (error) {
      if (KavitaClient.isUnreachable(error)) {
        // Entered on the identity it already holds, id included: nothing was
        // asked, so nothing about which account this is has changed.
        await _commit(
          AuthState(profiles: state.profiles, activeId: profile.id),
        );
        return;
      }
      if (error.response?.statusCode == 401) {
        await _dropCredential(profile);
        throw SignInExpired(error);
      }
      rethrow;
    }
    await _enter(profile.baseUrl, profile.username, user);
  }

  /// Makes the account that just signed in the active profile, whichever
  /// credential paid for it.
  ///
  /// Which account that is comes out of the token rather than out of anything
  /// that was typed, so a person who renamed themselves in Kavita lands back
  /// on their own profile wearing the new name, and a second account on a
  /// server the device already knows lands beside the first instead of on top
  /// of it.
  Future<void> _enter(String url, String username, LoginResult user) async {
    final profile = Profile(
      baseUrl: url,
      accountId: accountIdFrom(user.token),
      username: user.username.isEmpty ? username : user.username,
      apiKey: user.apiKey,
      token: user.token,
      isAdmin: user.isAdmin,
    );
    await _commit(AuthState(profiles: _upsert(profile), activeId: profile.id));
  }

  /// Keeps the profile and forgets how to be this person.
  Future<void> _dropCredential(Profile profile) => _commit(
    AuthState(
      profiles: _upsert(
        Profile(
          baseUrl: profile.baseUrl,
          accountId: profile.accountId,
          username: profile.username,
        ),
      ),
      activeId: state.activeId == profile.id ? null : state.activeId,
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
        profiles: _upsert(active.copyWith(token: token)),
        activeId: state.activeId,
      ),
    );
  }

  /// Leaves the current profile without forgetting it: it keeps its address,
  /// its account and its name, and asks for a password next time.
  Future<void> signOut() async {
    final active = state.active;
    final profiles = active == null
        ? state.profiles
        : _upsert(
            Profile(
              baseUrl: active.baseUrl,
              accountId: active.accountId,
              username: active.username,
            ),
          );
    await _commit(AuthState(profiles: profiles, activeId: null));
  }

  /// Goes back to the profile list while keeping every auth key, so returning
  /// to any of them is a single tap.
  Future<void> switchProfile() async {
    await _commit(AuthState(profiles: state.profiles, activeId: null));
  }

  /// Removes one profile, credential and all. The others on its server stay:
  /// a person leaving the household is not the server being forgotten.
  Future<void> forget(String profileId) async {
    final profiles = [
      for (final profile in state.profiles)
        if (profile.id != profileId) profile,
    ];
    await _commit(
      AuthState(
        profiles: profiles,
        activeId: state.activeId == profileId ? null : state.activeId,
      ),
    );
  }

  /// [profile] first, and every other profile that is not it — the same
  /// account on the same server, and never merely the same address.
  ///
  /// Two ids count as this one. Its own, and the name-based id it would have
  /// had while its account id was unreadable ([Profile.id]), because that row
  /// still holds an auth key: a profile that arrives with a readable id at
  /// last has to absorb the one it left behind rather than open beside it.
  /// Same server plus same name is safe to call the same account — Kavita
  /// will not issue two accounts one username.
  List<Profile> _upsert(Profile profile) {
    final beforeItHadAnId = Profile(
      baseUrl: profile.baseUrl,
      username: profile.username,
    ).id;
    return [
      profile,
      for (final other in state.profiles)
        if (other.id != profile.id && other.id != beforeItHadAnId) other,
    ];
  }

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
      sessionProvider.select((s) => s == null ? null : (s.id, s.apiKey)),
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
