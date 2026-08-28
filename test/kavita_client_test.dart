import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
