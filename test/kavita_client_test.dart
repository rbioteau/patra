import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verso/src/api/client_identity.dart';
import 'package:verso/src/api/kavita_client.dart';

/// Simulates a Kavita server whose current valid token is [validToken]:
/// 401 on any authenticated call made with another token, and a working
/// refresh endpoint (unless [refreshFails]).
class _FakeKavitaAdapter implements HttpClientAdapter {
  _FakeKavitaAdapter({
    required this.validToken,
    this.refreshFails = false,
    this.refreshReturnsGarbage = false,
    this.authenticatedStatus = 200,
    this.totalSeries = 0,
  });

  final String validToken;
  final bool refreshFails;

  /// 200 whose body holds no tokens (reverse proxy answering for Kavita).
  final bool refreshReturnsGarbage;

  /// Status served to correctly authenticated requests.
  final int authenticatedStatus;

  /// Number of series served by the paginated all-v2 endpoint.
  final int totalSeries;

  int refreshCalls = 0;

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

    if (options.path == '/api/Account/refresh-token') {
      refreshCalls++;
      if (refreshFails) return json({}, status: 401);
      if (refreshReturnsGarbage) return json({'unexpected': 'html'});
      return json({'token': validToken, 'refreshToken': 'refresh-2'});
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
  void Function(String, String)? onTokensRefreshed,
  void Function()? onSessionExpired,
}) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'expired-token',
    refreshToken: 'refresh-1',
    apiKey: 'key',
    onTokensRefreshed: onTokensRefreshed,
    onSessionExpired: onSessionExpired,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;
  return client;
}

ScreenMetrics _phoneScreen() => const ScreenMetrics(412, 915);

void main() {
  test('a 401 triggers a token refresh and the call is retried', () async {
    final adapter = _FakeKavitaAdapter(validToken: 'fresh-token');
    String? newToken;
    String? newRefreshToken;
    final client = _client(
      adapter,
      onTokensRefreshed: (t, r) {
        newToken = t;
        newRefreshToken = r;
      },
    );

    final libraries = await client.libraries();

    expect(libraries, hasLength(1));
    expect(libraries.first.name, 'Mangas');
    expect(adapter.refreshCalls, 1);
    expect(newToken, 'fresh-token');
    expect(newRefreshToken, 'refresh-2');
    expect(client.imageHeaders['Authorization'], 'Bearer fresh-token');
  });

  test('concurrent 401s refresh only once', () async {
    final adapter = _FakeKavitaAdapter(validToken: 'fresh-token');
    final client = _client(adapter);

    final results = await Future.wait([
      client.libraries(),
      client.libraries(),
      client.libraries(),
    ]);

    expect(results.every((libs) => libs.length == 1), isTrue);
    expect(adapter.refreshCalls, 1);
  });

  test('a rejected refresh token expires the session', () async {
    final adapter = _FakeKavitaAdapter(
      validToken: 'fresh-token',
      refreshFails: true,
    );
    var expired = false;
    final client = _client(adapter, onSessionExpired: () => expired = true);

    await expectLater(client.libraries(), throwsA(isA<DioException>()));
    expect(expired, isTrue);
  });

  test('a 200 refresh response without tokens expires the session', () async {
    final adapter = _FakeKavitaAdapter(
      validToken: 'fresh-token',
      refreshReturnsGarbage: true,
    );
    var expired = false;
    final client = _client(adapter, onSessionExpired: () => expired = true);

    await expectLater(client.libraries(), throwsA(isA<DioException>()));
    expect(expired, isTrue);
  });

  test('a retry failure after a successful refresh does not log out', () async {
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
    expect(adapter.refreshCalls, 1);
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
        refreshToken: 'refresh',
        apiKey: 'the-api-key',
      );
      final recorder = _RecordingAdapter((options) => lastRequest = options);
      client.httpClient.httpClientAdapter = recorder;
      client.refreshHttpClient.httpClientAdapter = recorder;
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
      // They are opt-in, and the webtoon view needs them to size pages.
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
        refreshToken: 'refresh',
        apiKey: 'the-api-key',
        identity: identity,
      );
      final recorder = _RecordingAdapter((options) => lastRequest = options);
      client.httpClient.httpClientAdapter = recorder;
      client.refreshHttpClient.httpClientAdapter = recorder;

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
