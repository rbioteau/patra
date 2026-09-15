import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/branding/patra_launch.dart';
import 'package:patra/src/features/launch/launch_animation.dart';

/// The whole animation, plus a frame for the post-frame callback it starts on.
const _whole = Duration(milliseconds: 4900);

Finder _splash() => find.byKey(patraLaunchSplashKey);

/// A stand-in for the app the splash is standing in front of.
///
/// The counter is the point of it: the splash covers the app, so a tap that
/// reaches the counter is the proof that the splash is really gone and not
/// merely invisible.
class _Home extends StatefulWidget {
  const _Home();

  static int taps = 0;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => _Home.taps++),
          child: const Text('home'),
        ),
      ),
    );
  }
}

Widget _app({
  bool launching = true,
  bool reduceMotion = false,
  Widget home = const _Home(),
}) {
  return ProviderScope(
    overrides: [isLaunchProvider.overrideWithValue(launching)],
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: reduceMotion,
      ),
      child: MaterialApp(
        // Mirrors how the real app mounts it: above the Navigator.
        builder: (_, child) =>
            LaunchAnimation(child: child ?? const SizedBox.shrink()),
        home: home,
      ),
    ),
  );
}

void main() {
  setUp(() => _Home.taps = 0);

  group('the launch animation on screen', () {
    testWidgets('the app is mounted and laid out underneath it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      // It is covering the app, not standing in for it: the screen behind is
      // already built, which is what lets its first requests go out while the
      // mark is still assembling.
      expect(_splash(), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('it fades out on its own and leaves the app bare', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.pump(_whole);
      await tester.pump();

      expect(_splash(), findsNothing);
      await tester.tap(find.text('home'));
      expect(_Home.taps, 1);
    });

    testWidgets('the app answers no taps while it is up', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('home'), warnIfMissed: false);
      expect(_Home.taps, 0);
    });

    testWidgets('a tap sends it home rather than cutting it out', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(_splash());
      // It seeks to the fade and lands, so it is still there a beat later:
      // the app underneath is never uncovered mid-assembly.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_splash(), findsOneWidget);

      await tester.pumpAndSettle();
      expect(_splash(), findsNothing);

    });

    testWidgets('less motion means no launch animation at all', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: true));
      await tester.pump();

      expect(_splash(), findsNothing);
      await tester.tap(find.text('home'));
      expect(_Home.taps, 1);
    });

    testWidgets('a handover is not a launch', (tester) async {
      // Entering another profile builds the whole app again, animation
      // included; without this the mark would assemble itself over somebody
      // who has just tapped their own face.
      await tester.pumpWidget(_app(launching: false));
      await tester.pump();

      expect(_splash(), findsNothing);
    });
  });

  group('waiting on the app', () {
    testWidgets('not ready holds the assembled mark', (tester) async {
      final ready = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (_, isReady, _) => PatraLaunch(
              ready: isReady,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(_whole);
      await tester.pump();

      ready.value = true;
      await tester.pumpAndSettle();
      addTearDown(ready.dispose);

      expect(_splash(), findsNothing);
    });

    testWidgets('disabled, it hands the screen straight over', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PatraLaunch(enabled: false, child: SizedBox.expand()),
        ),
      );
      await tester.pump();

      expect(_splash(), findsNothing);
    });
  });
}
