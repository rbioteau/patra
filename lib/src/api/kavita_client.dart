import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'account_id.dart';
import 'client_identity.dart';
import 'models.dart';

/// What a sign-in is made with. A password the first time, the account's
/// auth key every time after — and never both, never neither.
///
/// `LoginDto` carries all three fields flat, so the shape on the wire cannot
/// say that; a type here can. Which field is filled is what picks the
/// password path or the key path inside `AccountController.Login`, so the
/// choice is a fork rather than two settings, and [KavitaClient._loginBody]
/// is the one place that turns it back into Kavita's flat shape.
sealed class Credential {
  const Credential();

  /// What a person types the first time.
  const factory Credential.password(String value) = PasswordCredential;

  /// What a remembered server signs in with afterwards. `LoginDto` states
  /// that a login carrying one *"will ignore username/password for
  /// validation"*.
  const factory Credential.authKey(String value) = AuthKeyCredential;
}

class PasswordCredential extends Credential {
  const PasswordCredential(this.value);

  final String value;
}

class AuthKeyCredential extends Credential {
  const AuthKeyCredential(this.value);

  final String value;
}

/// Thin hand-written client for the handful of Kavita endpoints the app uses.
/// The full API exposes ~500 endpoints; generating a client for all of them
/// is not worth the weight.
class KavitaClient {
  KavitaClient({
    required this.baseUrl,
    required String token,
    required this.username,
    required this.apiKey,
    this.identity = const ClientIdentity.unknown(),
    this.onTokenRenewed,
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
       // Separate bare instance for the renewal call: routing it through
       // _dio would deadlock the queued interceptor below.
       _bareDio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
         ),
       ) {
    // Stamped per request rather than frozen into BaseOptions: part of the
    // identity is the screen, which turns when the device does. The bare
    // instance gets it too — it is the one that replays a retried request.
    for (final dio in [_dio, _bareDio]) {
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
      // Queued so concurrent 401s renew the token once, then retry in order.
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

  /// Marks a request whose `401` says nothing about our JWT, so the handler
  /// above leaves it alone.
  ///
  /// Every endpoint but one authenticates with the Bearer token, which makes
  /// a `401` mean "refresh and retry". `/api/Plugin/version` is
  /// `[AllowAnonymous]` and authenticated by the `apiKey` query parameter
  /// alone — Kavita never looks at the header — so its `401` means the *key*
  /// has expired while the session is perfectly good. Without this flag that
  /// answer would spend a refresh, retry a request that must 401 again, and,
  /// if the refresh itself failed, fire `onSessionExpired` and sign the user
  /// out over a version string.
  static const _bearerIsIrrelevant = 'bearerIsIrrelevant';

  final String baseUrl;

  /// Whose account this is, sent with every sign-in this client makes.
  ///
  /// `LoginDto` says Kavita ignores it when an [apiKey] is present, so it is
  /// belt and braces — but it costs one field, and it makes the renewal below
  /// exactly the request `AuthNotifier.resume` makes. The alternative was one
  /// shape exercised against a real server and a second, subtly different one
  /// on the path that recovers a session.
  final String username;

  /// The account's Kavita auth key: the one credential this client holds that
  /// does not expire.
  ///
  /// Two jobs, and they are the same secret. Image URLs carry it as a query
  /// parameter, because an `<img>` cannot always send a header. And it is what
  /// mints a JWT — `LoginDto` states that a login carrying an `apiKey` ignores
  /// the username and password, and `AccountController.Login` resolves the
  /// account from the key and skips the password check entirely. So a 401 on
  /// an expired JWT is answered by signing in again with this, rather than by
  /// the refresh-token pair the app deliberately no longer keeps (ADR-0004).
  final String apiKey;

  /// What this installation tells the server it is; sent on every request.
  final ClientIdentity identity;

  /// Notified with a freshly minted JWT, so the live session carries it.
  ///
  /// Nothing writes it down — see [apiKey].
  final void Function(String token)? onTokenRenewed;

  /// Notified when the server refuses [apiKey]: the key has been rotated or
  /// the account is gone, and only a password can get back in.
  final void Function()? onSessionExpired;

  /// Notified with false when the server could not be reached at all, and
  /// with true on the next successful response.
  final void Function(bool reachable)? onReachabilityChanged;

  String _token;
  final Dio _dio;
  final Dio _bareDio;

  @visibleForTesting
  Dio get httpClient => _dio;

  @visibleForTesting
  Dio get bareHttpClient => _bareDio;

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final response = error.response;
    final alreadyRetried = error.requestOptions.extra['retried'] == true;
    final ownsAuth = error.requestOptions.extra[_bearerIsIrrelevant] != true;
    if (response?.statusCode != 401 || alreadyRetried || !ownsAuth) {
      return handler.next(error);
    }
    // Another queued request may have renewed while we waited; only hit the
    // server if this request was sent with the current token.
    final sentWith = error.requestOptions.headers['Authorization'];
    if (sentWith == 'Bearer $_token') {
      // A refused key means the session is over; failures of the retried
      // request below do not — keep the two failure domains separate.
      try {
        final res = await _bareDio.post<Map<String, dynamic>>(
          '/api/Account/login',
          data: _loginBody(username, AuthKeyCredential(apiKey)),
        );
        final token = res.data?['token'];
        if (token is! String || token.isEmpty) {
          // 200 without a token: a reverse proxy or captive portal answered
          // in Kavita's place. It says nothing about the key, so the request
          // simply fails — see below for why that matters now.
          return handler.next(error);
        }
        _token = token;
        _dio.options.headers['Authorization'] = 'Bearer $_token';
        onTokenRenewed?.call(_token);
      } on DioException catch (renewal) {
        // **Only a refusal ends the session.** This used to fire on any
        // failure, which was affordable while the session was a token pair
        // that was expiring anyway: what it cost was a credential with a day
        // left in it. The auth key is durable, and `onSessionExpired` now
        // deletes it — so a 500, a proxy answering in Kavita's place, or the
        // network dropping between the 401 and this call would cost a working
        // credential and a password for a fault that fixes itself. That is
        // the same rule `AuthNotifier.resume` states, and the key is refused
        // in exactly one way: a bare 401.
        if (renewal.response?.statusCode == 401) onSessionExpired?.call();
        return handler.next(error);
      }
    }
    try {
      // Replayed on the bare instance: sending it through _dio would make its
      // failure wait on this very handler in the queued interceptor.
      final retried = await _bareDio.fetch<dynamic>(
        error.requestOptions
          ..headers['Authorization'] = 'Bearer $_token'
          ..extra['retried'] = true,
      );
      return handler.resolve(retried);
    } on DioException catch (e) {
      // The key is fine; surface the retry's own error, not the stale 401.
      return handler.next(e);
    }
  }

  /// Closes the underlying HTTP clients; in-flight requests may complete.
  void close() {
    _dio.close();
    _bareDio.close();
  }

  /// Authenticates against a Kavita server. Static because it happens before
  /// a client exists.
  ///
  /// Two ways in, one endpoint, and [Credential] is which. A password is what
  /// a person types the first time; an auth key is what a remembered server
  /// signs in with afterwards, so reopening the app never asks for a password
  /// again. Kavita resolves the account from the key, still checks
  /// `LoginRole`, and still answers with the whole `UserDto` — the two paths
  /// differ only in what is sent.
  ///
  /// `POST /api/Plugin/authenticate?apiKey=` mints the same token pair and is
  /// deliberately not used: it checks no role at all, takes the key in the
  /// query string, answers with a partial DTO carrying neither roles nor the
  /// key itself, and logs the raw key in cleartext when it fails (ADR-0004).
  static Future<LoginResult> login({
    required String baseUrl,
    required String username,
    required Credential credential,
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
      data: _loginBody(username, credential),
    );
    return LoginResult.fromJson(res.data!);
  }

  /// `LoginDto`, whose three fields Kavita binds by name. All three go on the
  /// wire every time, filled or empty — it is the shape the endpoint expects,
  /// and the empty one is how the server knows which path this is.
  static Map<String, String> _loginBody(
    String username,
    Credential credential,
  ) => switch (credential) {
    PasswordCredential(:final value) => {
      'username': username,
      'password': value,
      'apiKey': '',
    },
    AuthKeyCredential(:final value) => {
      'username': username,
      'password': '',
      'apiKey': value,
    },
  };

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

  /// Which release of Kavita this server is running, or null if it will not
  /// say.
  ///
  /// `/api/Plugin/version` rather than `/api/Server/server-info-slim`, which
  /// carries the same number in a richer DTO: `ServerController` is
  /// `[Authorize(PolicyGroups.AdminPolicy)]` at the class level and none of
  /// its actions opts out, so a non-admin earns a 403 from it and from
  /// `check-update` alike. This one is `[AllowAnonymous]` and its controller
  /// is `[SkipDeviceTracking]` — the same two properties that made
  /// `/api/Health` the right probe — and it accepts any account's
  /// non-expired auth key, which is exactly what the login response's
  /// [apiKey] is.
  ///
  /// The login response *also* carries this number, as `UserDto.kavitaVersion`,
  /// and we deliberately ignore it: a resumed session never logs in again, so
  /// on most launches there is no value at all, and the value there is would
  /// be as old as the last sign-in. Kavita's own web client ignores the field
  /// for the same reason — its `User` model does not even declare it — and
  /// polls this endpoint instead.
  ///
  /// The body is bare `text/plain` (four dot-separated integers, `0.9.1.4`),
  /// read from the `InstallVersion` setting that `Startup` rewrites from the
  /// assembly version at every boot. Anything that is not a string is treated
  /// as no answer rather than stringified onto the screen: the contract
  /// oracle deliberately does not assert response types, so the guard against
  /// a future Kavita returning JSON belongs here.
  ///
  /// Which is why this must **not** ask for `ResponseType.plain`, however
  /// well that describes what Kavita sends today: forcing it hands back the
  /// raw body as a `String` whatever the content type, so a JSON answer would
  /// sail past the check below and land on the card as a stringified map.
  /// Left alone, dio decodes by content type and the guard is real.
  Future<String?> serverVersion() async {
    final res = await _dio.get<dynamic>(
      '/api/Plugin/version',
      queryParameters: {'apiKey': apiKey},
      options: Options(extra: {_bearerIsIrrelevant: true}),
    );
    final version = res.data;
    if (version is! String) return null;
    final trimmed = version.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

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

  Future<List<Library>> libraries() async {
    final res = await _dio.get<List<dynamic>>('/api/Library/libraries');
    return res.data!
        .map((e) => Library.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Series>> seriesForLibrary(
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
        .map((e) => Series.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches every page of a library: the endpoint silently caps results at
  /// the page size.
  Future<List<Series>> allSeriesForLibrary(int libraryId) async {
    const pageSize = 100;
    final all = <Series>[];
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

  /// The account this session's token belongs to, or null if it cannot be
  /// read. Recomputed rather than cached because the token is refreshed.
  int? get accountId => accountIdFrom(_token);

  /// Series the user has started but not finished — the candidates the home
  /// screen's Continue promotion picks from. It is not drawn as a list: On
  /// deck is the home screen's only shelf.
  ///
  /// **`userId` is required.** Kavita reads the caller's own id off the query
  /// string here rather than off the bearer token, and answers 400 without it
  /// — which is what silently emptied this shelf: a failed shelf draws
  /// nothing, so the screen looked merely quiet rather than broken.
  Future<List<Series>> currentlyReading({int pageSize = 20}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/Series/currently-reading',
      queryParameters: {
        'PageNumber': 1,
        'PageSize': pageSize,
        'userId': ?accountId,
      },
    );
    return res.data!
        .map((e) => Series.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Next thing to read in each series — the "On deck" shelf.
  Future<List<Series>> onDeck({int pageSize = 20}) async {
    final res = await _dio.post<List<dynamic>>(
      '/api/Series/on-deck',
      queryParameters: {'PageNumber': 1, 'PageSize': pageSize},
    );
    return res.data!
        .map((e) => Series.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Series> series(int seriesId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/Series/$seriesId');
    return Series.fromJson(res.data!);
  }

  Future<SeriesMetadata> seriesMetadata(int seriesId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/Series/metadata',
      queryParameters: {'seriesId': seriesId},
    );
    return SeriesMetadata.fromJson(res.data!);
  }

  Future<List<Volume>> volumes(int seriesId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/Series/volumes',
      queryParameters: {'seriesId': seriesId},
    );
    return res.data!
        .map((e) => Volume.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChapterInfo> chapterInfo(int chapterId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/Reader/chapter-info',
      // Page dimensions are opt-in; without them the vertical-scrolling view cannot
      // size pages before their images load.
      queryParameters: {'chapterId': chapterId, 'includeDimensions': true},
    );
    return ChapterInfo.fromJson(res.data!);
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
