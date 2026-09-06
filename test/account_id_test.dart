import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/account_id.dart';

/// A JWT is three dot-separated base64url segments; only the middle one is
/// read here, and never its signature — this is our own token, not a
/// credential being verified.
String _jwt(Map<String, dynamic> claims) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS512'})}.${seg(claims)}.signature';
}

void main() {
  group('the account a token belongs to', () {
    // Kavita signs `nameid` (ASP.NET's ClaimTypes.NameIdentifier) with the
    // user's own id, and several endpoints want it back as a parameter.
    test('is read from the token we already hold', () {
      expect(accountIdFrom(_jwt({'name': 'rastalien', 'nameid': '1'})), 1);
      expect(accountIdFrom(_jwt({'nameid': '42'})), 42);
    });

    test('survives base64 that needs padding back on', () {
      // Segment lengths that are not a multiple of four are the normal case;
      // base64Url.decode refuses them without the padding restored.
      for (var i = 1; i < 40; i++) {
        final token = _jwt({'nameid': '7', 'pad': 'x' * i});
        expect(accountIdFrom(token), 7, reason: 'padding length $i');
      }
    });

    test('a token with no such claim yields nothing, never a throw', () {
      expect(accountIdFrom(_jwt({'name': 'rastalien'})), isNull);
      expect(accountIdFrom(_jwt({'nameid': 'not-a-number'})), isNull);
    });

    test('something that is not a token at all yields nothing', () {
      expect(accountIdFrom(''), isNull);
      expect(accountIdFrom('nonsense'), isNull);
      expect(accountIdFrom('a.b'), isNull);
      expect(accountIdFrom('a.!!!.c'), isNull);
    });
  });
}
