import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';

import 'test_support.dart';

/// Two people on one server, and one of them again on a second server: the
/// three profiles it takes to tell an address apart from an account.
final _romain = Profile(
  baseUrl: 'https://a.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-romain',
  token: signedToken(1),
);
final _lea = Profile(
  baseUrl: 'https://a.example',
  accountId: 2,
  username: 'lea',
  apiKey: 'key-lea',
  token: signedToken(2),
);
final _romainElsewhere = Profile(
  baseUrl: 'https://b.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-b',
  token: signedToken(1),
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

  /// The face the response carries, as Kavita's own `coverImage` and
  /// `primaryColor` come back on it.
  bool hasAvatar = false;
  String color = '';

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
      token: token ?? signedToken(accountId),
      apiKey: apiKey,
      roles: const ['Login'],
      hasAvatar: hasAvatar,
      color: color,
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

  group('the face a profile is drawn with', () {
    final withFace = Profile(
      baseUrl: 'https://a.example',
      accountId: 1,
      username: 'romain',
      apiKey: 'key-romain',
      hasAvatar: true,
      color: '#4AC694',
    );

    test('survives storage, because the picker draws before any request', () {
      final stored = Profile.fromJson(
        jsonDecode(jsonEncode(withFace.toJson())),
      )!;

      expect(stored.hasAvatar, isTrue);
      expect(stored.color, '#4AC694');
    });

    test('is fetched by account, and only while the key is held', () {
      expect(
        withFace.avatarUrl,
        'https://a.example/api/Image/user-cover?userId=1&apiKey=key-romain',
      );
      // Signed out there is no key to authenticate the image with, so there
      // is no picture to ask for — the colour and the initial are what is
      // left, and they are enough to recognise a face by.
      final signedOut = withFace.copyWith(apiKey: '');
      expect(signedOut.avatarUrl, isNull);
      expect(signedOut.color, '#4AC694');
      // An account with no avatar is drawn as its initial, never as a
      // request that can only 404.
      expect(_romain.hasAvatar, isFalse);
      expect(_romain.avatarUrl, isNull);
    });

    test('is kept when a profile is signed out, not only when it is live', () async {
      // Dropping the credential rebuilds the profile from its identity; the
      // face is not part of what a refused key invalidates, and losing it
      // would blank a picker that has no network to fetch it again with.
      final signIn = _FakeSignIn(fails: _refused(401));
      final container = _container(
        AuthState(profiles: [withFace], activeId: withFace.id),
        signIn: signIn,
      );

      await expectLater(
        container.read(authProvider.notifier).resume(withFace),
        throwsA(isA<SignInExpired>()),
      );

      final kept = container.read(authProvider).profiles.single;
      expect(kept.hasCredential, isFalse);
      expect(kept.color, '#4AC694');
      expect(kept.hasAvatar, isTrue);
    });

    test('is what the sign-in response said, kept on the profile', () async {
      final signIn = _FakeSignIn(accountId: 1, apiKey: 'key-romain')
        ..hasAvatar = true
        ..color = '#4AC694';
      final container = _container(const AuthState(), signIn: signIn);

      await container.read(authProvider.notifier).login(
        baseUrl: 'https://a.example',
        username: 'romain',
        password: 'hunter2',
      );

      final profile = container.read(authProvider).profiles.single;
      expect(profile.hasAvatar, isTrue);
      expect(profile.color, '#4AC694');
    });
  });

  group('opening the app', () {
    test('a device holding one profile goes straight back into it', () {
      // What a single-profile device has always done, and must keep doing:
      // no picker, no extra tap, straight to the shelves.
      final opened = AuthState(
        profiles: [_romain],
        activeId: _romain.id,
      ).atLaunch();

      expect(opened.active?.id, _romain.id);
    });

    test('a device holding one opens in it whatever storage said', () {
      // `switchProfile` writes `activeId: null` through to the keychain, and
      // a single-profile device has nobody to switch *to* — so without this
      // one tap on Settings' switch would leave that device opening on a
      // picker of one face at every start, for ever.
      final opened = AuthState(profiles: [_romain]).atLaunch();

      expect(opened.active?.id, _romain.id);
    });

    test('a lone profile with no key left still lands on the form', () {
      // Nothing to open it with: this is the one single-profile device that
      // is asked for something, and what it is asked for is a password.
      final signedOut = _romain.copyWith(apiKey: '');

      expect(AuthState(profiles: [signedOut]).atLaunch().active, isNull);
    });

    test('a device holding several lands on the picker, whoever read last', () {
      final opened = AuthState(
        profiles: [_romain, _lea],
        activeId: _lea.id,
      ).atLaunch();

      expect(opened.active, isNull, reason: 'the picker asks who is reading');
      expect(
        opened.profiles.map((p) => p.id),
        [_romain.id, _lea.id],
        reason: 'nobody is forgotten — only nobody is active yet',
      );
      expect(
        opened.profiles.every((p) => p.hasCredential),
        isTrue,
        reason: 'every key is kept, so entering any of them is one tap',
      );
    });

    test('a handover keeps every key and only the reader\'s token', () {
      // What a rebuilt container is seeded with when the tablet is handed
      // over (`SessionScope`). Every credential is kept — coming back to a
      // profile is a tap, never a password — but a JWT belongs to the
      // session that spent it, and this is the only place one could outlive
      // it: a resume mints a fresh one from the key, so nothing would ever
      // spend the one left behind.
      final handedOver = AuthState(
        profiles: [_romain, _lea],
        activeId: _lea.id,
      ).handedOver;

      expect(handedOver.activeId, _lea.id);
      expect(handedOver.active?.token, _lea.token);
      final left = handedOver.profiles.firstWhere((p) => p.id == _romain.id);
      expect(left.token, isEmpty);
      expect(left.apiKey, _romain.apiKey);
    });

    test('a handover to nobody leaves no token at all', () {
      // The shape a switch really makes: the picker is up, so nobody is
      // active and there is no session for a token to belong to.
      final handedOver = AuthState(profiles: [_romain, _lea]).handedOver;

      expect(handedOver.profiles.every((p) => p.token.isEmpty), isTrue);
      expect(handedOver.profiles.every((p) => p.hasCredential), isTrue);
    });

    test('leaves what storage read alone', () {
      // The rule is about opening the app, not about what the keychain
      // holds: which profile was last active is a true fact, and the rest of
      // the session goes on writing and reading it.
      final stored = AuthState(profiles: [_romain, _lea], activeId: _lea.id);

      expect(stored.active?.id, _lea.id);
      expect(stored.atLaunch().activeId, isNull);
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

    expect(container.read(sessionProvider)?.token, signedToken(1));
    final written = jsonDecode(storage['profiles']!) as List;
    expect(written.single, {
      'baseUrl': 'https://a.example',
      'accountId': 1,
      'username': 'romain',
      'apiKey': 'key-romain',
      'isAdmin': false,
      // What the picker draws this person with, plus the two facts about the
      // account itself that outlive a sign-in — and nothing else: the whole
      // row is asserted, so a secret added here has to be added here too.
      'ageRestricted': false,
      'hasAvatar': false,
      'color': '',
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

  group('the role, once the server has refused it', () {
    test('a refusal clears it and leaves everything else alone', () async {
      final admin = _romain.copyWith(isAdmin: true);
      final container = _container(
        AuthState(profiles: [admin, _lea], activeId: admin.id),
      );
      expect(container.read(sessionProvider)?.isAdmin, isTrue);

      await container.read(authProvider.notifier).clearAdmin();

      final state = container.read(authProvider);
      // A 403 from an admin-only endpoint is the server's own answer, and it
      // is fresher than a flag the last sign-in left.
      expect(state.active?.isAdmin, isFalse);
      // It says nothing about the credential, and nothing about anybody else.
      expect(state.active?.apiKey, 'key-romain');
      expect(state.profiles, hasLength(2));
      expect(
        state.profiles.firstWhere((p) => p.id == _lea.id).isAdmin,
        isFalse,
      );
    });

    test('and there is nothing to clear with nobody reading', () async {
      final container = _container(AuthState(profiles: [_romain]));

      await container.read(authProvider.notifier).clearAdmin();

      expect(container.read(authProvider).profiles.single.id, _romain.id);
    });
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
