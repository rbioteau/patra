import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/settings/mobile_data.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/mobile_data_gate.dart';

import 'test_support.dart';

/// The question a download away from Wi-Fi puts before it spends a plan, and
/// the device's answer to it.

/// One button standing in for every control that starts a fetch, recording
/// what [mayDownload] answered each tap.
class _Starter extends ConsumerWidget {
  const _Starter(this.answers);

  final List<bool> answers;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () async => answers.add(await mayDownload(context, ref)),
    child: const Text('start'),
  );
}

Future<List<bool>> _pump(
  WidgetTester tester, {
  required bool mobileData,
  MemoryKeychain? keychain,
  Locale locale = const Locale('en'),
}) async {
  final answers = <bool>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(keychain),
        testNetwork(mobileData: mobileData),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _Starter(answers)),
      ),
    ),
  );
  return answers;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on Wi-Fi, a download starts without a word', (tester) async {
    final answers = await _pump(tester, mobileData: false);
    await _tap(tester, 'start');
    expect(find.text("You're on mobile data"), findsNothing);
    expect(answers, [true]);
  });

  testWidgets('on mobile data, cancelling starts nothing', (tester) async {
    final answers = await _pump(tester, mobileData: true);
    await _tap(tester, 'start');
    expect(find.text("You're on mobile data"), findsOneWidget);
    expect(
      find.text('This download will use your data plan. Download anyway?'),
      findsOneWidget,
    );
    await _tap(tester, 'Cancel');
    expect(answers, [false]);
  });

  testWidgets('agreeing once is asked again next time', (tester) async {
    final keychain = MemoryKeychain();
    final answers = await _pump(tester, mobileData: true, keychain: keychain);
    await _tap(tester, 'start');
    await _tap(tester, 'Download');
    expect(answers, [true]);
    expect(await keychain.read('downloadOnMobileData'), isNull);

    await _tap(tester, 'start');
    expect(find.text("You're on mobile data"), findsOneWidget);
  });

  testWidgets("\"don't ask again\" is the device's, and is kept", (
    tester,
  ) async {
    final keychain = MemoryKeychain();
    final answers = await _pump(tester, mobileData: true, keychain: keychain);
    await _tap(tester, 'start');
    // The whole line is the control, not only the box.
    await _tap(tester, "Don't ask again");
    await _tap(tester, 'Download');
    expect(answers, [true]);
    expect(await keychain.read('downloadOnMobileData'), 'true');

    // Not asked again — in this run, nor in the next one on this device.
    await _tap(tester, 'start');
    expect(find.text("You're on mobile data"), findsNothing);
    expect(answers, [true, true]);

    await tester.pumpWidget(const SizedBox());
    final again = await _pump(tester, mobileData: true, keychain: keychain);
    await _tap(tester, 'start');
    expect(find.text("You're on mobile data"), findsNothing);
    expect(again, [true]);
  });

  testWidgets('the question is worded in French', (tester) async {
    await _pump(tester, mobileData: true, locale: const Locale('fr'));
    await _tap(tester, 'start');
    expect(find.text('Vous êtes sur les données mobiles'), findsOneWidget);
    expect(find.text('Ne plus demander'), findsOneWidget);
    expect(find.text('Télécharger'), findsOneWidget);
  });

  test('turning the setting off asks again', () async {
    final keychain = MemoryKeychain();
    await keychain.write('downloadOnMobileData', 'true');
    final container = ProviderContainer(overrides: [testKeychain(keychain)]);
    addTearDown(container.dispose);

    expect(await container.read(mobileDataDownloadsProvider.future), isTrue);
    await container.read(mobileDataDownloadsProvider.notifier).set(false);
    expect(container.read(mobileDataDownloadsProvider).value, isFalse);
    expect(await keychain.read('downloadOnMobileData'), isNull);
  });
}
