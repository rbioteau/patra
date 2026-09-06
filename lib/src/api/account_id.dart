import 'dart:convert';

/// Which Kavita account the session's own token belongs to.
///
/// Several endpoints take the caller's user id as a *parameter* rather than
/// reading it off the bearer token — `/api/Series/currently-reading` answers
/// **400** without it — and `UserDto.id` only reaches us at sign-in, which a
/// resumed session never does. The token, on the other hand, is what a session
/// *is* in this app: it is there on every path, including a resume, and it
/// already carries the answer.
///
/// Kavita signs `nameid`, which is ASP.NET's `ClaimTypes.NameIdentifier`, with
/// the user's own id. Nothing here verifies the signature and nothing should:
/// this is our own token being read for a value we are about to send back to
/// the server that issued it, not a credential being trusted.
///
/// Null for anything unreadable — a missing claim, a malformed token, an id
/// that is not a number. A caller that gets null simply omits the parameter
/// and is no worse off than before.
int? accountIdFrom(String token) {
  final segments = token.split('.');
  if (segments.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(_padded(segments[1]))),
    );
    if (payload is! Map) return null;
    final claim = payload['nameid'];
    return claim is int ? claim : int.tryParse('$claim');
  } catch (_) {
    // A token is whatever the server sent; unreadable is a null, never a throw.
    return null;
  }
}

/// A JWT strips base64's `=` padding, which `base64Url.decode` insists on.
String _padded(String segment) =>
    segment.padRight(segment.length + (4 - segment.length % 4) % 4, '=');
