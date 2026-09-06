import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';

/// Simulates a Kavita server whose current valid token is [validToken]:
/// 401 on any authenticated call made with another token, and a login
/// endpoint that mints [validToken] for the right auth key.
class _FakeKavitaAdapter implements HttpClientAdapter {
  _FakeKavitaAdapter({
    required this.validToken,
    this.validApiKey = 'key',
    this.loginReturnsGarbage = false,
    this.loginStatus,
    this.loginThrows,
    this.authenticatedStatus = 200,
    this.totalSeries = 0,
  });

  final String validToken;

  /// The auth key this server still recognises; anything else earns a 401,
  /// which is what a key rotated in Kavita's web UI looks like from here.
  final String validApiKey;

  /// 200 whose body holds no token (reverse proxy answering for Kavita).
  final bool loginReturnsGarbage;

  /// Served to a login instead of a token, when set: a server having a
  /// problem of its own rather than refusing anything.
  final int? loginStatus;

  /// Thrown instead of answering a login, when set — the network going away
  /// between the 401 and the request that would fix it.
  final Object? loginThrows;

  /// Status served to correctly authenticated requests.
  final int authenticatedStatus;

  /// Number of series served by the paginated all-v2 endpoint.
  final int totalSeries;

  /// Every login this server was asked for, body and all.
  final List<Map<String, dynamic>> logins = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody json(Object body, {int status = 200}) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    if (options.path == '/api/Account/login') {
      final body = (options.data as Map).cast<String, dynamic>();
      logins.add(body);
      if (loginThrows != null) throw loginThrows!;
      if (loginStatus != null) return json({}, status: loginStatus!);
      if (body['apiKey'] != validApiKey) return json({}, status: 401);
      if (loginReturnsGarbage) return json({'unexpected': 'html'});
      return json({
        'username': 'romain',
        'token': validToken,
        'refreshToken': 'refresh-2',
        'apiKey': validApiKey,
      });
    }
    if (options.headers['Authorization'] != 'Bearer $validToken') {
      return json({}, status: 401);
    }
    if (authenticatedStatus != 200) {
      return json({}, status: authenticatedStatus);
    }
    if (options.path == '/api/Library/libraries') {
      return json([
        {'id': 1, 'name': 'Mangas', 'type': 0},
      ]);
    }
    if (options.path == '/api/Series/all-v2') {
      final pageNumber = int.parse(
        '${options.queryParameters['PageNumber'] ?? 1}',
      );
      final pageSize = int.parse(
        '${options.queryParameters['PageSize'] ?? 100}',
      );
      final start = (pageNumber - 1) * pageSize;
      return json([
        for (var id = start; id < start + pageSize && id < totalSeries; id++)
          {'id': id, 'name': 'Series $id', 'pages': 10, 'pagesRead': 0},
      ]);
    }
    return json({}, status: 404);
  }

  @override
  void close({bool force = false}) {}
}

KavitaClient _client(
  _FakeKavitaAdapter adapter, {
  String token = 'expired-token',
  String apiKey = 'key',
  void Function(String)? onTokenRenewed,
  void Function()? onSessionExpired,
}) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: token,
    username: 'romain',
    apiKey: apiKey,
    onTokenRenewed: onTokenRenewed,
    onSessionExpired: onSessionExpired,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;
  return client;
}

ScreenMetrics _phoneScreen() => const ScreenMetrics(412, 915);

void main() {
  test('signing in with an auth key sends no password', () async {
    // The password-free path the whole design rests on: `LoginDto` documents
    // that a login carrying an apiKey ignores the username and password, and
    // Kavita resolves the account from the key. This is that field, filled in.
    final adapter = _FakeKavitaAdapter(
      validToken: 'fresh-token',
      validApiKey: 'the-auth-key',
    );

    final user = await KavitaClient.login(
      baseUrl: 'http://kavita.test',
      username: 'romain',
      credential: Credential.authKey('the-auth-key'),
      adapter: adapter,
    );

    expect(adapter.logins.single, {
      'username': 'romain',
      'password': '',
      'apiKey': 'the-auth-key',
    });
    expect(user.token, 'fresh-token');
    expect(user.apiKey, 'the-auth-key');
  });

  test('signing in with a password sends no auth key', () async {
    final adapter = _FakeKavitaAdapter(
      validToken: 'fresh-token',
      validApiKey: '',
    );

    await KavitaClient.login(
      baseUrl: 'http://kavita.test',
      username: 'romain',
      credential: Credential.password('hunter2'),
      adapter: adapter,
    );

    expect(adapter.logins.single, {
      'username': 'romain',
      'password': 'hunter2',
      'apiKey': '',
    });
  });

  test('a 401 mints a new token from the auth key and retries', () async {
    final adapter = _FakeKavitaAdapter(validToken: 'fresh-token');
    String? renewed;
    final client = _client(adapter, onTokenRenewed: (t) => renewed = t);

    final libraries = await client.libraries();

    expect(libraries, hasLength(1));
    expect(libraries.first.name, 'Mangas');
    expect(adapter.logins, hasLength(1));
    expect(adapter.logins.single['apiKey'], 'key');
    expect(adapter.logins.single['password'], '');
    expect(renewed, 'fresh-token');
    expect(client.imageHeaders['Authorization'], 'Bearer fresh-token');
  });

  test('a session entered offline mints its token on the first 401', () async {
    // Resuming with no network enters on the stored key alone, so the client
    // starts with no JWT at all. The very first request 401s, and the key
    // that got the session in is what gets it working.
    final adapter = _FakeKavitaAdapter(validToken: 'fresh-token');
    final client = _client(adapter, token: '');

    expect(await client.libraries(), hasLength(1));
    expect(adapter.logins, hasLength(1));
  });

  test('concurrent 401s sign in only once', () async {
    final adapter = _FakeKavitaAdapter(validToken: 'fresh-token');
    final client = _client(adapter);

    final results = await Future.wait([
      client.libraries(),
      client.libraries(),
      client.libraries(),
    ]);

    expect(results.every((libs) => libs.length == 1), isTrue);
    expect(adapter.logins, hasLength(1));
  });

  test('a refused auth key expires the session', () async {
    // What a key rotated in Kavita's web UI looks like: the JWT is stale, the
    // key that would replace it is no longer the account's, and a password is
    // the only way back in.
    final adapter = _FakeKavitaAdapter(
      validToken: 'fresh-token',
      validApiKey: 'rotated-since',
    );
    var expired = false;
    final client = _client(adapter, onSessionExpired: () => expired = true);

    await expectLater(client.libraries(), throwsA(isA<DioException>()));
    expect(expired, isTrue);
  });

  test('the renewal carries the username, exactly as a resume does', () async {
    // `LoginDto` says Kavita ignores it when a key is present, so both shapes
    // should work — but only one of them is ever exercised against a real
    // server, and it must not be the one that recovers a session.
    final adapter = _FakeKavitaAdapter(validToken: 'fresh-token');
    final client = _client(adapter);

    await client.libraries();

    expect(adapter.logins.single['username'], 'romain');
  });

  group('only a refused key may end the session', () {
    // This rule is new with the auth key, and it is the key being durable
    // that makes it matter. While a session was a token pair, expiring it on
    // any failed renewal cost a credential that had a day left in it. Now
    // `onSessionExpired` deletes the one secret the server is remembered by,
    // so anything that is not a refusal must leave it alone.

    test('a 200 without a token does not', () async {
      // A reverse proxy or captive portal answering in Kavita's place. The
      // request fails and the credential survives the walled garden.
      final adapter = _FakeKavitaAdapter(
        validToken: 'fresh-token',
        loginReturnsGarbage: true,
      );
      var expired = false;
      final client = _client(adapter, onSessionExpired: () => expired = true);

      await expectLater(client.libraries(), throwsA(isA<DioException>()));
      expect(expired, isFalse);
    });

    test('a server error does not', () async {
      final adapter = _FakeKavitaAdapter(
        validToken: 'fresh-token',
        loginStatus: 500,
      );
      var expired = false;
      final client = _client(adapter, onSessionExpired: () => expired = true);

      await expectLater(client.libraries(), throwsA(isA<DioException>()));
      expect(expired, isFalse);
    });

    test(
      'losing the network between the 401 and the renewal does not',
      () async {
        final adapter = _FakeKavitaAdapter(
          validToken: 'fresh-token',
          loginThrows: DioException(
            requestOptions: RequestOptions(path: '/api/Account/login'),
            type: DioExceptionType.connectionError,
          ),
        );
        var expired = false;
        final client = _client(adapter, onSessionExpired: () => expired = true);

        await expectLater(client.libraries(), throwsA(isA<DioException>()));
        expect(expired, isFalse);
      },
    );
  });

  test('a retry failure after a successful sign-in does not log out', () async {
    final adapter = _FakeKavitaAdapter(
      validToken: 'fresh-token',
      authenticatedStatus: 400,
    );
    var expired = false;
    final client = _client(adapter, onSessionExpired: () => expired = true);

    // The retry's own error (400) must surface, not the stale 401.
    await expectLater(
      client.libraries(),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          400,
        ),
      ),
    );
    expect(adapter.logins, hasLength(1));
    expect(expired, isFalse);
  });

  test('allSeriesForLibrary fetches every page', () async {
    final adapter = _FakeKavitaAdapter(
      validToken: 'expired-token',
      totalSeries: 250,
    );
    final client = _client(adapter);

    final series = await client.allSeriesForLibrary(1);

    expect(series, hasLength(250));
    expect(series.first.name, 'Series 0');
    expect(series.last.name, 'Series 249');
  });

  group('request shapes Kavita is strict about', () {
    late RequestOptions? lastRequest;

    KavitaClient recordingClient() {
      final client = KavitaClient(
        baseUrl: 'http://kavita.test',
        token: 'token',
        username: 'romain',
        apiKey: 'the-api-key',
      );
      final recorder = _RecordingAdapter((options) => lastRequest = options);
      client.httpClient.httpClientAdapter = recorder;
      client.bareHttpClient.httpClientAdapter = recorder;
      return client;
    }

    setUp(() => lastRequest = null);

    test('reader image bytes carry the apiKey', () async {
      // Kavita binds apiKey as a non-nullable parameter: without it the
      // endpoint answers 400 and downloads fail.
      await recordingClient().readerImageBytes(7, 2);

      expect(lastRequest!.path, '/api/Reader/image');
      expect(lastRequest!.queryParameters['apiKey'], 'the-api-key');
      expect(lastRequest!.queryParameters['chapterId'], 7);
      expect(lastRequest!.queryParameters['page'], 2);
    });

    test('reader images ask the server to rasterise a PDF', () async {
      // Without extractPdf, Kavita caches a PDF untouched and there is no
      // page image to serve: every page 404s. With it, a PDF reads exactly
      // like an archive. It is ignored for every other format.
      await recordingClient().readerImageBytes(7, 2);
      expect(lastRequest!.queryParameters['extractPdf'], true);

      expect(
        recordingClient().readerImageUrl(7, 2),
        contains('extractPdf=true'),
      );
    });

    test('chapter info asks for page dimensions', () async {
      // They are opt-in, and the vertical-scrolling view needs them to size pages.
      await recordingClient().chapterInfo(7);

      expect(lastRequest!.queryParameters['includeDimensions'], true);
    });

    test('every request identifies the client to the server', () async {
      // Kavita registers a device per (user, X-Device-Id) and reads the
      // platform out of the User-Agent; a request missing them lands as one
      // more anonymous device.
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.android,
        osVersion: '15',
        deviceModel: 'CPH2663',
        screen: _phoneScreen,
      );
      final client = KavitaClient(
        baseUrl: 'http://kavita.test',
        token: 'token',
        username: 'romain',
        apiKey: 'the-api-key',
        identity: identity,
      );
      final recorder = _RecordingAdapter((options) => lastRequest = options);
      client.httpClient.httpClientAdapter = recorder;
      client.bareHttpClient.httpClientAdapter = recorder;

      await client.chapterInfo(7);

      expect(lastRequest!.headers['user-agent'], identity.userAgent);
      expect(lastRequest!.headers['X-Device-Id'], 'device-uuid');
      expect(
        lastRequest!.headers['X-Kavita-Client'],
        identity.kavitaClientHeader,
      );
      // Covers and pages go out through image widgets, not dio.
      expect(client.imageHeaders['X-Device-Id'], 'device-uuid');
      expect(client.imageHeaders['user-agent'], identity.userAgent);
    });

    test('image URLs carry the apiKey too', () {
      final client = recordingClient();

      expect(client.readerImageUrl(7, 2), contains('apiKey=the-api-key'));
      expect(client.readerImageUrl(7, 2), contains('page=2'));
      expect(
        client.readerThumbnailUrl(7, 2),
        'http://kavita.test/api/Reader/thumbnail'
        '?chapterId=7&pageNum=2&apiKey=the-api-key',
      );
      expect(client.seriesCoverUrl(4), contains('apiKey=the-api-key'));
    });
  });
}

/// Captures the request that was sent, then answers something harmless.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.onRequest);

  final void Function(RequestOptions options) onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    if (options.responseType == ResponseType.bytes) {
      return ResponseBody.fromBytes(const [1, 2, 3], 200);
    }
    return ResponseBody.fromString(
      jsonEncode({'seriesId': 1, 'pages': 1}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
