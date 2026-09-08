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
import 'package:patra/src/features/profiles/profile_picker_screen.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/session_scope.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/offline_indicator.dart';

import 'test_support.dart';

/// A server that is simply not there: every request fails at the connection,
/// which is what dio reports for a LAN address nothing answers on.
///
/// Not a 500 and not a refusal — those are servers. This is the train.
class _UnreachableAdapter implements HttpClientAdapter {
  int attempts = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    attempts++;
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'no route to host',
    );
  }

  @override
  void close({bool force = false}) {}
}

Profile _profile(String username, int accountId) => Profile(
  baseUrl: 'https://kavita.example',
  accountId: accountId,
  username: username,
  apiKey: 'key-$username',
);

final _romain = _profile('romain', 1);
final _lea = _profile('lea', 2);

/// Two faces, so the device opens on the picker: that is the screen this is
/// about, and `AuthState.atLaunch` sends a one-profile device straight past
/// it.
final _profiles = [_romain, _lea];

Future<LoginResult> _signIn({
  required String baseUrl,
  required String username,
  required Credential credential,
  ClientIdentity identity = const ClientIdentity.unknown(),
}) async => throw DioException.connectionError(
  requestOptions: RequestOptions(path: '/api/Account/login'),
  reason: 'no route to host',
);

Widget _app(Directory root, _UnreachableAdapter adapter) => SessionScope(
  auth: AuthState(profiles: _profiles).atLaunch(),
  overrides: [
    testKeychain(),
    signInProvider.overrideWithValue(_signIn),
    downloadsRootProvider.overrideWithValue(root),
    kavitaClientProvider.overrideWith((ref) {
      final session = ref.watch(sessionProvider);
      final client = KavitaClient(
        baseUrl: session?.baseUrl ?? 'https://kavita.example',
        token: session?.token ?? '',
        username: session?.username ?? '',
        apiKey: session?.apiKey ?? '',
        onReachabilityChanged: (reachable) =>
            ref.read(offlineProvider.notifier).set(!reachable),
      );
      client.httpClient.httpClientAdapter = adapter;
      client.bareHttpClient.httpClientAdapter = adapter;
      return client;
    }),
  ],
  child: const PatraApp(),
);

Directory _room(WidgetTester tester) {
  mockPathProvider();
  final root = Directory.systemTemp.createTempSync('patra-offline-reading');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  return root;
}

/// Pumps until [until] holds, rather than for a fixed number of frames.
///
/// Every other step in these tests settles, and that is deliberate: this
/// branch's own fix is what makes the home screen stop animating offline, and
/// the test below asserts exactly that with `pumpAndSettle`. The reader is the
/// one place that genuinely never goes still, and it is the **fixture** rather
/// than the product: a saved page here is a single byte, which no decoder will
/// take, so `PageLoading`'s indicator spins over it for good. Writing a real
/// image per page would buy nothing — what is under test is where the page
/// count came from, not what the page looks like.
///
/// Waiting on a condition rather than on a frame budget because the work in
/// front of it is **real filesystem IO** — `saveChapterFixture` and
/// `DownloadsService.scan()` are not fake async, and a fixed number of pumps
/// is a race that a loaded machine loses.
Future<void> _pumpUntil(
  WidgetTester tester,
  FinderBase<Element> until, {
  int maxFrames = 60,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (until.evaluate().isNotEmpty) return;
  }
  fail('gave up waiting for $until');
}

/// What the app already says about being offline, wherever it says it.
const _offlineSentence =
    'Server unreachable — offline mode. Saved chapters remain readable.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('someone on a train reads what they saved for it', (
    tester,
  ) async {
    // The whole point of the feature, end to end and with nothing answering:
    // the picker draws, a face opens, and the chapter that was saved for the
    // journey is listed and readable.
    final root = _room(tester);
    await saveChapterFixture(
      root,
      _romain.id,
      chapterId: 42,
      seriesName: 'Blame!',
      title: 'Volume 1',
      pages: 3,
    );
    final adapter = _UnreachableAdapter();

    await tester.pumpWidget(_app(root, adapter));
    await tester.pumpAndSettle();

    // Drawn from what the device remembers, before anything was asked of a
    // server — and it is about to be shown that nothing could have answered.
    expect(find.byType(ProfilePickerScreen), findsOneWidget);
    expect(find.text('romain'), findsOneWidget);
    expect(find.text('lea'), findsOneWidget);

    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();

    // Entered anyway: unreachable is not a refused credential, so the session
    // opens on the key it already holds.
    expect(find.byType(ProfilePickerScreen), findsNothing);
    expect(find.byType(OfflineIndicator), findsOneWidget);

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Blame!'), findsOneWidget);
    expect(find.text('Volume 1'), findsOneWidget);

    await tester.tap(find.text('Volume 1'));
    await _pumpUntil(tester, find.byType(ReaderScreen));

    // The page count comes off the stored `meta.json`: nothing answered, so
    // there was nowhere else it could have come from.
    await tester.tapAt(tester.getCenter(find.byType(ReaderScreen)));
    await _pumpUntil(tester, find.text('1 / 3'));
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('the home screen stops asking rather than shimmering forever', (
    tester,
  ) async {
    // A `Skeleton` is an `AnimationController..repeat()`, and a section that
    // draws one whenever it has no value draws it for a value that is never
    // coming: offline, once `serverRetry` has spent its three attempts, the
    // provider is in error and the shimmer is permanent — a device redrawing
    // forever over a screen that says nothing.
    //
    // `pumpAndSettle` is the assertion: it waits for every animation to
    // finish, so it can only return if nothing is still shimmering.
    final root = _room(tester);
    await tester.pumpWidget(_app(root, _UnreachableAdapter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();

    expect(find.byType(Skeleton), findsNothing);
    // Still the bar that carries the *status*: the indicator's own sentence
    // must not reappear over the content, which is the rule
    // `offline_indicator_test.dart` keeps.
    expect(find.byType(OfflineIndicator), findsOneWidget);
    expect(find.text(_offlineSentence), findsNothing);
    // But a screen with nothing on it explains nothing, and this device has
    // nothing saved either — so it says that, and offers no way out it
    // cannot honour.
    expect(
      find.text(
        'The server is out of reach, and nothing is saved on this device yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('See your downloads'), findsNothing);
  });

  testWidgets('an empty home offline points at what is still readable', (
    tester,
  ) async {
    // The empty state is not the banner this app removed. That one said the
    // same sentence over content that existed, on every screen at once; this
    // is Home having nothing whatever to draw, naming the one tab that does
    // — and it is only offered because there is really something there.
    final root = _room(tester);
    await saveChapterFixture(
      root,
      _romain.id,
      chapterId: 42,
      seriesName: 'Blame!',
      title: 'Volume 1',
      pages: 3,
    );
    await tester.pumpWidget(_app(root, _UnreachableAdapter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();

    expect(
      find.text('The server is out of reach. What you saved is still here.'),
      findsOneWidget,
    );

    await tester.tap(find.text('See your downloads'));
    await tester.pumpAndSettle();

    // And it really is the Downloads tab, with the chapter on it.
    expect(find.text('Blame!'), findsOneWidget);
    expect(find.text('Volume 1'), findsOneWidget);
  });

  testWidgets('the library says it is offline instead of failing', (
    tester,
  ) async {
    // A grid of covers is the one screen here that genuinely cannot show
    // anything offline, so it does need furniture of its own — but worded as
    // the ordinary state it is, in the app's own offline sentence, rather
    // than as a fault. The retry beside it is what "coming back online is the
    // user's move" means in practice.
    final root = _room(tester);
    await tester.pumpWidget(_app(root, _UnreachableAdapter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text(_offlineSentence), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Two struck-through clouds, and they are not a repetition: the bar's is
    // the status this app shows on every screen, and the body's belongs to
    // the explanation standing in for a grid that cannot be drawn.
    expect(find.byType(OfflineIndicator), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsNWidgets(2));
    // Never the raw exception, which is what an unhandled error state shows.
    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('an unreachable server never costs a profile its key', (
    tester,
  ) async {
    // Throwing a working credential away over a fault that fixes itself is
    // what would make the next journey start with a password. Only a bare
    // 401 means the key itself is refused.
    final root = _room(tester);
    final adapter = _UnreachableAdapter();

    await tester.pumpWidget(_app(root, adapter));
    await tester.pumpAndSettle();
    await tester.tap(find.text('romain'));
    await tester.pumpAndSettle();

    expect(adapter.attempts, greaterThan(0), reason: 'it really did try');

    final kept = tester
        .container()
        .read(authProvider)
        .profiles
        .firstWhere((p) => p.id == _romain.id);
    expect(kept.hasCredential, isTrue);
  });
}
