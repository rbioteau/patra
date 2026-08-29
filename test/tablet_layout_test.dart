import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/home/home_screen.dart';
import 'package:patra/src/features/library/library_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/cover.dart';

import 'test_support.dart';

/// A server with [libraries] libraries and [series] series in the first one.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.libraries = 1, this.series = 0});

  final int libraries;
  final int series;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    return switch (options.path) {
      '/api/Library/libraries' => json([
        for (var i = 1; i <= libraries; i++)
          {'id': i, 'name': 'Library $i', 'type': 0},
      ]),
      '/api/Series/all-v2' => json([
        for (var i = 1; i <= series; i++)
          {
            'id': i,
            'name': 'Series $i',
            'libraryId': 1,
            'libraryName': 'Library 1',
            'pages': 100,
            'pagesRead': 0,
          },
      ]),
      // The home shelves stay empty: this is about the libraries under them.
      _ => json(const <Object>[]),
    };
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pump(WidgetTester tester, Widget screen, _Adapter adapter) async {
  mockPathProvider();
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
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// How many of [finder] share the top edge of the first one.
int _acrossOneRow(WidgetTester tester, Finder finder) {
  final top = tester.getTopLeft(finder.first).dy;
  var count = 0;
  for (var i = 0; i < finder.evaluate().length; i++) {
    if (tester.getTopLeft(finder.at(i)).dy == top) count++;
  }
  return count;
}

/// An iPad in portrait: 820x1180 logical points.
void _iPad(WidgetTester tester) {
  tester.view.physicalSize = const Size(1640, 2360);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// A phone: 390x844 logical points.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the library grid grows by column, not by cover', () {
    testWidgets('three across on a phone, as the handoff draws it', (
      tester,
    ) async {
      _phone(tester);
      await _pump(
        tester,
        const LibraryScreen(),
        _Adapter(libraries: 1, series: 12),
      );

      expect(_acrossOneRow(tester, find.byType(CoverTile)), 3);
    });

    testWidgets('more across on a tablet, and the covers keep their size', (
      tester,
    ) async {
      _iPad(tester);
      await _pump(
        tester,
        const LibraryScreen(),
        _Adapter(libraries: 1, series: 12),
      );

      expect(_acrossOneRow(tester, find.byType(CoverTile)), greaterThan(3));
      // Three across an iPad would be a 250pt cover: the grid takes columns
      // instead, and a cover stays the size it is drawn at.
      expect(
        tester.getSize(find.byType(CoverTile).first).width,
        lessThanOrEqualTo(150),
      );
    });
  });

  group('the home library cards fill the row they are given', () {
    Finder cardOf(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(SizedBox));

    testWidgets('two across on a phone', (tester) async {
      _phone(tester);
      await _pump(tester, const HomeScreen(), _Adapter(libraries: 6));

      expect(_acrossOneRow(tester, cardOf('Library 1')), 1);
      expect(
        tester.getTopLeft(cardOf('Library 2').first).dy,
        tester.getTopLeft(cardOf('Library 1').first).dy,
      );
      // Two per row: the third card starts a new one.
      expect(
        tester.getTopLeft(cardOf('Library 3').first).dy,
        greaterThan(tester.getTopLeft(cardOf('Library 1').first).dy),
      );
    });

    testWidgets('more across on a tablet, none of them a long empty bar', (
      tester,
    ) async {
      _iPad(tester);
      await _pump(tester, const HomeScreen(), _Adapter(libraries: 6));

      final first = tester.getTopLeft(cardOf('Library 1').first).dy;
      expect(tester.getTopLeft(cardOf('Library 3').first).dy, first);
      expect(
        tester.getSize(cardOf('Library 1').first).width,
        lessThanOrEqualTo(200),
      );
    });
  });
}
