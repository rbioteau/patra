import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/launch/launch_animation.dart';
import 'package:patra/src/features/profiles/profile_picker_screen.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/dashed_border.dart';

import 'test_support.dart';

Profile _profile({
  String baseUrl = 'https://kavita.example',
  int accountId = 1,
  String username = 'romain',
  String apiKey = 'key',
  bool hasAvatar = false,
  String color = '',
}) => Profile(
  baseUrl: baseUrl,
  accountId: accountId,
  username: username,
  apiKey: apiKey,
  hasAvatar: hasAvatar,
  color: color,
);

/// The picker, and **nothing else**: no client, no adapter, no server.
///
/// That is the point of this harness rather than an omission. A shared device
/// opens on this screen, and it has to draw before the first request and
/// often without one ever succeeding — so anything it needed from a session
/// would show up here as a `StateError` from [kavitaClientProvider], which
/// has no session to build one from.
Future<void> _pump(
  WidgetTester tester,
  List<Profile> profiles, {
  SignIn? signIn,
}) async {
  mockPathProvider();
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope every time, so a test that pumps twice really does open
      // a second device: the notifier reads the initial state once, and
      // swapping the override under a live container would not reach it.
      key: UniqueKey(),
      overrides: [
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: profiles),
        ),
        if (signIn != null) signInProvider.overrideWithValue(signIn),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: patraTheme(),
        home: const ProfilePickerScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// How dimmed the face under [name] is, asked of that one face.
///
/// Through the `InkWell` the face is built around, so the answer cannot be
/// some other widget's fade.
double _dimming(WidgetTester tester, String name) {
  final face = find
      .ancestor(of: find.text(name), matching: find.byType(InkWell))
      .first;
  final faded = tester.widgetList<Opacity>(
    find.descendant(of: face, matching: find.byType(Opacity)),
  );
  return faded.isEmpty ? 1 : faded.first.opacity;
}

/// The colour a face is drawn on: the box immediately behind its initial.
Color? _faceColor(WidgetTester tester, String initial) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: find.text(initial), matching: find.byType(Container))
        .first,
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('draws every remembered profile with no network at all', (
    tester,
  ) async {
    await _pump(tester, [
      _profile(username: 'romain'),
      _profile(accountId: 2, username: 'lea'),
    ]);

    expect(find.text('Who is reading?'.toUpperCase()), findsOneWidget);
    expect(find.text('romain'), findsOneWidget);
    expect(find.text('lea'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'nothing here may ask for a session',
    );
  });

  testWidgets('a profile with no avatar is its initial on its own colour', (
    tester,
  ) async {
    await _pump(tester, [
      _profile(username: 'romain', color: '#4AC694'),
      _profile(accountId: 2, username: 'lea'),
    ]);

    // Kavita's own colour for the account, as its web UI paints it.
    expect(_faceColor(tester, 'R'), const Color(0xFF4AC694));
    // An account the server gave no colour falls back to the app's identity
    // purple rather than to nothing at all.
    expect(_faceColor(tester, 'L'), patraAccent);
  });

  testWidgets('an avatar is fetched by account, and the initial stands in', (
    tester,
  ) async {
    await _pump(tester, [
      _profile(username: 'romain', hasAvatar: true, color: '#4AC694'),
      _profile(accountId: 2, username: 'lea'),
    ]);

    // Kavita serves an account's picture by id, with the key as the query
    // parameter — an image widget cannot always send a header.
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(
      image.imageUrl,
      'https://kavita.example/api/Image/user-cover?userId=1&apiKey=key',
    );

    // Nothing answers in a test, which is also what a train looks like: the
    // face falls back to the initial on its own colour rather than to a
    // spinner or a broken-image glyph.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('R'), findsOneWidget);
    expect(_faceColor(tester, 'R'), const Color(0xFF4AC694));
  });

  testWidgets('the server labels a face only when there are two of them', (
    tester,
  ) async {
    // Two people on one address: the host under both would be the same word
    // twice, and says nothing about which face is which.
    await _pump(tester, [
      _profile(username: 'romain'),
      _profile(accountId: 2, username: 'lea'),
    ]);
    expect(find.text('kavita.example'), findsNothing);

    // One person on two servers: the name is the same on both faces, and the
    // host is the only thing that tells them apart.
    await _pump(tester, [
      _profile(username: 'romain'),
      _profile(baseUrl: 'https://other.example', username: 'romain'),
    ]);
    expect(find.text('kavita.example'), findsOneWidget);
    expect(find.text('other.example'), findsOneWidget);

    // Two addresses that draw as **one word** are not two labels: the rule is
    // asked of the label, so a subtitle never prints the same host twice.
    await _pump(tester, [
      _profile(username: 'romain'),
      _profile(baseUrl: 'https://kavita.example:5001', username: 'lea'),
    ]);
    expect(find.text('kavita.example'), findsNothing);
  });

  testWidgets(
    'a profile whose key stopped working says so before it is tapped',
    (tester) async {
      await _pump(tester, [
        _profile(username: 'romain'),
        _profile(accountId: 2, username: 'lea', apiKey: ''),
      ]);

      expect(
        find.text('Sign in'),
        findsOneWidget,
        reason: 'the cost of tapping that face is learned before tapping it',
      );
      // And marked on the face itself: the word sits under the name, where a
      // reader choosing between faces is not looking.
      expect(find.byIcon(Icons.key_off_outlined), findsOneWidget);
      // Quieter than the faces that open on a tap — and asked of that face's
      // own subtree rather than of the tree at large: counting every
      // `Opacity` on screen breaks on any unrelated fade and never ties the
      // dimming to the face it is about.
      expect(_dimming(tester, 'lea'), lessThan(1));
      expect(_dimming(tester, 'romain'), 1);
    },
  );

  testWidgets('a face signing in is busy rather than stalled', (tester) async {
    // Two marks in one circle would be a face that is working and a face
    // that is stuck at the same time. The spinner is already saying what
    // this one is doing, so the badge stands down while it spins.
    final held = Completer<LoginResult>();
    // Left hanging on purpose; completed at teardown so nothing outlives the
    // test.
    addTearDown(
      () => held.complete(
        const LoginResult(username: 'romain', token: '', apiKey: ''),
      ),
    );
    await _pump(
      tester,
      [_profile(username: 'romain'), _profile(accountId: 2, username: 'lea')],
      signIn: ({
        required String baseUrl,
        required String username,
        required Credential credential,
        ClientIdentity identity = const ClientIdentity.unknown(),
      }) => held.future,
    );

    await tester.tap(find.text('romain'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.key_off_outlined), findsNothing);
  });

  testWidgets('a profile that still holds its key is marked with nothing', (
    tester,
  ) async {
    await _pump(tester, [_profile(), _profile(accountId: 2, username: 'lea')]);

    expect(find.byIcon(Icons.key_off_outlined), findsNothing);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('the add slot is a place to fill, in the handoff\'s dashes', (
    tester,
  ) async {
    await _pump(tester, [_profile(), _profile(accountId: 2, username: 'lea')]);

    expect(find.text('Add a profile'), findsOneWidget);
    final dashed = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.painter is DashedBorderPainter);
    expect(dashed, isNotEmpty);
  });

  testWidgets('removes nothing: entering a profile is all it does', (
    tester,
  ) async {
    // A long press used to remove a profile from here, and that is now in
    // Settings. The move is the guard: this screen stands in front of every
    // session and asks for nothing, so a press here could remove anybody's
    // profile — where Settings can only be reached by somebody holding a
    // credential on this device.
    await _pump(tester, [
      _profile(username: 'romain'),
      _profile(accountId: 2, username: 'lea'),
    ]);

    await tester.longPress(find.text('lea'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Forget'), findsNothing);
    expect(find.text('lea'), findsOneWidget);
    expect(find.text('romain'), findsOneWidget);
  });

  testWidgets('a sign-in in flight owns the screen', (tester) async {
    // One face is being entered, and it is the only one the screen answers
    // for: a second tap must not start a second sign-in, here or on the face
    // already busy.
    final entered = <String>[];
    await _pump(
      tester,
      [_profile(username: 'romain'), _profile(accountId: 2, username: 'lea')],
      // A sign-in that never answers, which is the window being tested: a
      // real one would either resolve or fail on DNS, and neither is a thing
      // to hang a test on.
      signIn:
          ({
            required String baseUrl,
            required String username,
            required Credential credential,
            ClientIdentity identity = const ClientIdentity.unknown(),
          }) {
            entered.add(username);
            return Completer<LoginResult>().future;
          },
    );

    await tester.tap(find.text('romain'));
    // Not `pumpAndSettle`: the face being entered wears a spinner, which is
    // an animation that never settles while the request is in flight.
    await tester.pump();
    await tester.tap(find.text('lea'));
    await tester.tap(find.text('romain'));
    await tester.pump();

    expect(entered, ['romain']);
  });

  testWidgets('offers the launch animation its lockup', (tester) async {
    await _pump(tester, [_profile(), _profile(accountId: 2, username: 'lea')]);

    // The presence of the slots is the whole condition: the splash lands its
    // frond and its wordmark on whichever screen offers them, and needs to
    // know nothing about which one this is.
    expect(find.byType(LaunchLogoSlot), findsOneWidget);
    expect(find.byType(LaunchWordmarkSlot), findsOneWidget);
  });
}
