import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';

import 'test_support.dart';

/// A JWT for Kavita account [accountId] — three base64url segments, of which
/// only the middle one is ever read (see `api/account_id.dart`). This is how a
/// profile learns which account it is: the id is in the token every sign-in
/// answers with, and nothing has to ask for it.
String _tokenFor(int accountId, {String signature = 'signature'}) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS512'})}.${seg({'nameid': '$accountId'})}.$signature';
}

/// Two people on one server, and one of them again on a second server: the
/// three profiles it takes to tell an address apart from an account.
final _romain = Profile(
  baseUrl: 'https://a.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-romain',
  token: _tokenFor(1),
);
final _lea = Profile(
  baseUrl: 'https://a.example',
  accountId: 2,
  username: 'lea',
  apiKey: 'key-lea',
  token: _tokenFor(2),
);
final _romainElsewhere = Profile(
  baseUrl: 'https://b.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-b',
  token: _tokenFor(1),
);

/// A stand-in for `/api/Account/login` that records what it was asked with.
class _FakeSignIn {
  _FakeSignIn({
    this.apiKey = 'key-romain',
    this.accountId = 1,
    this.username,
    this.token,
    this.fails,
  });

  /// Mutable, so one fake can answer for two people in turn — which is what a
  /// second account signing into the same server looks like from here.
  String apiKey;

  /// Which Kavita account the token it answers with belongs to.
  int accountId;

  /// The name the *server* knows this account by, where it differs from the
  /// one that was typed — which is what a rename in Kavita looks like here.
  String? username;

  /// Answered instead of a token for [accountId], for the paths that have to
  /// cope with a token carrying no readable id.
  final String? token;

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
      username: this.username ?? username,
      token: token ?? _tokenFor(accountId),
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

  group('which profile this is', () {
    test('is the server address and the Kavita account, and nothing else', () {
      // Two people on one server are two profiles…
      expect(_romain.id, isNot(_lea.id));
      // …and one person's account on two servers is two profiles as well: a
      // Kavita user id is only unique on the server that issued it.
      expect(_romainElsewhere.accountId, _romain.accountId);
      expect(_romainElsewhere.id, isNot(_romain.id));
    });

    test('survives the name changing on the server', () {
      // The name is a label, not the identity: someone who renames themselves
      // in Kavita is the same person and must not become a second row.
      expect(_romain.copyWith(username: 'rastalien').id, _romain.id);
    });

    test('falls back to the name when the token carries no id', () {
      // A real Kavita always signs `nameid`, so this is a guard rather than a
      // path: an unreadable token costs a rename being seen as a new profile,
      // and never the session itself.
      final nameless = Profile(
        baseUrl: 'https://a.example',
        username: 'romain',
        apiKey: 'key-romain',
      );
      expect(nameless.accountId, isNull);
      expect(nameless.id, isNot(_romain.id));
      expect(
        nameless.id,
        Profile(
          baseUrl: 'https://a.example',
          username: 'romain',
          apiKey: 'another-key',
        ).id,
        reason: 'the same person on the same server',
      );
    });
  });

  test('only a profile holding its auth key counts as a session', () {
    final signedOut = _romain.copyWith(apiKey: '');
    final state = AuthState(profiles: [signedOut], activeId: signedOut.id);
    expect(state.active, isNull);
    expect(signedOut.hasCredential, isFalse);
    expect(_romain.hasCredential, isTrue);
  });

  test('a profile read back from storage can still be opened', () {
    // The JWT is session state and is gone; the key is what survives, and it
    // is what says this profile opens without a password. Reading a stored
    // profile back is the whole reason `hasCredential` is not about the token.
    final stored = Profile.fromJson(jsonDecode(jsonEncode(_romain.toJson())))!;

    expect(stored.token, isEmpty, reason: 'the JWT is never written down');
    expect(stored.apiKey, 'key-romain');
    expect(stored.accountId, 1, reason: 'which account this is, on a resume');
    expect(stored.id, _romain.id);
    expect(stored.hasCredential, isTrue);
  });

  group('a server holding several profiles', () {
    test('remembers both, each with its own credential', () async {
      final storage = mockSecureStorage();
      final signIn = _FakeSignIn(accountId: 1, apiKey: 'key-romain');
      final container = _container(const AuthState(), signIn: signIn);
      final auth = container.read(authProvider.notifier);

      await auth.login(
        baseUrl: 'https://a.example',
        username: 'romain',
        password: 'hunter2',
      );
      // The second person signs into the same address, and the first is not
      // dropped: that is the whole of this ticket.
      signIn
        ..accountId = 2
        ..apiKey = 'key-lea';
      await auth.login(
        baseUrl: 'https://a.example',
        username: 'lea',
        password: 'swordfish',
      );

      final state = container.read(authProvider);
      expect(state.profiles, hasLength(2));
      expect(
        {for (final p in state.profiles) p.username: p.apiKey},
        {'romain': 'key-romain', 'lea': 'key-lea'},
      );
      expect(state.active?.username, 'lea');

      final written = jsonDecode(storage['profiles']!) as List;
      expect(written, hasLength(2), reason: 'both reach the keychain');
    });

    test('signing in again as one of them enters it, never a second', () async {
      final container = _container(
        AuthState(profiles: [_romain, _lea]),
        signIn: _FakeSignIn(accountId: 2, apiKey: 'key-lea-2'),
      );

      await container
          .read(authProvider.notifier)
          .login(
            baseUrl: 'https://a.example',
            username: 'lea',
            password: 'swordfish',
          );

      final state = container.read(authProvider);
      expect(state.profiles, hasLength(2), reason: 'entered, not duplicated');
      expect(state.active?.id, _lea.id);
      expect(state.active?.apiKey, 'key-lea-2', reason: 'the fresh key');
      expect(
        state.profiles.firstWhere((p) => p.id == _romain.id).apiKey,
        'key-romain',
        reason: 'the other profile on this server is untouched',
      );
    });

    test('a profile renamed on the server keeps its place', () async {
      final container = _container(
        AuthState(profiles: [_romain, _lea]),
        signIn: _FakeSignIn(accountId: 1, username: 'rastalien'),
      );

      await container
          .read(authProvider.notifier)
          .login(
            baseUrl: 'https://a.example',
            username: 'romain',
            password: 'hunter2',
          );

      final state = container.read(authProvider);
      expect(state.profiles, hasLength(2), reason: 'the same two people');
      expect(state.active?.id, _romain.id);
      expect(state.active?.username, 'rastalien', reason: 'the new name');
    });

    test('forgetting one leaves the other on that server', () async {
      final container = _container(
        AuthState(profiles: [_romain, _lea], activeId: _lea.id),
      );

      await container.read(authProvider.notifier).forget(_lea.id);

      final state = container.read(authProvider);
      expect(state.profiles.single.id, _romain.id);
      expect(state.active, isNull, reason: 'the active profile is gone');
    });

    test('a renewed token reaches the active profile only', () async {
      final container = _container(
        AuthState(profiles: [_romain, _lea], activeId: _romain.id),
      );

      await container.read(authProvider.notifier).updateToken('token-romain-2');

      final state = container.read(authProvider);
      expect(state.active?.token, 'token-romain-2');
      expect(state.active?.apiKey, 'key-romain', reason: 'identity unchanged');
      expect(
        state.profiles.firstWhere((p) => p.id == _lea.id).token,
        _lea.token,
        reason: 'the other profile on the same server is untouched',
      );
    });
  });

  group('the layout shipped earlier', () {
    test('is deleted on first load and never read', () async {
      // No migration: a profile is keyed by its account now, and the old
      // entries cannot say which account they were. Deleting rather than
      // leaving them is the point — each carries an auth key, which is a
      // whole Kavita account (ADR-0004), and nothing will ever read it again.
      final storage = mockSecureStorage({
        'servers': jsonEncode([
          {'baseUrl': 'https://a.example', 'username': 'romain', 'apiKey': 'k'},
        ]),
        'activeServer': 'https://a.example',
        // The single-server layout before that one, whose migration path goes
        // the same way.
        'baseUrl': 'https://old.example',
        'username': 'romain',
        'apiKey': 'older-key',
        'token': 'a-stale-jwt',
        'refreshToken': 'a-stale-refresh',
        // Not ours to touch.
        'appLocale': 'fr',
        'clientDeviceId': 'device-uuid',
      });

      final state = await SessionStorage.load();

      expect(state.profiles, isEmpty);
      expect(state.active, isNull);
      expect(storage.keys, unorderedEquals(['appLocale', 'clientDeviceId']));
    });

    test('a row it cannot read costs a profile, never the app', () async {
      // `load()` is awaited in `main()` before `runApp`, so a `TypeError` out
      // of a cast here would fail every start of the app for good — over one
      // bad row nothing would ever clear.
      mockSecureStorage({
        'profiles': jsonEncode([
          {'baseUrl': 'https://bad.example', 'accountId': 'not-a-number'},
          {'baseUrl': 'https://worse.example', 'username': 7, 'isAdmin': 'yes'},
          _romain.toJson(),
        ]),
        'activeProfile': _romain.id,
      });

      final state = await SessionStorage.load();

      expect(state.profiles, hasLength(3));
      expect(state.profiles.first.accountId, isNull);
      expect(state.profiles[1].username, isEmpty);
      expect(state.profiles[1].isAdmin, isFalse);
      expect(state.active?.id, _romain.id, reason: 'the good row still opens');
    });

    test('a profile written now is read back whole', () async {
      final storage = mockSecureStorage();
      await SessionStorage.save(
        AuthState(profiles: [_romain, _lea], activeId: _lea.id),
      );

      expect(storage.containsKey('servers'), isFalse);
      final state = await SessionStorage.load();

      expect(state.profiles.map((p) => p.id), [_romain.id, _lea.id]);
      expect(state.active?.username, 'lea');
      expect(state.active?.token, isEmpty, reason: 'the JWT is session state');
    });
  });

  test('a token with no readable id still remembers the person', () async {
    // The guard [Profile.id] documents, driven the whole way: an unreadable
    // token costs the account id, and must cost neither the session nor a
    // second row on the next sign-in.
    final signIn = _FakeSignIn(token: 'not-a-token', apiKey: 'key-romain');
    final container = _container(const AuthState(), signIn: signIn);
    final auth = container.read(authProvider.notifier);

    Future<void> signInAsRomain() => auth.login(
      baseUrl: 'https://a.example',
      username: 'romain',
      password: 'hunter2',
    );

    await signInAsRomain();
    expect(container.read(sessionProvider)?.accountId, isNull);
    expect(container.read(sessionProvider)?.username, 'romain');

    await signInAsRomain();
    expect(
      container.read(authProvider).profiles,
      hasLength(1),
      reason: 'the same person on the same server, not a row per sign-in',
    );
  });

  test('a profile that gains an id absorbs the row it left behind', () async {
    // The other half of that fallback: the name-keyed row still holds an auth
    // key, so a sign-in that can finally read the id has to take its place
    // rather than open a second row that also works.
    final nameless = Profile(
      baseUrl: 'https://a.example',
      username: 'romain',
      apiKey: 'key-romain',
    );
    final container = _container(
      AuthState(profiles: [nameless, _lea]),
      signIn: _FakeSignIn(accountId: 1, apiKey: 'key-romain-2'),
    );

    await container
        .read(authProvider.notifier)
        .login(
          baseUrl: 'https://a.example',
          username: 'romain',
          password: 'hunter2',
        );

    final state = container.read(authProvider);
    expect(state.profiles.map((p) => p.id), [_romain.id, _lea.id]);
    expect(state.active?.accountId, 1);
  });

  test('signing in stores the auth key and no other secret', () async {
    final storage = mockSecureStorage();
    final signIn = _FakeSignIn(apiKey: 'key-romain', accountId: 1);
    final container = _container(const AuthState(), signIn: signIn);

    await container
        .read(authProvider.notifier)
        .login(
          baseUrl: 'https://a.example/',
          username: 'romain',
          password: 'hunter2',
        );

    expect(container.read(sessionProvider)?.token, _tokenFor(1));
    final written = jsonDecode(storage['profiles']!) as List;
    expect(written.single, {
      'baseUrl': 'https://a.example',
      'accountId': 1,
      'username': 'romain',
      'apiKey': 'key-romain',
      'isAdmin': false,
    });
  });

  test('resuming signs in with the auth key and no password', () async {
    final signIn = _FakeSignIn(apiKey: 'key-romain');
    final container = _container(
      AuthState(profiles: [_romain]),
      signIn: signIn,
    );

    await container.read(authProvider.notifier).resume(_romain);

    expect(signIn.calls.single, {
      'baseUrl': 'https://a.example',
      'username': 'romain',
      'credential': 'key key-romain',
    });
    expect(container.read(sessionProvider)?.id, _romain.id);
  });

  test('a key the server refuses leaves that profile signed out', () async {
    // The key was rotated in Kavita's web UI, or the account is gone. The
    // profile stays in the list, loses its secret, and the next tap asks for
    // a password — which is the only thing that can still get in.
    final container = _container(
      AuthState(profiles: [_romain, _lea]),
      signIn: _FakeSignIn(fails: _refused(401)),
    );

    // A type of its own, because the screen has to tell this apart from every
    // other way a sign-in fails: it is the one that asks for a password.
    await expectLater(
      container.read(authProvider.notifier).resume(_romain),
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
    final kept = state.profiles.firstWhere((p) => p.id == _romain.id);
    expect(kept.username, 'romain', reason: 'the profile is remembered');
    expect(kept.hasCredential, isFalse, reason: 'a password is needed again');
    expect(
      state.profiles.firstWhere((p) => p.id == _lea.id).apiKey,
      'key-lea',
      reason: 'the other profile is untouched',
    );
  });

  test('a server that answers badly keeps the key', () async {
    // A 500, or a proxy answering in Kavita's place, says nothing about the
    // credential. Throwing away a working key over it would cost a password
    // for a fault that fixes itself.
    final container = _container(
      AuthState(profiles: [_romain]),
      signIn: _FakeSignIn(fails: _refused(500)),
    );

    await expectLater(
      container.read(authProvider.notifier).resume(_romain),
      throwsA(isA<DioException>()),
      reason: 'not SignInExpired: nothing was refused',
    );
    expect(container.read(authProvider).profiles.single.apiKey, 'key-romain');
  });

  test('resuming with no network enters the profile anyway', () async {
    // Nothing to ask and nothing to ask it of: what such a session reads is
    // what it saved. The key is already here, so being offline is not the
    // same fact as being refused.
    final container = _container(
      AuthState(profiles: [_romain]),
      signIn: _FakeSignIn(fails: _noNetwork),
    );

    await container.read(authProvider.notifier).resume(_romain);

    expect(container.read(sessionProvider)?.id, _romain.id);
    expect(container.read(sessionProvider)?.apiKey, 'key-romain');
  });

  test('signing out keeps the profile but drops its key', () async {
    final container = _container(
      AuthState(profiles: [_romain, _lea], activeId: _romain.id),
    );
    expect(container.read(sessionProvider)?.username, 'romain');

    await container.read(authProvider.notifier).signOut();

    final state = container.read(authProvider);
    expect(state.active, isNull);
    expect(state.profiles, hasLength(2));
    final kept = state.profiles.firstWhere((p) => p.id == _romain.id);
    expect(kept.username, 'romain', reason: 'the profile is remembered');
    expect(kept.hasCredential, isFalse, reason: 'the password is needed again');
    expect(
      state.profiles.firstWhere((p) => p.id == _lea.id).apiKey,
      'key-lea',
      reason: 'the other profile keeps its own credential',
    );
  });

  test('leaving a profile keeps its key so returning is one tap', () async {
    final signIn = _FakeSignIn(apiKey: 'key-romain');
    final container = _container(
      AuthState(profiles: [_romain], activeId: _romain.id),
      signIn: signIn,
    );

    await container.read(authProvider.notifier).switchProfile();
    expect(container.read(sessionProvider), isNull);
    expect(container.read(authProvider).profiles.single.hasCredential, isTrue);

    await container.read(authProvider.notifier).resume(_romain);
    expect(container.read(sessionProvider)?.id, _romain.id);
  });

  test('host is what a profile row displays', () {
    expect(_romain.host, 'a.example');
    expect(
      Profile(baseUrl: 'http://192.168.1.20:5000', username: '').host,
      '192.168.1.20',
    );
    // A malformed address parses with no host: show it raw rather than blank.
    expect(Profile(baseUrl: 'not a url', username: '').host, 'not a url');
  });
}
