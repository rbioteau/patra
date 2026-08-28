import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verso/src/app.dart';
import 'package:verso/src/features/login/login_screen.dart';

void main() {
  testWidgets('shows the login screen when there is no session', (
    WidgetTester tester,
  ) async {
    // No initialSessionProvider override: same as a first launch.
    await tester.pumpWidget(const ProviderScope(child: VersoApp()));
    await tester.pumpAndSettle();

    // Tests run under the default 'en' locale.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
