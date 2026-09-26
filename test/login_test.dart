import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/features/login/login_screen.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// The form as a device with nothing remembered draws it: every field shown,
/// which is the only state that ever carried the local-address caption.
Future<void> _pumpLogin(
  WidgetTester tester, {
  List<Profile> profiles = const [],
  String? profileId,
  double keyboard = 0,
  SignIn? signIn,
}) async {
  mockPathProvider();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        testKeychain(),
        initialAuthStateProvider.overrideWithValue(
          AuthState(profiles: profiles),
        ),
        if (signIn != null) signInProvider.overrideWithValue(signIn),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: patraTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            // What the platform reports while the keyboard is up.
            data: MediaQuery.of(context)
                .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: LoginScreen(profileId: profileId),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The field under a given uppercase label. `find.ancestor` walks outward
/// from the label, so the nearest Column is the `_Field` holding both.
TextField _field(WidgetTester tester, String label) => tester.widget<TextField>(
  find
      .descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      )
      .first,
);

/// A server that turns the sign-in down, so the form draws its error and
/// stays where it is.
Future<LoginResult> _refuse({
  required String baseUrl,
  required String username,
  required Credential credential,
  ClientIdentity identity = const ClientIdentity.unknown(),
}) async => throw Exception('refused');

void main() {
  testWidgets('the footer stands down while the keyboard is up', (
    tester,
  ) async {
    await _pumpLogin(tester);
    expect(find.textContaining('kept in secure storage'), findsOneWidget);

    await _pumpLogin(tester, keyboard: 320);
    expect(find.textContaining('kept in secure storage'), findsNothing);
  });

  testWidgets('the keyboard offers the next field, then the verb', (
    tester,
  ) async {
    await _pumpLogin(tester);

    expect(
      _field(tester, 'SERVER ADDRESS').textInputAction,
      TextInputAction.next,
    );
    expect(_field(tester, 'USERNAME').textInputAction, TextInputAction.next);
    // The last field submits, so the button never has to be found under a
    // keyboard.
    expect(_field(tester, 'PASSWORD').textInputAction, TextInputAction.done);
  });

  testWidgets('the password can be looked at, and stays looked at', (
    tester,
  ) async {
    await _pumpLogin(tester, signIn: _refuse);

    expect(_field(tester, 'PASSWORD').obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(_field(tester, 'PASSWORD').obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // A refused sign-in is the one moment the eye earns its place, so
    // nothing puts it back. The form has to get all the way past its own
    // validator for this to be asking anything.
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'https://kavita.example',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'romain');
    await tester.enterText(find.byType(TextFormField).at(2), 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('kavita.example'),
      findsWidgets,
      reason: 'the sign-in has to have been refused, not merely not tried',
    );
    expect(_field(tester, 'PASSWORD').obscureText, isFalse);
  });
}
