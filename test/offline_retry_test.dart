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

/// A server that is simply not there, as on a device with no network.
class _Unreachable implements HttpClientAdapter {
  var calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    calls++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Unreachable> _pumpHome(WidgetTester tester) async {
  mockPathProvider();
  final adapter = _Unreachable();
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
  );
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [kavitaClientProvider.overrideWithValue(client)],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an offline start settles instead of retrying forever', (
    tester,
  ) async {
    final adapter = await _pumpHome(tester);

    // Home asks for three things: continue-reading, on-deck and libraries.
    expect(adapter.calls, 3, reason: 'the screen should have tried once each');

    // A short bounded backoff catches a momentary blip...
    await tester.pump(const Duration(seconds: 5));
    final settled = adapter.calls;
    expect(
      settled,
      lessThanOrEqualTo(9),
      reason: 'three attempts per provider at most, not an open-ended climb',
    );

    // ...and then it stops. Riverpod 3 retries a failed provider on its own,
    // with exponential backoff and no ceiling: unbounded, this reached 33
    // requests within the minute and kept going, each attempt dropping the
    // providers back to loading so the screen never left its skeleton. That
    // is what an offline start looked like on a real device.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 5));
    }

    expect(
      adapter.calls,
      settled,
      reason:
          'a minute later the app had made ${adapter.calls} requests rather '
          'than the $settled it had settled on — it is still looping',
    );
  });
}
