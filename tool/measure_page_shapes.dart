/// Measures the shape of real pages on a real Kavita server.
///
/// #64 asks where "very tall" starts, and says it cannot be guessed: it has to
/// be measured on a library holding both things that scroll and things that
/// turn. This is the instrument. It prints one row per series — the median
/// page shape, the spread around it, and what the threshold in
/// `docs/research/reader-vertical-page-shape.md` would decide — and then sorts
/// the rows so the gap between the two populations is visible.
///
/// It reads the numbers through `ChapterInfo`, so what it measures is exactly
/// what the app will measure: the same endpoint, the same `includeDimensions`
/// flag, the same 0- or 1-based page numbers, the same `isWide`.
///
/// Run it from the repository root:
///
/// ```sh
/// dart run tool/measure_page_shapes.dart \
///   --url https://kavita.example.org \
///   --user roman \
///   --api-key <the key from Kavita's user settings>
/// ```
///
/// `--url`, `--user` and `--api-key` fall back to `KAVITA_URL`, `KAVITA_USER`
/// and `KAVITA_API_KEY`. An API key is what signs in, so no password is ever
/// needed here: all three of `LoginDto`'s fields go on the wire, filled or
/// empty, and the password is ignored when a key is present.
///
/// `--insecure` accepts a self-signed certificate, which is what a server on
/// a home network usually has. `--library <id>` measures one library.
/// `--chapters <n>` reads more than the first chapter of each series.
library;

import 'dart:convert';
import 'dart:io';

import 'package:patra/src/api/models.dart';

const _usage = '''
Measures real page shapes on a real Kavita server, for #64.

Usage: dart run tool/measure_page_shapes.dart --url <url> --user <name> --api-key <key>

  --url        Base URL of the server, e.g. https://kavita.example.org
  --user       Kavita username
  --api-key    API key from that user's settings (a password is never needed)
  --library    Measure one library id instead of every library
  --chapters   Chapters per series to read (default 1): a series is one format,
               so one chapter is usually enough
  --insecure   Accept a self-signed certificate
''';

/// The threshold `docs/research/reader-vertical-page-shape.md` names: height
/// divided by width, at or above which a page is a panel and not a page.
const _verticalAt = 1.8;

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.write(_usage);
    return;
  }
  final options = _Options.parse(args);
  if (options == null) {
    stderr.write(_usage);
    exit(64);
  }

  final api = _Api(Uri.parse(options.url), insecure: options.insecure);
  try {
    await api.signIn(options.user, options.apiKey);
    final rows = <_Row>[];
    for (final library in await api.libraries()) {
      if (options.library != null && library.id != options.library) continue;
      for (final series in await api.seriesForLibrary(library.id)) {
        final row = await _measure(api, library, series, options.chapters);
        if (row != null) rows.add(row);
      }
    }
    _report(rows);
  } finally {
    api.close();
  }
}

/// One series' measurement, or null when the server reported no dimensions.
class _Row {
  _Row({
    required this.library,
    required this.series,
    required this.median,
    required this.min,
    required this.max,
    required this.pages,
    required this.spreads,
  });

  final String library;
  final String series;
  final double median;
  final double min;
  final double max;
  final int pages;

  /// Pages left out because Kavita measured them as two pages wide.
  final int spreads;
}

Future<_Row?> _measure(
  _Api api,
  Library library,
  Series series,
  int chaptersPerSeries,
) async {
  final chapters = (await api.volumes(series.id))
      .expand((volume) => volume.chapters)
      .take(chaptersPerSeries)
      .toList();

  final tallness = <double>[];
  var spreads = 0;
  for (final chapter in chapters) {
    final info = await api.chapterInfo(chapter.id);
    for (final page in info.pageDimensions.values) {
      // No dimensions, or a page the server never measured: not evidence.
      if (page.width <= 0 || page.height <= 0) continue;
      // A spread is two pages' worth of width presented as one, so its shape
      // says nothing about the shape of a page in this work.
      if (page.isWide || page.width > page.height) {
        spreads++;
        continue;
      }
      tallness.add(page.height / page.width);
    }
  }

  // Fewer than three pages is where Kavita's own detector declines to answer,
  // and one or two pages cannot separate a webtoon from a scan with an
  // unusually tall cover.
  if (tallness.length < 3) return null;
  tallness.sort();
  return _Row(
    library: library.name,
    series: series.name,
    median: _median(tallness),
    min: tallness.first,
    max: tallness.last,
    pages: tallness.length,
    spreads: spreads,
  );
}

double _median(List<double> sorted) {
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

void _report(List<_Row> rows) {
  if (rows.isEmpty) {
    stdout.writeln('No series reported page dimensions.');
    return;
  }
  rows.sort((a, b) => a.median.compareTo(b.median));

  final buffer = StringBuffer()
    ..writeln('| Library | Series | Pages | Spreads | Median h/w | Min | Max | >= $_verticalAt |')
    ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- |');
  for (final row in rows) {
    final cells = [
      row.library,
      row.series,
      '${row.pages}',
      '${row.spreads}',
      row.median.toStringAsFixed(2),
      row.min.toStringAsFixed(2),
      row.max.toStringAsFixed(2),
      row.median >= _verticalAt ? 'vertical' : 'paged',
    ];
    buffer.writeln('| ${cells.join(' | ')} |');
  }
  stdout.writeln(buffer);

  // Where the two populations separate, as the threshold itself sees them:
  // the highest work it calls paged and the lowest it calls vertical. The
  // widest gap between any two neighbours is not the question — a library
  // of a single kind has a widest gap and no separation in it, as the public
  // demo showed by reporting 0.03 between two comics.
  final paged = rows.where((row) => row.median < _verticalAt).toList();
  final vertical = rows.where((row) => row.median >= _verticalAt).toList();
  if (paged.isEmpty || vertical.isEmpty) {
    stdout.writeln(
      paged.isEmpty
          ? 'Every series measured here is vertical: this library holds nothing that '
              'turns, so it says nothing about how tall a page can get before it stops being one.'
          : 'Every series measured here is paged: this library holds nothing that '
              'scrolls, so it corroborates the paged population and says nothing about '
              'where the threshold goes.',
    );
    return;
  }
  final highest = paged.last;
  final lowest = vertical.first;
  stdout.writeln(
    'Paged tops out at ${highest.median.toStringAsFixed(2)} (${highest.series}); vertical '
    'starts at ${lowest.median.toStringAsFixed(2)} (${lowest.series}). Any threshold in '
    '(${highest.median.toStringAsFixed(2)}, ${lowest.median.toStringAsFixed(2)}] splits '
    'this library the same way, and $_verticalAt is in it.',
  );
}

/// The command line, with the environment as its fallback.
class _Options {
  _Options({
    required this.url,
    required this.user,
    required this.apiKey,
    required this.library,
    required this.chapters,
    required this.insecure,
  });

  final String url;
  final String user;
  final String apiKey;
  final int? library;
  final int chapters;
  final bool insecure;

  static _Options? parse(List<String> args) {
    if (args.contains('--help')) return null;
    String? value(String name, String env) {
      final index = args.indexOf(name);
      if (index != -1 && index + 1 < args.length) return args[index + 1];
      final fromEnv = Platform.environment[env];
      return fromEnv == null || fromEnv.isEmpty ? null : fromEnv;
    }

    final url = value('--url', 'KAVITA_URL');
    final user = value('--user', 'KAVITA_USER');
    final apiKey = value('--api-key', 'KAVITA_API_KEY');
    if (url == null || user == null || apiKey == null) return null;

    final library = value('--library', 'KAVITA_LIBRARY');
    final chapters = value('--chapters', 'KAVITA_CHAPTERS');
    return _Options(
      url: url,
      user: user,
      apiKey: apiKey,
      library: library == null ? null : int.tryParse(library),
      chapters: chapters == null ? 1 : int.tryParse(chapters) ?? 1,
      insecure: args.contains('--insecure'),
    );
  }
}

/// A Kavita server, signed in, read through the app's own models.
class _Api {
  _Api(this.base, {required this.insecure}) {
    _client.badCertificateCallback = (_, _, _) => insecure;
  }

  final Uri base;
  final bool insecure;
  final HttpClient _client = HttpClient();
  String _token = '';

  Future<void> signIn(String username, String apiKey) async {
    // All three of `LoginDto`'s fields go on the wire, filled or empty, and
    // the password is ignored when a key is present — so this is the whole
    // credential, and no password is ever asked for.
    final body = await post('/api/Account/login', {
      'username': username,
      'password': '',
      'apiKey': apiKey,
    }) as Map<String, dynamic>;
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw StateError('Signed in, but the server returned no token.');
    }
    _token = token;
  }

  Future<List<Library>> libraries() async => [
    for (final library in await get('/api/Library/libraries') as List<dynamic>)
      Library.fromJson(library as Map<String, dynamic>),
  ];

  Future<List<Series>> seriesForLibrary(int libraryId) async => [
    for (final series
        in await post(
              '/api/Series/all-v2',
              {
                'statements': [
                  {
                    'comparison': FilterComparison.contains,
                    'field': SeriesFilterField.libraries,
                    'value': '$libraryId',
                  },
                ],
                'combination': FilterCombination.and,
                'limitTo': 0,
                'sortOptions': {
                  'sortField': SeriesSortField.sortName,
                  'isAscending': true,
                },
              },
              {'PageNumber': '1', 'PageSize': '500'},
            ) as List<dynamic>)
      Series.fromJson(series as Map<String, dynamic>),
  ];

  Future<List<Volume>> volumes(int seriesId) async => [
    for (final volume
        in await get(
              '/api/Series/volumes',
              {'seriesId': '$seriesId'},
            ) as List<dynamic>)
      Volume.fromJson(volume as Map<String, dynamic>),
  ];

  Future<ChapterInfo> chapterInfo(int chapterId) async => ChapterInfo.fromJson(
    await get('/api/Reader/chapter-info', {
      'chapterId': '$chapterId',
      // Page dimensions are opt-in; without this the server reports no
      // dimensions at all and there is nothing to measure.
      'includeDimensions': 'true',
    }) as Map<String, dynamic>,
  );

  Future<dynamic> get(String path, [Map<String, String> params = const {}]) =>
      _send('GET', path, params);

  Future<dynamic> post(
    String path,
    Object body, [
    Map<String, String> params = const {},
  ]) async {
    final request = await _open('POST', path, params);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    return _finish(request);
  }

  Future<HttpClientRequest> _open(
    String method,
    String path,
    Map<String, String> params,
  ) async {
    final request = await _client.openUrl(method, _uri(path, params));
    // Before the body is written: once it has been, the headers are immutable.
    if (_token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    }
    return request;
  }

  Future<dynamic> _send(
    String method,
    String path,
    Map<String, String> params,
  ) async {
    final request = await _open(method, path, params);
    return _finish(request);
  }

  Future<dynamic> _finish(HttpClientRequest request) async {
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('${request.uri} → ${response.statusCode}: $text');
    }
    return jsonDecode(text);
  }

  /// Under `base`, keeping any prefix it carries: a server behind a reverse
  /// proxy is often at `/kavita`, and resolving an absolute path against it
  /// would drop the prefix.
  Uri _uri(String path, Map<String, String> params) {
    final prefix = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(
      path: '$prefix${path.startsWith('/') ? path.substring(1) : path}',
      queryParameters: params,
    );
  }

  void close() => _client.close(force: true);
}
