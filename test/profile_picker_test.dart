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

  testWidgets('a profile whose key stopped working says so before it is tapped', (
    tester,
  ) async {
    await _pump(tester, [
      _profile(username: 'romain'),
      _profile(accountId: 2, username: 'lea', apiKey: ''),
    ]);

    expect(
      find.text('Sign in'),
      findsOneWidget,
      reason: 'the cost of tapping that face is learned before tapping it',
    );
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

  group('removing a profile', () {
    /// Long-presses [name] and returns with the confirmation up.
    Future<void> longPress(WidgetTester tester, String name) async {
      await tester.longPress(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets('is a long press, and says who it is about', (tester) async {
      mockSecureStorage();
      await _pump(tester, [
        _profile(username: 'romain'),
        _profile(accountId: 2, username: 'lea'),
      ]);

      await longPress(tester, 'lea');
      // Both halves: a server holds several profiles, so it is one of them
      // being removed rather than the address.
      expect(find.text('Forget lea on kavita.example?'), findsOneWidget);

      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();

      expect(find.text('lea'), findsNothing);
      expect(
        find.text('romain'),
        findsOneWidget,
        reason: 'the others on that server stay',
      );
    });

    testWidgets('does nothing until it is confirmed', (tester) async {
      mockSecureStorage();
      await _pump(tester, [
        _profile(username: 'romain'),
        _profile(accountId: 2, username: 'lea'),
      ]);

      await longPress(tester, 'lea');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('lea'), findsOneWidget);
      expect(find.text('romain'), findsOneWidget);
    });

    testWidgets('is refused while a face is being entered', (tester) async {
      // The one guard there is: a sign-in in flight owns the screen, so a
      // press cannot remove the profile the app is halfway into.
      mockSecureStorage();
      await _pump(
        tester,
        [_profile(username: 'romain'), _profile(accountId: 2, username: 'lea')],
        // A sign-in that never answers, which is the window being tested: a
        // real one would either resolve or fail on DNS, and neither is a
        // thing to hang a test on.
        signIn:
            ({
              required String baseUrl,
              required String username,
              required Credential credential,
              ClientIdentity identity = const ClientIdentity.unknown(),
            }) => Completer<LoginResult>().future,
      );

      await tester.tap(find.text('romain'));
      await tester.pump();

      // Not `pumpAndSettle`: the face being entered wears a spinner, which
      // is an animation that never settles while the request is in flight.
      await tester.longPress(find.text('romain'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Forget romain'), findsNothing);
    });
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
