import 'package:dio/dio.dart';

import '../../l10n/generated/app_localizations.dart';

/// What went wrong reaching a Kavita server, in the terms of someone who has
/// just typed an address into the login form.
///
/// A `DioException.toString()` names a type, a URI and often a Java or socket
/// error underneath it; put in front of a person it says only that something
/// failed. These are the distinctions that change what they would *do* next:
/// fix the address, wait, trust a certificate, retype a password.
enum ConnectionFailureKind {
  /// Nothing answered: no DNS record, connection refused, no route, or the
  /// platform blocking cleartext.
  unreachable,

  /// Something is listening but did not finish answering in time.
  timedOut,

  /// TLS was refused — a self-signed certificate the device does not trust
  /// is the usual reason on a self-hosted server.
  badCertificate,

  /// The server understood the login and rejected it.
  badCredentials,

  /// A web server answered, but Kavita is not what is behind that address.
  notKavita,

  /// Kavita answered, and it is having a problem of its own.
  serverError,

  /// Anything left: shown with the raw error, since we have nothing better.
  unknown,
}

/// A classified connection failure, and the message to show for it.
class ConnectionFailure {
  const ConnectionFailure(this.kind, {this.status, this.detail});

  final ConnectionFailureKind kind;

  /// The HTTP status behind [ConnectionFailureKind.serverError].
  final int? status;

  /// The raw error, shown only for [ConnectionFailureKind.unknown].
  final String? detail;

  /// Reads an error thrown by [KavitaClient] into something sayable.
  ///
  /// Kavita answers *every* credential-side failure of `/api/Account/login`
  /// with a bare 401 — unknown user, wrong password, locked-out account,
  /// disabled account, unconfirmed e-mail, password auth disabled — and the
  /// body it carries is plain text in the **server account's** locale, so the
  /// six cases can be told apart neither by status nor by anything we could
  /// show. One case covers them, worded so it stays true of a lockout.
  factory ConnectionFailure.from(Object error) {
    if (error is! DioException) {
      return ConnectionFailure(
        ConnectionFailureKind.unknown,
        detail: error.toString(),
      );
    }
    final kind = switch (error.type) {
      DioExceptionType.connectionError => ConnectionFailureKind.unreachable,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ConnectionFailureKind.timedOut,
      DioExceptionType.badCertificate => ConnectionFailureKind.badCertificate,
      DioExceptionType.badResponse => _fromStatus(error.response?.statusCode),
      // A 200 carrying a login page, an XML index or anything else that is
      // not the DTO fails in the *decode*, which dio reports as `unknown`
      // with no response attached at all — so the wrapped error is the only
      // thing left to read. Getting that far means bytes came back, and a
      // web server that is not Kavita is the ordinary way to get them: a
      // reverse proxy, a router's admin page, another app on the port.
      DioExceptionType.unknown => switch (error.error) {
        FormatException() || TypeError() => ConnectionFailureKind.notKavita,
        _ => ConnectionFailureKind.unknown,
      },
      _ => ConnectionFailureKind.unknown,
    };
    return ConnectionFailure(
      kind,
      status: error.response?.statusCode,
      detail: kind == ConnectionFailureKind.unknown ? error.toString() : null,
    );
  }

  static ConnectionFailureKind _fromStatus(int? status) => switch (status) {
    null => ConnectionFailureKind.unknown,
    401 => ConnectionFailureKind.badCredentials,
    >= 500 => ConnectionFailureKind.serverError,
    // Every other status on the login endpoint means a web server answered
    // and Kavita was not behind it: a proxy's 404, a portal's redirect.
    _ => ConnectionFailureKind.notKavita,
  };

  /// [host] names the server in the message; it is the address the user
  /// typed, not the URI, so a malformed one still reads.
  String message(AppLocalizations l10n, String host) => switch (kind) {
    ConnectionFailureKind.unreachable => l10n.connectionUnreachable(host),
    ConnectionFailureKind.timedOut => l10n.connectionTimedOut(host),
    ConnectionFailureKind.badCertificate => l10n.connectionBadCertificate(
      host,
    ),
    ConnectionFailureKind.badCredentials => l10n.connectionBadCredentials,
    ConnectionFailureKind.notKavita => l10n.connectionNotKavita(host),
    ConnectionFailureKind.serverError => l10n.connectionServerError(
      host,
      status ?? 0,
    ),
    ConnectionFailureKind.unknown => l10n.loginFailed(detail ?? ''),
  };
}
