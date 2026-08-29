import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// Thin hand-written client for the handful of Kavita endpoints the app uses.
/// The full API exposes ~500 endpoints; generating a client for all of them
/// is not worth the weight.
class KavitaClient {
  KavitaClient({
    required this.baseUrl,
    required String token,
    required this._refreshToken,
    required this.apiKey,
    this.onTokensRefreshed,
    this.onSessionExpired,
    this.onReachabilityChanged,
  }) : _token = token,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           headers: {'Authorization': 'Bearer $token'},
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 30),
         ),
       ),
       // Separate bare instance for the refresh call: routing it through
       // _dio would deadlock the queued interceptor below.
       _refreshDio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
         ),
       ) {
    _dio.interceptors.add(
      // Not queued: reachability must not serialize concurrent responses.
      InterceptorsWrapper(
        onResponse: (response, handler) {
          onReachabilityChanged?.call(true);
          handler.next(response);
        },
        onError: (error, handler) {
          if (_isUnreachable(error)) onReachabilityChanged?.call(false);
          handler.next(error);
        },
      ),
    );
    _dio.interceptors.add(
      // Queued so concurrent 401s refresh once, then retry in order.
      QueuedInterceptorsWrapper(onError: _onError),
    );
  }

  static bool _isUnreachable(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    _ => false,
  };

  final String baseUrl;
  final String apiKey;

  /// Notified with the new (token, refreshToken) pair so the session can be
  /// persisted.
  final void Function(String token, String refreshToken)? onTokensRefreshed;

  /// Notified when the refresh token itself is rejected: the user must log
  /// in again.
  final void Function()? onSessionExpired;

  /// Notified with false when the server could not be reached at all, and
  /// with true on the next successful response.
  final void Function(bool reachable)? onReachabilityChanged;

  String _token;
  String _refreshToken;
  final Dio _dio;
  final Dio _refreshDio;

  @visibleForTesting
  Dio get httpClient => _dio;

  @visibleForTesting
  Dio get refreshHttpClient => _refreshDio;

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final response = error.response;
    final alreadyRetried = error.requestOptions.extra['retried'] == true;
    if (response?.statusCode != 401 || alreadyRetried) {
      return handler.next(error);
    }
    // Another queued request may have refreshed while we waited; only hit
    // the server if this request was sent with the current token.
    final sentWith = error.requestOptions.headers['Authorization'];
    if (sentWith == 'Bearer $_token') {
      // Refresh failures mean the session is over; failures of the retried
      // request below do not — keep the two failure domains separate.
      try {
        final res = await _refreshDio.post<Map<String, dynamic>>(
          '/api/Account/refresh-token',
          data: {'token': _token, 'refreshToken': _refreshToken},
        );
        final token = res.data?['token'];
        final refreshToken = res.data?['refreshToken'];
        if (token is! String || refreshToken is! String) {
          // 200 without tokens: a reverse proxy or captive portal answered
          // in Kavita's place. Treat as an expired session.
          onSessionExpired?.call();
          return handler.next(error);
        }
        _token = token;
        _refreshToken = refreshToken;
        _dio.options.headers['Authorization'] = 'Bearer $_token';
        onTokensRefreshed?.call(_token, _refreshToken);
      } on DioException {
        onSessionExpired?.call();
        return handler.next(error);
      }
    }
    try {
      // Replayed on the bare instance: sending it through _dio would make its
      // failure wait on this very handler in the queued interceptor.
      final retried = await _refreshDio.fetch<dynamic>(
        error.requestOptions
          ..headers['Authorization'] = 'Bearer $_token'
          ..extra['retried'] = true,
      );
      return handler.resolve(retried);
    } on DioException catch (e) {
      // The tokens are fine; surface the retry's own error, not the stale 401.
      return handler.next(e);
    }
  }

  /// Closes the underlying HTTP clients; in-flight requests may complete.
  void close() {
    _dio.close();
    _refreshDio.close();
  }

  /// Authenticates against a Kavita server. Static because it happens before
  /// a client exists.
  static Future<UserDto> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
      ),
    );
    final res = await dio.post<Map<String, dynamic>>(
      '/api/Account/login',
      data: {'username': username, 'password': password, 'apiKey': ''},
    );
    return UserDto.fromJson(res.data!);
  }

  Future<List<LibraryDto>> libraries() async {
    final res = await _dio.get<List<dynamic>>('/api/Library/libraries');
    return res.data!
        .map((e) => LibraryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SeriesDto>> seriesForLibrary(
    int libraryId, {
    int pageNumber = 1,
    int pageSize = 100,
  }) async {
    final res = await _dio.post<List<dynamic>>(
      '/api/Series/all-v2',
      queryParameters: {'PageNumber': pageNumber, 'PageSize': pageSize},
      data: {
        'statements': [
          // field 19 = Libraries, comparison 5 = Contains
          {'comparison': 5, 'field': 19, 'value': '$libraryId'},
        ],
        'combination': 1, // And
        'limitTo': 0,
        'sortOptions': {'sortField': 1, 'isAscending': true},
      },
    );
    return res.data!
        .map((e) => SeriesDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches every page of a library: the endpoint silently caps results at
  /// the page size.
  Future<List<SeriesDto>> allSeriesForLibrary(int libraryId) async {
    const pageSize = 100;
    final all = <SeriesDto>[];
    for (var pageNumber = 1; ; pageNumber++) {
      final page = await seriesForLibrary(
        libraryId,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );
      all.addAll(page);
      if (page.length < pageSize) return all;
    }
  }

  /// Series the user has started but not finished — the "Continue" shelf.
  Future<List<SeriesDto>> currentlyReading({int pageSize = 20}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/Series/currently-reading',
      queryParameters: {'PageNumber': 1, 'PageSize': pageSize},
    );
    return res.data!
        .map((e) => SeriesDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Next thing to read in each series — the "On deck" shelf.
  Future<List<SeriesDto>> onDeck({int pageSize = 20}) async {
    final res = await _dio.post<List<dynamic>>(
      '/api/Series/on-deck',
      queryParameters: {'PageNumber': 1, 'PageSize': pageSize},
    );
    return res.data!
        .map((e) => SeriesDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SeriesDto> series(int seriesId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/Series/$seriesId');
    return SeriesDto.fromJson(res.data!);
  }

  Future<SeriesMetadataDto> seriesMetadata(int seriesId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/Series/metadata',
      queryParameters: {'seriesId': seriesId},
    );
    return SeriesMetadataDto.fromJson(res.data!);
  }

  Future<List<VolumeDto>> volumes(int seriesId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/Series/volumes',
      queryParameters: {'seriesId': seriesId},
    );
    return res.data!
        .map((e) => VolumeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChapterInfoDto> chapterInfo(int chapterId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/Reader/chapter-info',
      // Page dimensions are opt-in; without them the webtoon view cannot
      // size pages before their images load.
      queryParameters: {'chapterId': chapterId, 'includeDimensions': true},
    );
    return ChapterInfoDto.fromJson(res.data!);
  }

  Future<void> saveProgress({
    required int libraryId,
    required int seriesId,
    required int volumeId,
    required int chapterId,
    required int pageNum,
  }) => _dio.post(
    '/api/Reader/progress',
    data: {
      'libraryId': libraryId,
      'seriesId': seriesId,
      'volumeId': volumeId,
      'chapterId': chapterId,
      'pageNum': pageNum,
    },
  );

  /// Downloads one reader page as bytes, for offline storage.
  Future<List<int>> readerImageBytes(
    int chapterId,
    int page, {
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.get<List<int>>(
      '/api/Reader/image',
      // apiKey is not optional server-side: Kavita binds it as a non-nullable
      // parameter, so omitting it answers 400 rather than falling back to the
      // bearer token.
      queryParameters: _readerImageQuery(chapterId, page),
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancelToken,
    );
    return res.data!;
  }

  /// Headers to pass to image widgets — Kavita image endpoints accept the
  /// JWT like any other endpoint.
  Map<String, String> get imageHeaders => {'Authorization': 'Bearer $_token'};

  String seriesCoverUrl(int seriesId) =>
      '$baseUrl/api/Image/series-cover?seriesId=$seriesId&apiKey=$apiKey';

  String volumeCoverUrl(int volumeId) =>
      '$baseUrl/api/Image/volume-cover?volumeId=$volumeId&apiKey=$apiKey';

  String chapterCoverUrl(int chapterId) =>
      '$baseUrl/api/Image/chapter-cover?chapterId=$chapterId&apiKey=$apiKey';

  /// Single source of truth for the reader-image query, so the URL used by
  /// image widgets and the one used by downloads cannot drift apart.
  Map<String, dynamic> _readerImageQuery(int chapterId, int page) => {
    'chapterId': chapterId,
    'page': page,
    'apiKey': apiKey,
  };

  String readerImageUrl(int chapterId, int page) =>
      Uri.parse('$baseUrl/api/Reader/image')
          .replace(
            queryParameters: _readerImageQuery(
              chapterId,
              page,
            ).map((key, value) => MapEntry(key, '$value')),
          )
          .toString();

  /// Server-rendered page thumbnail, for the reader's page strip: far lighter
  /// than pulling every full-size page.
  String readerThumbnailUrl(int chapterId, int page) =>
      '$baseUrl/api/Reader/thumbnail?chapterId=$chapterId&pageNum=$page'
      '&apiKey=$apiKey';
}
