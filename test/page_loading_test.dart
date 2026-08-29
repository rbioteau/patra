import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/features/reader/page_loading.dart';
import 'package:patra/src/theme.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool explain}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: patraTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PageLoading(explain: explain)),
        ),
      );

  testWidgets('an ordinary page never explains itself', (tester) async {
    await pump(tester, explain: false);
    await tester.pump(PageLoading.explainAfter * 3);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparing the PDF'), findsNothing);
  });

  testWidgets('a PDF says what the server is doing, but not at once', (
    tester,
  ) async {
    await pump(tester, explain: true);

    // A page that arrives normally must not flash a wall of text on the way.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparing the PDF'), findsNothing);

    await tester.pump(PageLoading.explainAfter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparing the PDF'), findsOneWidget);
    expect(
      find.textContaining('Only the first open waits'),
      findsOneWidget,
    );
  });
}
