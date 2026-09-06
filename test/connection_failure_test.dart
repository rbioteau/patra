import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/connection_failure.dart';
import 'package:patra/src/api/kavita_client.dart';

/// Answers the login call with whatever a wrong address would answer with.
class _Adapter implements HttpClientAdapter {
  /// [contentType] is part of the case, not decoration: ASP.NET returns
  /// `Unauthorized("message")` as **text/plain**, and what dio does with a
  /// body depends on it — a wrong one here would test a server that does
  /// not exist.
  _Adapter.responds(this.status, this.body, this.contentType)
    : throws = null,
      raw = null;
  _Adapter.fails(this.throws)
    : status = 0,
      body = '',
      contentType = 'text/plain',
      raw = null;

  /// Throws a real exception from the socket, rather than a DioException of
  /// a chosen type — which is the only way to find out what dio makes of it.
  _Adapter.raises(this.raw)
    : status = 0,
      body = '',
      contentType = 'text/plain',
      throws = null;

  final int status;
  final String body;
  final String contentType;
  final DioExceptionType? throws;
  final Object? raw;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    final thrown = raw;
    if (thrown != null) throw thrown;
    final type = throws;
    if (type != null) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<ConnectionFailure> _failureOf(
  _Adapter adapter, {
  bool onWeb = false,
}) async {
  try {
    await KavitaClient.login(
      baseUrl: 'http://kavita.test',
      username: 'u',
      password: 'p',
      adapter: adapter,
    );
    fail('login should not have succeeded');
  } on Object catch (e) {
    return ConnectionFailure.from(e, onWeb: onWeb);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a failed login says what to do about it', () {
    test('Kavita rejects the credentials with a bare 401', () async {
      // Verified against Kavita's AccountController: an unknown user, a wrong
      // password, a locked-out account, a disabled one, an unconfirmed
      // e-mail and password-auth-disabled all return Unauthorized, carrying
      // plain text in the *server account's* locale. One case covers them.
      final failure = await _failureOf(
        _Adapter.responds(
          401,
          'Your credentials are not correct',
          'text/plain',
        ),
      );
      expect(failure.kind, ConnectionFailureKind.badCredentials);
    });

    test('a web server that is not Kavita 404s the login endpoint', () async {
      final failure = await _failureOf(
        _Adapter.responds(404, '<html>404</html>', 'text/html'),
      );
      expect(failure.kind, ConnectionFailureKind.notKavita);
    });

    test('a 200 carrying someone else\'s page is not Kavita either', () async {
      // A router's admin page or a reverse proxy's landing page answers 200
      // with HTML, which fails in the decode rather than on the wire — the
      // ordinary result of typing an address that hosts something else.
      final failure = await _failureOf(
        _Adapter.responds(200, '<html><body>hello</body></html>', 'text/html'),
      );
      expect(failure.kind, ConnectionFailureKind.notKavita);
    });

    test('Kavita having a problem of its own is not the user\'s', () async {
      final failure = await _failureOf(
        _Adapter.responds(500, 'boom', 'text/plain'),
      );
      expect(failure.kind, ConnectionFailureKind.serverError);
      expect(failure.status, 500);
    });

    test('nothing answers at all', () async {
      final failure = await _failureOf(
        _Adapter.fails(DioExceptionType.connectionError),
      );
      expect(failure.kind, ConnectionFailureKind.unreachable);
    });

    test('in a browser, nothing answering is not the only reading', () async {
      // Chrome reports a server that is not there and a server that refused
      // the request through the *same* XHR error event, and dio calls both
      // `connectionError`. Refusal is the common case rather than the exotic
      // one: Kavita's production CORS policy (Startup.cs) calls
      // AllowAnyHeader/AllowAnyMethod/AllowCredentials and never names an
      // origin, so it sends `Access-Control-Allow-Origin` to nobody and a
      // browser build is refused by every server it can in fact reach.
      // Blaming the network there told someone on a public HTTPS domain to
      // check they were on the same Wi-Fi as their server.
      final failure = await _failureOf(
        _Adapter.fails(DioExceptionType.connectionError),
        onWeb: true,
      );
      expect(failure.kind, ConnectionFailureKind.blockedByBrowser);
    });

    test('something listens but does not finish', () async {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = await _failureOf(_Adapter.fails(type));
        expect(failure.kind, ConnectionFailureKind.timedOut, reason: '$type');
      }
    });

    test('TLS is refused', () async {
      final failure = await _failureOf(
        _Adapter.fails(DioExceptionType.badCertificate),
      );
      expect(failure.kind, ConnectionFailureKind.badCertificate);
    });

    test('a self-signed certificate is named, not dumped', () async {
      // dio only ever raises DioExceptionType.badCertificate from an adapter
      // given a `validateCertificate` callback, which this app does not set.
      // What a self-signed server really produces is a HandshakeException —
      // a TlsException, so neither the SocketException nor the HttpException
      // dio's IO adapter catches — which arrives wrapped as `unknown`. Left
      // unmatched, the one screen where a self-hoster meets this showed the
      // raw dio dump.
      final failure = await _failureOf(
        _Adapter.raises(const HandshakeException('CERTIFICATE_VERIFY_FAILED')),
      );
      expect(failure.kind, ConnectionFailureKind.badCertificate);
    });

    test('a refusal is not a wrong address', () async {
      // Kavita's AdminPolicy answers 403, which every non-login caller can
      // meet — asking for a scan with an account that is not, or is no
      // longer, an admin. Lumped in with the catch-all it read "there is no
      // Kavita server behind that address", which describes nothing.
      final failure = await _failureOf(
        _Adapter.responds(403, 'Forbidden', 'text/plain'),
      );
      expect(failure.kind, ConnectionFailureKind.forbidden);
    });

    test('anything else keeps the raw error rather than inventing one', () {
      final failure = ConnectionFailure.from(StateError('nope'));
      expect(failure.kind, ConnectionFailureKind.unknown);
      expect(failure.detail, contains('nope'));
    });
  });

  group('the message is one a person can act on', () {
    late AppLocalizations en;
    late AppLocalizations fr;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
      fr = await AppLocalizations.delegate.load(const Locale('fr'));
    });

    test('every case says something different, and names the server', () {
      final seen = <String>{};
      for (final kind in ConnectionFailureKind.values) {
        final message = ConnectionFailure(
          kind,
          status: 500,
          detail: 'raw',
        ).message(en, 'kavita.lan');
        expect(seen.add(message), isTrue, reason: '$kind repeats a message');
        // The dio type, the URI and the socket error under it are what this
        // whole file exists to keep off the login screen.
        expect(message, isNot(contains('DioException')));
        // The classifier reports a failed scan from the Library tab too, so
        // no message may be worded for the login screen.
        expect(message, isNot(contains('sign in')));
        if (kind != ConnectionFailureKind.badCredentials &&
            kind != ConnectionFailureKind.unknown) {
          expect(message, contains('kavita.lan'), reason: '$kind');
        }
      }
    });

    test('French says it too, and never falls back to English', () {
      for (final kind in ConnectionFailureKind.values) {
        final failure = ConnectionFailure(kind, status: 500, detail: 'raw');
        expect(
          failure.message(fr, 'kavita.lan'),
          isNot(failure.message(en, 'kavita.lan')),
          reason: '$kind is not translated',
        );
      }
    });
  });
}
