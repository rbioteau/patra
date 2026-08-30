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

/// A server that either answers the health probe or cannot be reached.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.reachable = true, this.healthStatus = 200});

  final bool reachable;

  /// What `/api/Health` answers when the server *is* there.
  final int healthStatus;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    paths.add(options.path);
    if (!reachable) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (options.path == '/api/Health') {
      // Kavita returns the plain string "Ok", not JSON.
      return ResponseBody.fromString(
        healthStatus == 200 ? 'Ok' : 'error',
        healthStatus,
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

Future<_Adapter> _pump(
  WidgetTester tester, {
  bool reachable = true,
  int healthStatus = 200,
}) async {
  mockPathProvider();
  final adapter = _Adapter(reachable: reachable, healthStatus: healthStatus);
  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          const AuthState(
            servers: [_server],
            activeUrl: 'https://kavita.example',
          ),
        ),
        kavitaClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
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

/// What a screen reader announces for the card.
///
/// The dot's `Semantics` label merges into the tappable card's own node
/// rather than standing as a node of its own, which is what one wants here:
/// one stop, announced whole — "Connected, kavita.example, romain, Switch
/// server" — instead of a bare status dot the user has to swipe onto.
///
/// The semantics tree is only built on demand, and its handle has to be
/// released before the framework's end-of-test check — which runs ahead of
/// `addTearDown` — so it is taken and dropped inside this call.
Future<String> _announcement(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await tester.pump();
  final label = tester.getSemantics(find.text('kavita.example')).label;
  handle.dispose();
  return label;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the server card says whether the server is really there', () {
    testWidgets('a server that answers is shown as connected', (tester) async {
      final adapter = await _pump(tester);

      expect(
        adapter.paths,
        contains('/api/Health'),
        reason: 'the dot has to ask something, not assume',
      );
      expect(_dotColor(tester), patraOnline);
      expect(await _announcement(tester), contains('Connected'));
      // Good news needs no caption; only the bad case is spelled out.
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('a server that cannot be reached is not shown green', (
      tester,
    ) async {
      await _pump(tester, reachable: false);

      // The regression this file exists for: the dot was a `const`
      // patraOnline, so it said "connected" from the moment it was drawn and
      // never asked anything.
      expect(_dotColor(tester), isNot(patraOnline));
      expect(_dotColor(tester), patraDanger);
      // Colour alone is no indicator at 8pt — two colours a good share of
      // people cannot tell apart — so the state is also said in words.
      expect(find.text('Offline'), findsOneWidget);
      expect(await _announcement(tester), contains('Offline'));
    });

    testWidgets('answering badly is not the same as not being there', (
      tester,
    ) async {
      // A Kavita having a bad day, or a reverse proxy that 404s the health
      // endpoint, still *answered*. A connectivity dot asks whether the
      // server can be reached, not whether it is happy — and painting it red
      // here would contradict the rest of the app, which is working.
      await _pump(tester, healthStatus: 500);

      expect(_dotColor(tester), patraOnline);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('a failed request outranks a probe that once succeeded', (
      tester,
    ) async {
      await _pump(tester);
      expect(_dotColor(tester), patraOnline);

      // The connection drops while the screen sits there. Nothing re-probes
      // on its own, but the next request anywhere in the app fails and sets
      // `offlineProvider` — which has to win over the stale success, or the
      // dot goes back to meaning "nobody has told us otherwise".
      final element = tester.element(find.byType(SettingsScreen));
      ProviderScope.containerOf(element)
          .read(offlineProvider.notifier)
          .set(true);
      await tester.pumpAndSettle();

      expect(_dotColor(tester), patraDanger);
      expect(find.text('Offline'), findsOneWidget);
      expect(await _announcement(tester), isNot(contains('Connected')));
    });
  });
}
