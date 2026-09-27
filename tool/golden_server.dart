/// The host half of the device golden: a Kavita that answers with what a real
/// one said, and a hand on the device the test cannot reach itself.
///
/// ```sh
/// ./tool/device_golden.sh                   # the one command; it runs this
///
/// dart run tool/golden_server.dart --device <id>
/// dart run tool/golden_server.dart --device <id> --record http://localhost:5055
/// ```
///
/// **Why a recording and not a Kavita.** What the golden photographs is the
/// page Kavita makes of a book, drawn by the web engine that ships, and the
/// page is only worth comparing if it is the same page every run. A live
/// server moves under that — an upgrade rewrites its HTML, a scan renumbers
/// its ids, and a release would wait on a container. So the server's answers
/// are recorded once, from a real Kavita reading `golden-book.epub`, and
/// replayed here byte for byte: the page is Kavita's own and the run needs
/// nothing but this file and a phone.
///
/// **_Recording is the test itself**, run through this as a proxy
/// (`--record <kavita>`): every request the app made on its way to the page
/// and back is forwarded and written down, so the recording holds exactly
/// what the app asks — no list here to keep in step with the client. Replay
/// answers only what was recorded, and anything else is a 404 printed on
/// stderr: an app that starts asking something new fails the next run loudly
/// rather than drawing a page nobody recorded.
///
/// The recorded server's credentials never reach the repository: the token,
/// refresh token and auth key the login answered with are replaced in every
/// body before it is written — the token by one of the same shape, since the
/// app reads the account id out of it.
///
/// **The control port** (`--port` + 1) is how the test on the device asks the
/// host for the two things it cannot do itself: a screenshot of the glass —
/// `adb exec-out screencap`, the whole screen as the reader sees it, the web
/// view included — and the server going away, by removing the `adb reverse`
/// the device reaches it through, which is a refused connection and therefore
/// exactly what being offline is to the app.
///
/// It never ships: it is a `tool/`, like `tool/demo_server.dart`.
library;

import 'dart:convert';
import 'dart:io';

const _defaultRecording = 'integration_test/golden/kavita';

/// What the login's secrets are replaced with. The token keeps a JWT's shape
/// and the account id in its `nameid`, because a profile is keyed on it
/// (`accountIdFrom`); it is signed by nobody and grants nothing.
final _placeholderToken = [
  base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}')),
  base64Url.encode(utf8.encode('{"nameid":"1","name":"golden"}')),
  'golden',
].map((part) => part.replaceAll('=', '')).join('.');
const _placeholderRefresh = 'golden-refresh-token';
const _placeholderApiKey = 'golden-api-key';

void main(List<String> args) async {
  final port = int.parse(_arg(args, '--port') ?? '5000');
  final controlPort = port + 1;
  final device = _arg(args, '--device');
  final upstream = _arg(args, '--record');
  final recording = Directory(_arg(args, '--recording') ?? _defaultRecording);
  final shots = Directory(_arg(args, '--shots') ?? 'build/golden');
  final adb = _arg(args, '--adb') ?? 'adb';

  if (device == null) {
    stderr.writeln('--device <id> is required: the control port drives it.');
    exit(2);
  }

  final _Recording store;
  if (upstream != null) {
    if (recording.existsSync()) recording.deleteSync(recursive: true);
    recording.createSync(recursive: true);
    store = _Recording.empty(recording);
  } else {
    final index = File('${recording.path}/index.json');
    if (!index.existsSync()) {
      stderr.writeln(
        '${index.path} is missing — record one first (see '
        'integration_test/golden/README.md).',
      );
      exit(1);
    }
    store = _Recording.read(recording);
  }

  final client = HttpClient();
  final kavita = _Kavita(
    port: port,
    answer: (request) => upstream != null
        ? _forward(request, client, Uri.parse(upstream), store)
        : _replay(request, store),
  );
  await kavita.start();
  final control = await HttpServer.bind(InternetAddress.anyIPv4, controlPort);
  final phone = _Device(
    adb: adb,
    id: device,
    port: port,
    shots: shots,
    kavita: kavita,
  );

  stdout.writeln(
    upstream != null
        ? 'recording $upstream on http://localhost:$port into ${recording.path}'
        : 'replaying ${store.length} answers on http://localhost:$port',
  );
  stdout.writeln('control on http://localhost:$controlPort, driving $device');

  await for (final request in control) {
    await _control(request, phone);
  }
}

/// The Kavita port, which can be taken away and given back.
///
/// Taken away means **closed with its connections**, not merely unreachable
/// for new ones: the app keeps its connection alive between requests, and
/// the first version of this removed only the `adb reverse` — the saved copy
/// was then "read offline" over a connection that was still open, and the
/// log showed the server answering every request the offline half made.
class _Kavita {
  _Kavita({required this.port, required this.answer});

  final int port;
  final Future<void> Function(HttpRequest request) answer;
  HttpServer? _server;

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen((request) async {
      try {
        await answer(request);
      } on Exception catch (error) {
        stderr.writeln('${request.method} ${request.uri}: $error');
        try {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
        } on Exception {
          // The connection went with the server; nobody is left to tell.
        }
      }
      stdout.writeln(
        '${request.method.padRight(4)} ${request.response.statusCode} '
        '${_key(request.method, request.uri)}',
      );
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

// ---- replay ----------------------------------------------------------------

Future<void> _replay(HttpRequest request, _Recording store) async {
  // The body is read and dropped: a write is answered as it was answered on
  // the day, and a filter is one library's worth of the same answer.
  await request.drain<void>();
  final answer = store.answer(_key(request.method, request.uri));
  if (answer == null) {
    stderr.writeln(
      'NOT RECORDED ${_key(request.method, request.uri)} — the app asked '
      'something the recording never saw; record again.',
    );
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }
  request.response.statusCode = answer.status;
  if (answer.contentType != null) {
    request.response.headers.contentType = ContentType.parse(
      answer.contentType!,
    );
  }
  request.response.add(answer.body);
  await request.response.close();
}

// ---- recording -------------------------------------------------------------

Future<void> _forward(
  HttpRequest request,
  HttpClient client,
  Uri upstream,
  _Recording store,
) async {
  final body = await request.fold<List<int>>([], (all, b) => all..addAll(b));
  // The app only ever saw the placeholders, so they are turned back into
  // the recorded server's own credentials on the way up.
  final target = upstream.replace(
    path: request.uri.path,
    query: request.uri.hasQuery ? store.restore(request.uri.query) : null,
  );
  final out = await client.openUrl(request.method, target);
  request.headers.forEach((name, values) {
    const skipped = {'host', 'content-length', 'accept-encoding', 'connection'};
    if (skipped.contains(name.toLowerCase())) return;
    for (final value in values) {
      out.headers.add(name, store.restore(value));
    }
  });
  out.add(utf8.encode(store.restore(utf8.decode(body, allowMalformed: true))));
  final answer = await out.close();
  final bytes = await answer.fold<List<int>>([], (all, b) => all..addAll(b));
  final contentType = answer.headers.contentType?.toString();

  if (request.uri.path.toLowerCase() == '/api/account/login' &&
      answer.statusCode == HttpStatus.ok) {
    store.learnSecrets(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
  }

  final kept = store.keep(
    _key(request.method, request.uri),
    answer.statusCode,
    contentType,
    bytes,
  );

  request.response.statusCode = answer.statusCode;
  if (contentType != null) {
    request.response.headers.contentType = ContentType.parse(contentType);
  }
  // What the app is handed is what the recording will hand it next time, so
  // a recording run already draws the sanitised answers.
  request.response.add(kept);
  await request.response.close();
}

/// The recorded answers, and the file that lists them.
class _Recording {
  _Recording.empty(this.directory);

  _Recording.read(this.directory) {
    final index = jsonDecode(
      File('${directory.path}/index.json').readAsStringSync(),
    ) as List<dynamic>;
    for (final entry in index.cast<Map<String, dynamic>>()) {
      _answers[entry['key'] as String] = _Answer(
        status: entry['status'] as int,
        contentType: entry['contentType'] as String?,
        file: entry['file'] as String,
        body: File('${directory.path}/${entry['file']}').readAsBytesSync(),
      );
    }
  }

  final Directory directory;
  final _answers = <String, _Answer>{};
  final _secrets = <String, String>{};

  int get length => _answers.length;

  _Answer? answer(String key) => _answers[key];

  /// Remembers what the login answered with, so it can be taken out of
  /// everything written from here on.
  ///
  /// Every key and token in it, and not only the three the app reads: the
  /// login also lists the account's other auth keys, and Kavita signs the
  /// pictures in a book's pages with one of those — the first recording
  /// carried it into the repository inside a page's HTML.
  void learnSecrets(Map<String, dynamic> login) {
    final named = {
      'token': _placeholderToken,
      'refreshToken': _placeholderRefresh,
      'apiKey': _placeholderApiKey,
    };
    void walk(Object? node, String? field) {
      if (node is Map<String, dynamic>) {
        node.forEach((name, value) => walk(value, name));
      } else if (node is List<dynamic>) {
        for (final value in node) {
          walk(value, field);
        }
      } else if (node is String &&
          node.length >= 8 &&
          field != null &&
          RegExp('key|token', caseSensitive: false).hasMatch(field)) {
        _secrets.putIfAbsent(
          node,
          () => named[field] ?? 'golden-auth-key-${_secrets.length}',
        );
      }
    }

    walk(login, null);
  }

  /// Writes one answer down — the first one only, so a question asked twice
  /// is answered the way it was answered first: where the reader was when
  /// the book was opened, not where the recording run left it.
  List<int> keep(String key, int status, String? contentType, List<int> body) {
    final sanitised = _sanitise(contentType, body);
    if (_answers.containsKey(key)) return sanitised;

    final file =
        '${_answers.length.toString().padLeft(3, '0')}-'
        '${key.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase()}'
        '${_extension(contentType)}';
    final trimmed = file.length > 120
        ? '${file.substring(0, 110)}${_extension(contentType)}'
        : file;
    File('${directory.path}/$trimmed').writeAsBytesSync(sanitised);
    _answers[key] = _Answer(
      status: status,
      contentType: contentType,
      file: trimmed,
      body: sanitised,
    );
    _writeIndex();
    return sanitised;
  }

  /// The other direction: a placeholder the app sends back becomes the
  /// secret it stands for, so the recorded server is spoken to in its own
  /// credentials.
  String restore(String text) {
    var restored = text;
    _secrets.forEach((secret, placeholder) {
      restored = restored.replaceAll(placeholder, secret);
    });
    return restored;
  }

  List<int> _sanitise(String? contentType, List<int> body) {
    final type = contentType ?? '';
    final textual = ['json', 'text', 'html', 'xml', 'css'].any(type.contains);
    if (!textual) return body;
    var text = utf8.decode(body, allowMalformed: true);
    _secrets.forEach((secret, placeholder) {
      text = text.replaceAll(secret, placeholder);
    });
    // And any key an address carries or token a body holds that the login
    // did not list — a token renewed mid-run is not in the login's answer:
    // a credential in a recording is one too many, whoever minted it.
    text = text.replaceAllMapped(
      RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'),
      (match) => match[0] == _placeholderToken ? match[0]! : _placeholderToken,
    );
    text = text.replaceAllMapped(
      RegExp(r'(apiKey=)(?!golden-)[^&"\s]+', caseSensitive: false),
      (match) => '${match[1]}golden-unknown-key',
    );
    return utf8.encode(text);
  }

  void _writeIndex() {
    final entries = [
      for (final MapEntry(:key, :value) in _answers.entries)
        {
          'key': key,
          'status': value.status,
          'contentType': value.contentType,
          'file': value.file,
        },
    ];
    File('${directory.path}/index.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
    );
  }
}

class _Answer {
  _Answer({
    required this.status,
    required this.contentType,
    required this.file,
    required this.body,
  });

  final int status;
  final String? contentType;
  final String file;
  final List<int> body;
}

/// What a request is recorded under: its method, its path, and its query
/// without the auth key — which is a credential, differs between the
/// recording and the replay, and says nothing about what is being asked.
String _key(String method, Uri uri) {
  final query = Map.of(uri.queryParameters)
    ..removeWhere((name, _) => name.toLowerCase() == 'apikey');
  final names = query.keys.toList()..sort();
  final rest = [for (final name in names) '$name=${query[name]}'].join('&');
  return '$method ${uri.path}${rest.isEmpty ? '' : '?$rest'}';
}

String _extension(String? contentType) {
  final type = contentType ?? '';
  if (type.contains('json')) return '.json';
  if (type.contains('html')) return '.html';
  if (type.contains('png')) return '.png';
  if (type.contains('jpeg')) return '.jpg';
  if (type.contains('css')) return '.css';
  if (type.contains('text')) return '.txt';
  return '.bin';
}

// ---- the device ------------------------------------------------------------

Future<void> _control(HttpRequest request, _Device device) async {
  await request.drain<void>();
  final (status, said) = switch (request.uri.path) {
    '/capture' => await device.capture(
      request.uri.queryParameters['name'] ?? 'shot',
    ),
    '/offline' => await device.unplug(),
    '/online' => await device.plug(),
    _ => (HttpStatus.notFound, 'no control ${request.uri.path}'),
  };
  stdout.writeln('control ${request.uri.path}: $said');
  request.response
    ..statusCode = status
    ..write(said);
  await request.response.close();
}

class _Device {
  _Device({
    required this.adb,
    required this.id,
    required this.port,
    required this.shots,
    required this.kavita,
  });

  final _Kavita kavita;
  final String adb;
  final String id;
  final int port;
  final Directory shots;

  /// The glass, as it is: `screencap` reads what the display composed, so
  /// the web view is in it as the reader sees it — which is the whole reason
  /// the host takes the picture rather than the test's own binding.
  Future<(int, String)> capture(String name) async {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name)) {
      return (HttpStatus.badRequest, 'a shot is named in [a-z0-9-]');
    }
    final result = await Process.run(adb, [
      '-s',
      id,
      'exec-out',
      'screencap',
      '-p',
    ], stdoutEncoding: null);
    if (result.exitCode != 0) {
      return (HttpStatus.internalServerError, '${result.stderr}');
    }
    shots.createSync(recursive: true);
    final file = File('${shots.path}/$name.png')
      ..writeAsBytesSync(result.stdout as List<int>);
    return (HttpStatus.ok, 'wrote ${file.path}');
  }

  /// The server goes away the way a train takes it away: the device's
  /// connection is refused.
  Future<(int, String)> unplug() async {
    await kavita.stop();
    return _adb([
      'reverse',
      '--remove',
      'tcp:$port',
    ], 'the server is unreachable');
  }

  Future<(int, String)> plug() async {
    await kavita.start();
    return _adb(['reverse', 'tcp:$port', 'tcp:$port'], 'the server is back');
  }

  Future<(int, String)> _adb(List<String> command, String done) async {
    final result = await Process.run(adb, ['-s', id, ...command]);
    return result.exitCode == 0
        ? (HttpStatus.ok, done)
        : (HttpStatus.internalServerError, '${result.stderr}');
  }
}

String? _arg(List<String> args, String name) {
  final index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}
