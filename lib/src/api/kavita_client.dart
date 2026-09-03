import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'client_identity.dart';
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
    this.identity = const ClientIdentity.unknown(),
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
    // Stamped per request rather than frozen into BaseOptions: part of the
    // identity is the screen, which turns when the device does. The refresh
    // instance gets it too — it is the one that replays a retried request.
    for (final dio in [_dio, _refreshDio]) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers.addAll(identity.headers);
            handler.next(options);
          },
        ),
      );
    }
    _dio.interceptors.add(
      // Not queued: reachability must not serialize concurrent responses.
      InterceptorsWrapper(
        onResponse: (response, handler) {
          onReachabilityChanged?.call(true);
          handler.next(response);
        },
        onError: (error, handler) {
          if (isUnreachable(error)) onReachabilityChanged?.call(false);
          handler.next(error);
        },
      ),
    );
    _dio.interceptors.add(
      // Queued so concurrent 401s refresh once, then retry in order.
      QueuedInterceptorsWrapper(onError: _onError),
    );
  }

  /// Whether the request never got an answer at all, as against getting one
  /// we did not like. The reachability interceptor and the settings probe
  /// have to draw this line the same way or the dot and the banner disagree.
  static bool isUnreachable(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    _ => false,
  };

  final String baseUrl;
  final String apiKey;

  /// What this installation tells the server it is; sent on every request.
  final ClientIdentity identity;

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
    ClientIdentity identity = const ClientIdentity.unknown(),
    @visibleForTesting HttpClientAdapter? adapter,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {...identity.headers},
        connectTimeout: const Duration(seconds: 10),
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    final res = await dio.post<Map<String, dynamic>>(
      '/api/Account/login',
      data: {'username': username, 'password': password, 'apiKey': ''},
    );
    return UserDto.fromJson(res.data!);
  }

  /// Cheapest proof that the server is there.
  ///
  /// `/api/Health` is the right probe rather than a convenient GET we already
  /// make: it is `[AllowAnonymous]`, so it answers reachability even when our
  /// token has gone stale — which is the question a connectivity dot asks —
  /// and it is `[SkipDeviceTracking]`, so asking it repeatedly does not churn
  /// the `ClientDevice` entry that every other endpoint registers.
  ///
  /// Untyped on purpose: the body is the plain string "Ok", not JSON. Going
  /// through [_dio] is the point — the reachability interceptor turns the
  /// result into [offlineProvider] for the rest of the app.
  Future<void> health() => _dio.get<dynamic>('/api/Health');

  /// Asks the server to scan a library for new files.
  ///
  /// **Admin only.** `POST /api/Library/scan` sits behind Kavita's
  /// `AdminPolicy`, which is `RequireRole("Admin")` — and so does every other
  /// way in: `scan-multiple`, `scan-all`, and even `scan-folder`, which is
  /// `[AllowAnonymous]` but looks up the key's account and refuses a
  /// non-admin itself. There is no non-admin path, which is why the button
  /// this sits behind is not offered to one; a `403` is all it could earn.
  ///
  /// `libraryId` goes in the query string, not a body: the action takes a
  /// bare `int`, which is where ASP.NET binds a primitive from.
  Future<void> scanLibrary(int libraryId) => _dio.post<dynamic>(
    '/api/Library/scan',
    queryParameters: {'libraryId': libraryId},
  );

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
          {
            'comparison': FilterComparison.contains,
            'field': SeriesFilterField.libraries,
            'value': '$libraryId',
          },
        ],
        'combination': FilterCombination.and,
        // The one number here the spec cannot vouch for: a bare int32 with no
        // enum and no default, whose "0 means no limit" is server behaviour
        // the description never states.
        'limitTo': 0,
        'sortOptions': {
          'sortField': SeriesSortField.sortName,
          'isAscending': true,
        },
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

  /// Marks one chapter read or unread.
  ///
  /// The pair `mark-multiple-read` / `mark-multiple-unread` rather than
  /// `mark-chapter-read`: there is no single-chapter *unread* endpoint, and
  /// these two take the same body, so the toggle is one shape instead of two.
  /// `volumeIds` is sent empty on purpose — the server merges it with
  /// `chapterIds` and reads it unconditionally. A volume with no chapter
  /// breakdown is covered by its placeholder chapter, which is all it has.
  Future<void> markChapterRead({
    required int seriesId,
    required int chapterId,
    required bool read,
  }) => _dio.post(
    read
        ? '/api/Reader/mark-multiple-read'
        : '/api/Reader/mark-multiple-unread',
    data: {
      'seriesId': seriesId,
      'volumeIds': const <int>[],
      'chapterIds': [chapterId],
      // Marking a row read by hand is not a reading session.
      'generateReadingSession': false,
    },
  );

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
  /// JWT like any other endpoint. They carry the identity too: every
  /// authenticated request refreshes the device's "last seen", and covers are
  /// most of them.
  Map<String, String> get imageHeaders => {
    'Authorization': 'Bearer $_token',
    ...identity.headers,
  };

  /// The devices Kavita has registered for the current user.
  ///
  /// Kavita registers (or refreshes) the calling device in middleware, before
  /// the controller runs, so this call also creates the entry it returns.
  /// Only exists since Kavita 0.9.1.
  Future<List<ClientDeviceDto>> clientDevices() async {
    final res = await _dio.get<List<dynamic>>('/api/Device/client/devices');
    return res.data!
        .map((e) => ClientDeviceDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sets the name Kavita shows for a registered device. Refused (403) for a
  /// read-only account.
  Future<void> renameClientDevice({
    required int deviceId,
    required String name,
  }) => _dio.post(
    '/api/Device/client/update-name',
    data: {'deviceId': deviceId, 'name': name},
  );

  String seriesCoverUrl(int seriesId) =>
      '$baseUrl/api/Image/series-cover?seriesId=$seriesId&apiKey=$apiKey';

  String volumeCoverUrl(int volumeId) =>
      '$baseUrl/api/Image/volume-cover?volumeId=$volumeId&apiKey=$apiKey';

  String chapterCoverUrl(int chapterId) =>
      '$baseUrl/api/Image/chapter-cover?chapterId=$chapterId&apiKey=$apiKey';

  /// Single source of truth for the reader-image query, so the URL used by
  /// image widgets and the one used by downloads cannot drift apart.
  ///
  /// `extractPdf` is what makes a PDF readable at all: without it Kavita
  /// caches the file untouched and there is no page image to serve, so every
  /// page 404s. With it the server rasterises the PDF into one image per page
  /// and this endpoint answers exactly as it does for an archive. It is
  /// harmless for every other format — Kavita only reads the flag on its
  /// PDF/EPUB branch — and its own thumbnail endpoint passes it unconditionally.
  Map<String, dynamic> _readerImageQuery(int chapterId, int page) => {
    'chapterId': chapterId,
    'page': page,
    'apiKey': apiKey,
    'extractPdf': true,
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
