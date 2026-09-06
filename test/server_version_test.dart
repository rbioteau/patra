import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/settings/settings_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// A server that answers the health probe, and answers the version endpoint
/// however this test needs it to.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.versionStatus = 200, this.versionBody = '0.9.1.4', this.held});

  final int versionStatus;

  /// The raw body `/api/Plugin/version` returns. A `String` is what Kavita
  /// really sends; anything else stands in for a future that returns JSON.
  final Object? versionBody;

  /// Gates the version answer, so a test can look at the card while the
  /// request is still in flight.
  final Completer<void>? held;

  final paths = <String>[];
  final queries = <String, Map<String, dynamic>>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    paths.add(options.path);
    queries[options.path] = options.queryParameters;
    if (options.path == '/api/Plugin/version') {
      await held?.future;
      return ResponseBody.fromString(
        versionBody is String ? versionBody! as String : jsonEncode(versionBody),
        versionStatus,
        headers: {
          Headers.contentTypeHeader: [
            versionBody is String ? 'text/plain' : Headers.jsonContentType,
          ],
        },
      );
    }
    if (options.path == '/api/Health') {
      return ResponseBody.fromString(
        'Ok',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(const <Object>[]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _server = ServerEntry(
  baseUrl: 'https://kavita.example',
  username: 'romain',
  token: 'token',
  refreshToken: 'refresh',
  apiKey: 'key',
);

KavitaClient _client(_Adapter adapter, {void Function()? onSessionExpired}) {
  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
    onSessionExpired: onSessionExpired,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;
  return client;
}

Future<_Adapter> _pump(WidgetTester tester, {_Adapter? adapter}) async {
  mockPathProvider();
  final used = adapter ?? _Adapter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          const AuthState(
            servers: [_server],
            activeUrl: 'https://kavita.example',
          ),
        ),
        kavitaClientProvider.overrideWithValue(_client(used)),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  return used;
}

/// The reachability dot: the one circular Container inside the server card.
Color _dotColor(WidgetTester tester) {
  final card = find
      .ancestor(of: find.text('kavita.example'), matching: find.byType(InkWell))
      .first;
  final dot = tester
      .widgetList<Container>(
        find.descendant(of: card, matching: find.byType(Container)),
      )
      .firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
  return (dot.decoration! as BoxDecoration).color!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the server card names the release it is talking to', () {
    testWidgets('the version is shown once the server answers', (tester) async {
      final adapter = await _pump(tester);
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('/api/Plugin/version'));
      // `[AllowAnonymous]`: the key in the query string is the whole of the
      // authentication, which is why this endpoint is open to a non-admin at
      // all where `server-info-slim` is not.
      expect(adapter.queries['/api/Plugin/version'], {'apiKey': 'key'});
      // Verbatim, four parts and no `v` — the string Kavita's own admin
      // screen prints, so the two can be read against each other.
      expect(find.text('Kavita 0.9.1.4'), findsOneWidget);
    });

    testWidgets('nothing is said before the answer arrives', (tester) async {
      final held = Completer<void>();
      await _pump(tester, adapter: _Adapter(held: held));
      await tester.pump();

      // Not a placeholder, not "unknown": the absence of the line is never
      // itself a message. The card already has a dot and a word for the case
      // where something is wrong.
      expect(find.textContaining('Kavita'), findsNothing);

      held.complete();
      await tester.pumpAndSettle();
      expect(find.text('Kavita 0.9.1.4'), findsOneWidget);
    });

    testWidgets('being offline takes the version away', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Kavita 0.9.1.4'), findsOneWidget);

      // The connection drops while the screen sits there, with a perfectly
      // good version already in hand. It still has to go: a version is only
      // ever true of a server we can reach *now*, and the alternative reads
      // "romain · Kavita 0.9.1.4 · Offline" — asserting a fact about the
      // server in the same breath as admitting we cannot reach it.
      final element = tester.element(find.byType(SettingsScreen));
      ProviderScope.containerOf(element)
          .read(offlineProvider.notifier)
          .set(true);
      await tester.pumpAndSettle();

      expect(find.textContaining('Kavita'), findsNothing);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('a server that will not name itself is still connected', (
      tester,
    ) async {
      // The invariant this file exists for. The version and the dot are two
      // requests on purpose, and folding them into one is the tidy-up someone
      // will reach for later: the endpoints share their auth properties and
      // one call would do. But an old Kavita 404s this endpoint and an
      // expired auth key 401s it, both from a server that is plainly up — so
      // a version we cannot get must leave the dot exactly where it was.
      // The symptom of getting this wrong looks like a network bug.
      await _pump(tester, adapter: _Adapter(versionStatus: 404));
      await tester.pumpAndSettle();

      expect(_dotColor(tester), patraOnline);
      expect(find.text('Offline'), findsNothing);
      expect(find.textContaining('Kavita'), findsNothing);
    });
  });

  group('what the client will accept as a version', () {
    test('a plain-text body is read as it stands', () async {
      final adapter = _Adapter(versionBody: '0.9.1.4\n');
      expect(await _client(adapter).serverVersion(), '0.9.1.4');
    });

    test('a body that is not a string is no answer at all', () async {
      // The contract oracle deliberately does not assert response types, so
      // a future Kavita answering `{"version": …}` has to be caught here —
      // or a stringified map is what lands on the card.
      final adapter = _Adapter(versionBody: {'version': '0.9.1.4'});
      expect(await _client(adapter).serverVersion(), isNull);
    });

    test('an expired auth key does not end the session', () async {
      // `/api/Plugin/version` is `[AllowAnonymous]` and authenticated by the
      // query key alone — Kavita never reads the Bearer header on it — so its
      // 401 says the *key* expired, never that the JWT did. Left in the
      // ordinary 401 path it would spend a token refresh, replay a request
      // that must 401 again, and, if that refresh failed, sign the user out
      // over a version string.
      var expired = false;
      final adapter = _Adapter(versionStatus: 401);
      final client = _client(adapter, onSessionExpired: () => expired = true);

      await expectLater(client.serverVersion(), throwsA(isA<DioException>()));

      expect(expired, isFalse);
      expect(adapter.paths, isNot(contains('/api/Account/refresh-token')));
      expect(
        adapter.paths.where((p) => p == '/api/Plugin/version'),
        hasLength(1),
        reason: 'a 401 here is final; there is nothing to retry it with',
      );
    });
  });
}
