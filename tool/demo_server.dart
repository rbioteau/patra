/// A Kavita server that serves a library nobody owns.
///
///   dart run tool/demo_server.dart            # then point the app at http://localhost:5000
///   ./tool/gen_demo_library.sh                # draws the pictures it serves
///
/// **Why it exists.** The store screenshots have to show the app, and the app
/// shows somebody's library — a publisher's covers, an author's pages. Putting
/// those on a listing is a rights problem, and assembling a rights-free
/// library by hand is a chore that has to be redone for every new series worth
/// photographing. So the content is faked instead, one layer below the app:
/// this speaks Kavita's API for a handful of invented series and serves
/// drawings made by `tool/gen_demo_library.sh`. Every pixel is ours, and the
/// app is none the wiser — the screenshots are of the real app, which is what
/// a store asks for, over content that belongs to nobody.
///
/// **It is not a simulator.** Every response is the shape `lib/src/api/models.dart`
/// reads, and nothing more: a route it does not know is a 404, so a screen
/// that starts calling a new endpoint fails loudly the next time the recipe
/// runs rather than looking subtly wrong. The shapes were read out of
/// `docs/openapi/kavita-openapi-0.9.0.0.json` — pinned in this repository — and
/// out of the models, not invented here.
///
/// **It never ships.** It is a `tool/`, so it is not in the app, not in a
/// bundle, and not behind a flag anybody could turn on in production: a fake
/// content mode inside the app would be a second way for every screen to draw,
/// and this is not.
///
/// State lives in memory and dies with the process, which is the point: a run
/// that needs the same answers twice starts the server again.
library;

import 'dart:convert';
import 'dart:io';

/// The account the demo answers to. Any password and any auth key are accepted
/// — nothing here is worth protecting — but the name is the one the recipe
/// signs in with, and the app draws it on the picker.
const _username = 'roman';

/// One library, of Kavita's Manga type: series made of volumes made of
/// chapters, which is the shape the store screenshots show.
const _libraryName = 'Demo Library';
const _libraryType = 0;

/// Six drawings, reused across every chapter. The reader is what is being
/// photographed, and a page that says which page it is reads better in a
/// screenshot than eighty unique ones.
const _pagesPerChapter = 6;
const _pageDrawings = 6;

void main(List<String> args) async {
  final port = int.parse(_arg(args, '--port') ?? '5000');
  final root = Directory(_arg(args, '--library') ?? 'store/demo');

  final titles = File('${root.path}/titles.txt');
  if (!titles.existsSync()) {
    stderr.writeln(
      '${titles.path} is missing — run ./tool/gen_demo_library.sh first.',
    );
    exit(1);
  }
  final library = _DemoLibrary(
    titles.readAsLinesSync().where((line) => line.trim().isNotEmpty).toList(),
  );
  if (library.series.isEmpty) {
    stderr.writeln('${titles.path} names no series.');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln(
    'demo Kavita on http://localhost:$port — ${library.series.length} series, '
    '${library.chapters.length} chapters, pictures in ${root.path}',
  );
  stdout.writeln('sign in with any password; the account is $_username');

  await for (final request in server) {
    final started = DateTime.now();
    try {
      await _route(request, library, root);
    } on Exception catch (error) {
      stderr.writeln('${request.method} ${request.uri.path}: $error');
      await _text(request, HttpStatus.internalServerError, '$error');
    } finally {
      // One line per request, because "did the app even get here?" is the
      // first question when a screen comes out wrong — and the answer is
      // invisible without it.
      final ms = DateTime.now().difference(started).inMilliseconds;
      stdout.writeln(
        '${request.method.padRight(4)} ${request.uri.path} '
        '${request.response.statusCode} ${ms}ms'
        '${request.uri.hasQuery ? '?${request.uri.query}' : ''}',
      );
    }
  }
}

Future<void> _route(
  HttpRequest request,
  _DemoLibrary library,
  Directory root,
) async {
  final path = request.uri.path;

  switch (path) {
    // Kavita's only [AllowAnonymous] probe, and the app asks it often.
    case '/api/Health':
      return _text(request, HttpStatus.ok, 'Ok');

    // Bare text, four dot-separated integers: the app refuses anything that is
    // not a string rather than stringify it onto the settings card.
    case '/api/Plugin/version':
      return _text(request, HttpStatus.ok, '0.9.0.0');

    case '/api/Account/login':
      return _json(request, {
        'username': _username,
        'token': 'demo-token',
        'apiKey': 'demo-api-key',
        'roles': const ['Admin'],
        // Kavita's AgeRating.NotApplicable: no restriction, which is what the
        // app compares against to decide whether an account is limited.
        'ageRestriction': const {'ageRating': -1},
        'coverImage': 'avatar.png',
        'primaryColor': '#D7B976',
      });

    case '/api/Library/libraries':
      return _json(request, [
        {
          'id': _DemoLibrary.libraryId,
          'name': _libraryName,
          'type': _libraryType,
        },
      ]);

    case '/api/Library/scan':
      return _json(request, true);

    // The filter body is read and ignored: one library means every query is
    // already scoped, and a filter nobody applies is a lie this does not need.
    case '/api/Series/all-v2':
      return _json(request, [
        for (final series in library.series) library.seriesJson(series),
      ]);

    case '/api/Series/on-deck':
      return _json(request, [
        for (final series in library.series)
          if (library.underWay(series)) library.seriesJson(series),
      ]);

    case '/api/Series/volumes':
      final series = library.seriesById(_query(request, 'seriesId'));
      if (series == null) {
        return _text(request, HttpStatus.notFound, 'no such series');
      }
      return _json(request, [
        for (final volume in series.volumes) library.volumeJson(volume),
      ]);

    case '/api/Series/metadata':
      final series = library.seriesById(_query(request, 'seriesId'));
      if (series == null) {
        return _text(request, HttpStatus.notFound, 'no such series');
      }
      return _json(request, {
        'summary':
            'A series drawn for the store screenshots. Every cover, '
            'page and title in it was made for this demo.',
        'writers': [
          {'name': 'Demo Library'},
        ],
        'genres': [
          {'title': 'Demo'},
          {'title': 'Placeholder'},
        ],
        'releaseYear': 2026,
      });

    case '/api/Reader/chapter-info':
      final chapter = library.chapterById(_query(request, 'chapterId'));
      if (chapter == null) {
        return _text(request, HttpStatus.notFound, 'no such chapter');
      }
      return _json(request, library.chapterInfoJson(chapter));

    case '/api/Reader/get-progress':
      final chapter = library.chapterById(_query(request, 'chapterId'));
      if (chapter == null) {
        return _text(request, HttpStatus.notFound, 'no such chapter');
      }
      return _json(request, {
        'pageNum': chapter.pagesRead,
        'bookScrollId': null,
      });

    case '/api/Reader/progress':
    case '/api/Reader/mark-multiple-read':
    case '/api/Reader/mark-multiple-unread':
      final body = await _body(request);
      library.record(body, read: path != '/api/Reader/mark-multiple-unread');
      return _json(request, true);

    // An empty list: the app registers itself on every request and renames the
    // entry it finds, so nothing to find is a no-op rather than an error.
    case '/api/Device/client/devices':
      return _json(request, const <Object>[]);

    case '/api/Device/client/update-name':
      return _json(request, true);

    case '/api/Reader/image':
    case '/api/Reader/thumbnail':
      final chapter = library.chapterById(_query(request, 'chapterId'));
      if (chapter == null) {
        return _text(request, HttpStatus.notFound, 'no such chapter');
      }
      final page = _query(
        request,
        path.endsWith('thumbnail') ? 'pageNum' : 'page',
      );
      return _image(request, root, library.pageDrawing(chapter, page));

    case '/api/Image/series-cover':
      return _image(
        request,
        root,
        library.coverDrawing(library.seriesById(_query(request, 'seriesId'))),
      );

    case '/api/Image/volume-cover':
      return _image(
        request,
        root,
        library.coverDrawing(
          library.seriesOfVolume(_query(request, 'volumeId')),
        ),
      );

    case '/api/Image/chapter-cover':
      return _image(
        request,
        root,
        library.coverDrawing(
          library.seriesOfChapter(_query(request, 'chapterId')),
        ),
      );

    case '/api/Image/user-cover':
      return _image(request, root, 'avatar.png');

    case '/':
      return _text(
        request,
        HttpStatus.ok,
        'A demo Kavita for the store screenshots.\n'
        '${library.series.length} series, ${library.chapters.length} chapters.\n'
        'Sign in with any password as "$_username".\n',
      );
  }

  // `/api/Series/<id>`, which the app calls for one series.
  final one = RegExp(r'^/api/Series/(\d+)$').firstMatch(path);
  if (one != null) {
    final series = library.seriesById(int.parse(one.group(1)!));
    if (series == null) {
      return _text(request, HttpStatus.notFound, 'no such series');
    }
    return _json(request, library.seriesJson(series));
  }

  stderr.writeln('404 ${request.method} $path');
  await _text(request, HttpStatus.notFound, 'no route for $path');
}

// ---- the library, and the JSON the app reads -------------------------------

class _DemoLibrary {
  _DemoLibrary(List<String> titles) {
    for (var i = 0; i < titles.length; i++) {
      final number = i + 1;
      // Two volumes, three chapters and two: enough for a volume row with
      // chapters under it and for the reading-position view to have something
      // to group.
      final volumes = <_Volume>[];
      for (var v = 1; v <= 2; v++) {
        final chapters = <_Chapter>[
          for (var c = 1; c <= (v == 1 ? 3 : 2); c++)
            _Chapter(
              id: 1000 + number * 100 + v * 10 + c,
              number: volumeChapterOffset(v) + c,
              pages: _pagesPerChapter,
            ),
        ];
        volumes.add(
          _Volume(id: 100 + number * 10 + v, number: v, chapters: chapters),
        );
      }
      series.add(_Series(id: number, name: titles[i], volumes: volumes));
    }

    // Seeded progress, so the screenshots have a Continue to continue and an
    // On deck with something on it before the recipe marks anything itself.
    // One series is half-finished and one is barely started, which is also how
    // the on-deck ordering gets two different answers to sort.
    _chapter(1000 + 1 * 100 + 1 * 10 + 1)?.pagesRead = _pagesPerChapter;
    _chapter(1000 + 1 * 100 + 1 * 10 + 2)?.pagesRead = 3;
    _chapter(1000 + 3 * 100 + 1 * 10 + 1)?.pagesRead = _pagesPerChapter;
  }

  static const libraryId = 1;

  final List<_Series> series = [];

  List<_Chapter> get chapters => [
    for (final s in series)
      for (final v in s.volumes) ...v.chapters,
  ];

  _Series? seriesById(int? id) => series.where((s) => s.id == id).firstOrNull;

  _Chapter? chapterById(int? id) =>
      chapters.where((c) => c.id == id).firstOrNull;

  /// The series a volume belongs to, for a cover: a volume draws its series'
  /// picture, because the drawings are per series and a second set of covers
  /// would be four more things to keep in step for no visible difference.
  _Series? seriesOfVolume(int? volumeId) =>
      series.where((s) => s.volumes.any((v) => v.id == volumeId)).firstOrNull;

  _Series? seriesOfChapter(int? chapterId) => series
      .where(
        (s) => s.volumes.any((v) => v.chapters.any((c) => c.id == chapterId)),
      )
      .firstOrNull;

  _Chapter? _chapter(int id) => chapterById(id);

  bool underWay(_Series s) {
    final read = s.pagesRead;
    return read > 0 && read < s.pages;
  }

  /// Which drawing stands in for a series' cover. Cycled, so a shelf of four
  /// does not repeat one picture twice in a row.
  String coverDrawing(_Series? series) =>
      'cover-${((series?.id ?? 1) - 1) % 4 + 1}.png';

  /// Which drawing stands in for a page. Offset by the chapter, so turning a
  /// page visibly changes the picture.
  String pageDrawing(_Chapter chapter, int? page) =>
      'page-${((chapter.id + (page ?? 0)) % _pageDrawings) + 1}.png';

  Map<String, dynamic> seriesJson(_Series s) => {
    'id': s.id,
    'name': s.name,
    'libraryId': libraryId,
    'libraryName': _libraryName,
    'pages': s.pages,
    'pagesRead': s.pagesRead,
    // Kavita's MangaFormat.Archive: a chapter of pictures, which is what the
    // reader draws. An EPub here would send it looking for /api/Book instead.
    'format': 1,
    'latestReadDate': s.pagesRead > 0 ? '2026-01-01T00:00:00Z' : null,
  };

  Map<String, dynamic> volumeJson(_Volume v) => {
    'id': v.id,
    'name': 'Volume ${v.number}',
    'minNumber': v.number,
    'pages': v.chapters.fold(0, (n, c) => n + c.pages),
    'pagesRead': v.chapters.fold(0, (n, c) => n + c.pagesRead),
    'chapters': [for (final c in v.chapters) chapterJson(c)],
  };

  Map<String, dynamic> chapterJson(_Chapter c) => {
    'id': c.id,
    'title': 'Chapter ${c.number}',
    // The free-text title Kavita carries beside the number, empty here: the
    // screenshots want numbers, and a demo title would only be one more thing
    // to keep in step.
    'titleName': '',
    'range': '${c.number}',
    'minNumber': c.number,
    'pages': c.pages,
    'pagesRead': c.pagesRead,
    'isSpecial': false,
    'sortOrder': c.number.toDouble(),
    'format': 1,
  };

  Map<String, dynamic> chapterInfoJson(_Chapter c) {
    final owner = _ownerOf(c);
    return {
      'seriesId': owner.$1.id,
      'volumeId': owner.$2.id,
      'libraryId': libraryId,
      'pages': c.pages,
      'seriesName': owner.$1.name,
      'title': 'Chapter ${c.number}',
      'seriesFormat': 1,
      'libraryType': _libraryType,
      // Every page drawn at the same size, which is what the drawings are:
      // the app reads these to lay a vertical strip out before the images
      // arrive, and one size is the truth here.
      'pageDimensions': [
        for (var p = 1; p <= c.pages; p++)
          {'pageNumber': p, 'width': 1000, 'height': 1500, 'isWide': false},
      ],
    };
  }

  (_Series, _Volume) _ownerOf(_Chapter chapter) {
    for (final s in series) {
      for (final v in s.volumes) {
        if (v.chapters.contains(chapter)) {
          return (s, v);
        }
      }
    }
    throw StateError('chapter ${chapter.id} belongs to no volume');
  }

  /// Applies a write the app made — and there are two shapes of them.
  ///
  /// `/api/Reader/progress` carries one `chapterId` and the `pageNum` reached;
  /// `mark-multiple-read` / `-unread` carry a **list** under `chapterIds` and
  /// no page at all. Reading only the first is what makes a swipe on a row
  /// silently do nothing here while the app believes it worked, which is a
  /// screenshot of a screen that disagrees with itself.
  void record(Map<String, dynamic> body, {required bool read}) {
    final ids = <int>[
      if (body['chapterId'] is int) body['chapterId'] as int,
      for (final id in (body['chapterIds'] as List<dynamic>? ?? const []))
        if (id is int) id,
    ];
    final page = body['pageNum'];

    for (final id in ids) {
      final chapter = chapterById(id);
      if (chapter == null) continue;
      chapter.pagesRead = page is int
          // Reading: where in the chapter the reader got to.
          ? page.clamp(0, chapter.pages)
          // Marked by hand: whole, or nothing at all.
          : (read ? chapter.pages : 0);
    }
  }
}

/// A chapter's number within its series: volume 2 does not start at 1 again,
/// which is how Kavita numbers them too.
int volumeChapterOffset(int volume) => volume == 1 ? 0 : 3;

class _Chapter {
  _Chapter({required this.id, required this.number, required this.pages});

  final int id;
  final int number;
  final int pages;
  int pagesRead = 0;
}

class _Volume {
  _Volume({required this.id, required this.number, required this.chapters});

  final int id;
  final int number;
  final List<_Chapter> chapters;
}

class _Series {
  _Series({required this.id, required this.name, required this.volumes});

  final int id;
  final String name;
  final List<_Volume> volumes;

  /// Pages, and pages read, over every volume.
  ///
  /// The inner fold starts at zero and not at the outer accumulator: folding a
  /// list of lists with the running total in both counts the first volume
  /// twice, and a series of thirty pages reports forty-eight.
  int get pages =>
      volumes.fold(0, (n, v) => n + v.chapters.fold(0, (m, c) => m + c.pages));

  int get pagesRead => volumes.fold(
    0,
    (n, v) => n + v.chapters.fold(0, (m, c) => m + c.pagesRead),
  );
}

// ---- the wire --------------------------------------------------------------

Future<Map<String, dynamic>> _body(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.isEmpty) {
    return const {};
  }
  final decoded = jsonDecode(raw);
  return decoded is Map<String, dynamic> ? decoded : const {};
}

int? _query(HttpRequest request, String name) =>
    int.tryParse(request.uri.queryParameters[name] ?? '');

Future<void> _json(HttpRequest request, Object? body) async {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

Future<void> _text(HttpRequest request, int status, String body) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.text
    ..write(body);
  await request.response.close();
}

Future<void> _image(HttpRequest request, Directory root, String name) async {
  final file = File('${root.path}/$name');
  if (!file.existsSync()) {
    return _text(request, HttpStatus.notFound, '$name is not drawn yet');
  }
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType('image', 'png')
    ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
    ..add(await file.readAsBytes());
  await request.response.close();
}

String? _arg(List<String> args, String name) {
  final index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}
