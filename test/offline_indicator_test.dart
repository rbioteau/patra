import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/home/home_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// A server that is either there and empty, or not there at all.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.reachable = true});

  final bool reachable;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    if (!reachable) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
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

Future<void> _pumpHome(WidgetTester tester, {bool reachable = true}) async {
  mockPathProvider();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Built with `overrideWith`, not `overrideWithValue`: what turns a
        // failed request into the offline state is the client's
        // `onReachabilityChanged`, wired by the real provider. A ready-made
        // client has nobody to tell, and the indicator would never appear
        // however unreachable the server was.
        kavitaClientProvider.overrideWith((ref) {
          final client = KavitaClient(
            baseUrl: 'http://kavita.test',
            token: 'token',
            username: 'romain',
            apiKey: 'key',
            onReachabilityChanged: (reachable) =>
                ref.read(offlineProvider.notifier).set(!reachable),
          );
          client.httpClient.httpClientAdapter = _Adapter(reachable: reachable);
          client.bareHttpClient.httpClientAdapter = _Adapter(
            reachable: reachable,
          );
          return client;
        }),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  // Past the bounded retries, so the offline state has settled.
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

const _explanation =
    'Server unreachable — offline mode. Saved chapters remain readable.';

Finder get _cloud => find.byIcon(Icons.cloud_off_outlined);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('offline is a status in the bar, not a paragraph over the content', () {
    testWidgets('a reachable server shows nothing at all', (tester) async {
      await _pumpHome(tester, reachable: true);

      expect(_cloud, findsNothing);
      expect(find.text(_explanation), findsNothing);
    });

    testWidgets('an unreachable one puts a struck-through cloud in the bar', (
      tester,
    ) async {
      await _pumpHome(tester, reachable: false);

      expect(
        find.descendant(of: find.byType(AppBar), matching: _cloud),
        findsOneWidget,
        reason: 'the indicator belongs in the bar, beside the wordmark',
      );
      // The banner used to say this across the top of the content, pushing
      // the shelves down and repeating itself on every screen at once.
      expect(find.text(_explanation), findsNothing);
    });

    testWidgets('the icon carries the sentence for anyone who needs it', (
      tester,
    ) async {
      await _pumpHome(tester, reachable: false);

      // A struck-through cloud means nothing to a screen reader, and little
      // to someone meeting it for the first time — so the old banner text is
      // the tooltip, which is also the semantics label.
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: _cloud, matching: find.byType(IconButton)),
            )
            .tooltip,
        _explanation,
      );

      // And a tap says it in full, since a tooltip on a phone needs a
      // long-press nobody thinks to try.
      await tester.tap(_cloud);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_explanation), findsOneWidget);
    });
  });
}
