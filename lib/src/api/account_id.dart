import 'dart:convert';

/// Which Kavita account the session's own token belongs to.
///
/// **This is what a profile is keyed on.** `Profile.id` is `(baseUrl,
/// accountId)`, and `UserDto.id` only ever arrives in a sign-in response —
/// which a resumed session never makes. The token, on the other hand, is what
/// a session *is* in this app: it is there on every path, including a resume,
/// and it already carries the answer.
///
/// Kavita signs the id into `nameid`: `TokenService.CreateToken` adds
/// `new(NameIdentifier, user.Id.ToString())`, and the legacy
/// `JwtSecurityTokenHandler` it writes with maps that long claim URI to the
/// short `nameid` on the way out. Nothing here verifies the signature and
/// nothing should: this is our own token being read for a value we key our
/// own storage on, not a credential being trusted.
///
/// Null for anything unreadable — a missing claim, a malformed token, an id
/// that is not a number. `Profile.id` then falls back to the username, which
/// costs exactly the rename this exists to survive.
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
