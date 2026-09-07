import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/app.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/features/login/login_screen.dart';
import 'package:patra/src/features/launch/launch_animation.dart';
import 'package:patra/src/features/profiles/profile_picker_screen.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/features/series/series_detail_screen.dart';
import 'package:patra/src/routes.dart';

import 'test_support.dart';

/// The link a share sheet or a browser hands the OS: a series, with what the
/// screen needs to draw its header before the fetch lands.
const _link = '/series/5?name=Blame%21&library=1';

/// A Kavita that answers everything the series screen asks, or refuses the
/// series outright — which is what a link to somebody else's library is.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.refuseSeries = false});

  /// Kavita's own answer for a series this account cannot see: the lookup is
  /// scoped to the account, so what comes back is not a 403 but "that series
  /// does not exist".
  final bool refuseSeries;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody json(Object body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
    if (refuseSeries && options.path.startsWith('/api/Series/')) {
      return ResponseBody.fromString(
        'Series does not exist',
        400,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }
    return switch (options.path) {
      '/api/Library/libraries' => json([
        {'id': 1, 'name': 'Mangas', 'type': 0},
      ]),
      '/api/Series/5' => json({
        'id': 5,
        'name': 'Blame!',
        'libraryId': 1,
        'pages': 200,
        'pagesRead': 40,
      }),
      '/api/Reader/chapter-info' => json({
        'seriesId': 5,
        'volumeId': 1,
        'libraryId': 1,
        'pages': 50,
        'seriesName': 'Blame!',
        'title': 'Chapter 1',
      }),
      '/api/Series/metadata' => json({
        'id': 5,
        'summary': 'A city with no end.',
        'writers': [
          {'id': 1, 'name': 'Tsutomu Nihei'},
        ],
      }),
      '/api/Series/volumes' => json([
        {
          'id': 1,
          'minNumber': 1,
          'pages': 200,
          'pagesRead': 40,
          'chapters': [
            {
              'id': 11,
              'range': '1',
              'minNumber': 1,
              'pages': 200,
              'pagesRead': 40,
              'seriesId': 5,
            },
          ],
        },
      ]),
      _ => json(const <Object>[]),
    };
  }

  @override
  void close({bool force = false}) {}
}

final _romain = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 1,
  username: 'romain',
  apiKey: 'key-romain',
);

final _lea = Profile(
  baseUrl: 'https://kavita.example',
  accountId: 2,
  username: 'lea',
  apiKey: 'key-lea',
);

Widget _app({
  required AuthState auth,
  required Directory downloadsRoot,
  bool refuseSeries = false,
  bool launching = true,
  SignIn? signIn,
}) {
  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'token',
    username: 'romain',
    apiKey: 'key-romain',
  );
  client.httpClient.httpClientAdapter = _StubAdapter(
    refuseSeries: refuseSeries,
  );
  client.bareHttpClient.httpClientAdapter = _StubAdapter(
    refuseSeries: refuseSeries,
  );

  return ProviderScope(
    overrides: [
      initialAuthStateProvider.overrideWithValue(auth.atLaunch()),
      kavitaClientProvider.overrideWithValue(client),
      downloadsRootProvider.overrideWithValue(downloadsRoot),
      isLaunchProvider.overrideWithValue(launching),
      if (signIn != null) signInProvider.overrideWithValue(signIn),
    ],
    child: const PatraApp(),
  );
}

/// A server that accepts whatever it is given, and answers as [who].
SignIn _signsIn({required int accountId, required String who}) =>
    ({
      required String baseUrl,
      required String username,
      required Credential credential,
      ClientIdentity identity = const ClientIdentity.unknown(),
    }) async => LoginResult(
      username: who,
      token: signedToken(accountId),
      apiKey: 'key-$who',
    );

/// The series the app is showing, as the link asked for it.
(String, String, int) _opened(WidgetTester tester) {
  final screen = tester.widget<SeriesDetailScreen>(
    find.byType(SeriesDetailScreen),
  );
  return ('${screen.seriesId}', screen.seriesName, screen.libraryId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what a link holds', () {
    test('a series and a chapter are what a link can point at', () {
      expect(PendingLink('/series/5').take(), '/series/5');
      expect(PendingLink('/reader/11?page=3').take(), '/reader/11?page=3');
    });

    test('the app\'s own furniture is not a link', () {
      // A tab, a gate, or the app simply being opened: nobody linked to any
      // of these, and holding one would send somebody signing in back to
      // where the *previous* person was.
      for (final location in ['/', '/library', '/downloads', '/settings',
          profilesLocation, '/login?profile=x']) {
        expect(
          PendingLink(location).take(),
          isNull,
          reason: '$location is not a link',
        );
      }
    });

    test('an id it could not open is not a link', () {
      // The builders put a series or a chapter id there and the screens
      // parse one back out; anything else would be held only to crash the
      // screen it was held for.
      expect(PendingLink('/series/abc').take(), isNull);
      expect(PendingLink('/series').take(), isNull);
      expect(PendingLink('/reader/11/2').take(), isNull);
    });

    test('nothing is held where nothing was handed over', () {
      expect(PendingLink.none().take(), isNull);
    });

    test('a link is spent by being taken', () {
      final pending = PendingLink('/series/5');
      expect(pending.take(), '/series/5');
      // Not a second time: a link is opened once, and switching profile an
      // hour later is not that.
      expect(pending.take(), isNull);
    });
  });

  group('a link arriving on a cold start', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('patra-deep-link-test');
      mockSecureStorage();
      mockPathProvider();
    });
    tearDown(() {
      root.deleteSync(recursive: true);
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .clearDefaultRouteNameTestValue();
    });

    /// The OS hands a link to the app as the route it was started on.
    void openedWith(String link) => TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .defaultRouteNameTestValue = link;

    /// Room for the shelves under the link, so nothing overflows.
    void room(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    testWidgets('waits for a profile where there is one to choose', (
      tester,
    ) async {
      room(tester);
      openedWith(_link);

      await tester.pumpWidget(
        _app(
          auth: AuthState(profiles: [_romain, _lea]),
          downloadsRoot: root,
          // A tap on a face spends its stored key, which is a request.
          signIn: _signsIn(accountId: 2, who: 'lea'),
        ),
      );
      await tester.pumpAndSettle();

      // Identity first: the link names content, and on a shared device
      // opening it in whoever read last is a coin toss.
      expect(find.byType(ProfilePickerScreen), findsOneWidget);
      expect(find.byType(SeriesDetailScreen), findsNothing);

      await tester.tap(find.text('lea'));
      await tester.pumpAndSettle();

      // And then opens — whole, query and all: the screen draws its header
      // from what the link carried, before its own fetch lands.
      expect(_opened(tester), ('5', 'Blame!', 1));
      // On top of the app rather than instead of it: a series with nothing
      // under it draws no back arrow, and there is no other way into Patra
      // from here.
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('opens straight away where there is nobody to choose', (
      tester,
    ) async {
      room(tester);
      openedWith(_link);

      await tester.pumpWidget(
        _app(auth: AuthState(profiles: [_romain]), downloadsRoot: root),
      );
      await tester.pumpAndSettle();

      // One profile is a question with one answer, and `atLaunch` has
      // already answered it.
      expect(find.byType(ProfilePickerScreen), findsNothing);
      expect(_opened(tester), ('5', 'Blame!', 1));
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('opens a chapter where it was left, with a way back out', (
      tester,
    ) async {
      room(tester);
      openedWith('/reader/11?page=3');

      await tester.pumpWidget(
        _app(auth: AuthState(profiles: [_romain]), downloadsRoot: root),
      );
      // Not pumpAndSettle: the page placeholders spin forever behind a
      // server that serves no pages, exactly as in `reader_test.dart`.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
      expect(reader.chapterId, 11);
      // The page the link named: opening at 0 would post that back and wipe
      // the place the chapter was left at.
      expect(reader.initialPage, 3);

      // The reader's own close button is a `maybePop`, which on a lone page
      // does nothing at all — so this is the whole of whether a link opens
      // the app or a room with no door.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReaderScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('survives the password a lone signed-out profile asks for', (
      tester,
    ) async {
      room(tester);
      openedWith(_link);

      await tester.pumpWidget(
        _app(
          auth: AuthState(
            profiles: [
              Profile(
                baseUrl: 'https://kavita.example',
                accountId: 1,
                username: 'romain',
              ),
            ],
          ),
          downloadsRoot: root,
          signIn: _signsIn(accountId: 1, who: 'romain'),
        ),
      );
      await tester.pumpAndSettle();

      // The form, not the picker — and the link is still waiting behind it.
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'hunter2');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(_opened(tester), ('5', 'Blame!', 1));
    });

    testWidgets('is not opened a second time when the app is handed over', (
      tester,
    ) async {
      room(tester);
      openedWith(_link);

      // What `SessionScope` builds for the second person: the same app on a
      // fresh container, and the OS still holding the link that started the
      // first one. Following it here would open one person's link in
      // somebody else's session — the coin toss, an hour later.
      await tester.pumpWidget(
        _app(
          auth: AuthState(profiles: [_romain]),
          downloadsRoot: root,
          launching: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SeriesDetailScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('to content the chosen profile cannot see fails as any '
        'request does', (tester) async {
      room(tester);
      openedWith(_link);

      await tester.pumpWidget(
        _app(
          auth: AuthState(profiles: [_romain]),
          downloadsRoot: root,
          refuseSeries: true,
        ),
      );
      await tester.pumpAndSettle();

      // The screen opens and its own failure state says so. Nothing about a
      // link needs a case of its own: what a refused series produces is a
      // refused request, which every screen here already knows how to wear.
      expect(find.byType(SeriesDetailScreen), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
