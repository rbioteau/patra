import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/launch/launch_animation.dart';
import 'package:patra/src/features/launch/launch_composition.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/patra_frond.dart';
import 'package:patra/src/widgets/patra_wordmark.dart';

/// A stand-in for the app the splash hands off to.
///
/// [withSlot] gives it a header carrying the mark, where the home screen puts
/// it. [withWordmarkSlot] gives it the login masthead's second landing place,
/// the one that makes the wordmark travel instead of fade.
Widget _app({
  bool withSlot = true,
  bool withWordmarkSlot = false,
  Size size = const Size(390, 844),
  bool reduceMotion = false,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: reduceMotion),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      // Mirrors how the real app mounts it: above the Navigator, so the splash
      // sits outside every Material in the app.
      builder: (_, child) =>
          LaunchAnimation(child: child ?? const SizedBox.shrink()),
      home: withWordmarkSlot
          ? const Scaffold(
              body: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LaunchLogoSlot(child: PatraFrond(height: 44)),
                    SizedBox(width: 32),
                    LaunchWordmarkSlot(child: PatraWordmark(size: 40)),
                  ],
                ),
              ),
            )
          : Scaffold(
              appBar: AppBar(
                title: withSlot
                    ? const LaunchLogoSlot(child: PatraFrond(height: 24))
                    : const Text('no slot'),
              ),
              body: const SizedBox.expand(),
            ),
    ),
  );
}

/// The splash's own wordmark, as it will actually be painted.
RenderParagraph _splashWordmark(WidgetTester tester) {
  return tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .firstWhere((p) => p.text.toPlainText().startsWith('patra'));
}

void main() {
  group('the composition keeps the beats it was authored with', () {
    test('the five beats add up to the whole', () {
      expect(LaunchCue.total, 7.8);
      expect(LaunchCue.unfurl - LaunchCue.stem, closeTo(1.1, 1e-9));
      expect(LaunchCue.wordmark - LaunchCue.unfurl, closeTo(2.3, 1e-9));
      expect(LaunchCue.settle - LaunchCue.wordmark, closeTo(1.4, 1e-9));
      expect(LaunchCue.handoff - LaunchCue.settle, closeTo(0.8, 1e-9));
      expect(LaunchCue.total - LaunchCue.handoff, closeTo(2.2, 1e-9));
    });

    test('the first frame is an empty ink screen', () {
      // The native launch window paints the ink and nothing else, so anything
      // visible at t=0 would appear out of nowhere on top of it.
      const first = LaunchStage(0);
      expect(first.stemGrow, 0);
      expect(first.wordmarkOpacity, 0);
      expect(first.inkOpacity, 1);
      expect(first.appOpacity, 0);
      for (var i = 0; i < FrondGeometry.full.length; i++) {
        expect(first.blade(i, FrondGeometry.full[i].rotation).opacity, 0);
      }
    });

    test('the stem is grown before the first page is turned', () {
      expect(const LaunchStage(0.55).stemGrow, 1);
      expect(
        const LaunchStage(LaunchCue.unfurl).blade(0, -50).opacity,
        0,
        reason: 'the first blade starts exactly on the Unfurl cue',
      );
    });

    test('the blades are turned one at a time, left to right', () {
      // Mid-beat, the leftmost page has landed and the rightmost has not begun.
      const mid = LaunchStage(LaunchCue.unfurl + 0.8);
      expect(mid.blade(0, -50).rotation, closeTo(-50, 1));
      expect(mid.blade(4, 50).rotation, LaunchStage.pageFrom);
      expect(mid.blade(4, 50).opacity, 0);

      // Each one starts where a page starts and lands on its place in the fan.
      final landed = LaunchStage(LaunchCue.wordmark);
      for (var i = 0; i < FrondGeometry.full.length; i++) {
        final blade = FrondGeometry.full[i];
        expect(landed.blade(i, blade.rotation).rotation, blade.rotation);
        expect(landed.blade(i, blade.rotation).widthFactor, closeTo(1, 1e-9));
        expect(landed.blade(i, blade.rotation).opacity, closeTo(1, 1e-9));
      }
    });

    test('a page is at its thinnest as it crosses the spine', () {
      const start = LaunchCue.unfurl;
      final crossing = LaunchStage(start + 0.02).blade(0, -50);
      final landed = LaunchStage(start + LaunchStage.bladeTurn).blade(0, -50);
      expect(crossing.widthFactor, lessThan(0.35));
      expect(landed.widthFactor, closeTo(1, 1e-9));
    });

    test('the app is fully up, and the ink gone, by the last frame', () {
      const end = LaunchStage(LaunchCue.total);
      expect(end.inkOpacity, 0);
      expect(end.appOpacity, 1);
      expect(end.appRise, 0);
      expect(end.landingOpacity, 0);
      expect(end.logoReveal, 1);
      expect(end.flight, 1);
    });

    test('the header logo arrives while the flying frond is still there', () {
      // The overlap is what makes it one mark landing rather than two marks.
      const t = LaunchCue.handoff + 0.95;
      expect(const LaunchStage(t).landingOpacity, greaterThan(0));
      expect(const LaunchStage(t).logoReveal, greaterThan(0));
      expect(const LaunchStage(t).flight, 1, reason: 'landed before it fades');
    });
  });

  group('the launch animation on screen', () {
    testWidgets('the splash wordmark is not painted in the error style', (
      tester,
    ) async {
      // The splash is built in MaterialApp's `builder`, above the Navigator
      // and so outside every Material in the app. Without an ancestor of its
      // own it inherits Flutter's error text style, whose one attribute the
      // wordmark's own style does not override is a yellow double underline.
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 4000));

      final style = _splashWordmark(tester).text.style!;
      expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
      expect(style.decorationStyle, isNot(TextDecorationStyle.double));

      await tester.pumpAndSettle();
    });

    testWidgets('the frond lands on the header logo, not beside it', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      // Just after the flight has finished and before the frond has faded.
      await tester.pump(
        const Duration(milliseconds: ((LaunchCue.handoff + 0.95) * 1000) ~/ 1),
      );

      // The tile is larger than the mark drawn on it — the fan leaves the top
      // corners empty — so what has to land on the slot is the mark's own
      // bounds, not the box they are painted in.
      final tile = tester.getRect(find.byKey(_FlyingFrondTile.key));
      final bounds = FrondGeometry.boundsOf(FrondVariant.full);
      final scale = tile.width / FrondGeometry.tile;
      final mark = Rect.fromLTWH(
        tile.left + bounds.left * scale,
        tile.top + bounds.top * scale,
        bounds.width * scale,
        bounds.height * scale,
      );
      final slot = tester.getRect(find.byType(LaunchLogoSlot));

      expect(mark.center.dx, closeTo(slot.center.dx, 1));
      expect(mark.center.dy, closeTo(slot.center.dy, 1));
      expect(mark.height, closeTo(slot.height, 1));

      await tester.pumpAndSettle();
    });

    testWidgets('with no logo slot the frond simply fades where it is', (
      tester,
    ) async {
      // Signing in, there is no header to hand off to; the splash must still
      // finish rather than aiming at nothing.
      await tester.pumpWidget(_app(withSlot: false));
      await tester.pumpAndSettle();

      expect(find.byType(LaunchLogoSlot), findsNothing);
      expect(find.text('no slot'), findsOneWidget);
    });

    testWidgets('a tap sends the splash home instead of cutting it out', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(Stack), findsWidgets);

      await tester.tapAt(const Offset(195, 700));
      await tester.pump();
      // Skipping still plays the landing: the app is not there yet.
      expect(tester.widget<Opacity>(_appOpacity(tester)).opacity, lessThan(1));

      await tester.pumpAndSettle();
      expect(find.byType(LaunchAnimation), findsOneWidget);
      // Done: the splash has taken itself out of the tree.
      expect(_splashInk(), findsNothing);
    });

    testWidgets('with a wordmark slot the word travels instead of fading', (
      tester,
    ) async {
      // The login masthead draws the wordmark at the splash's own size, so the
      // outro there is the lockup moving into place rather than the word
      // disappearing and a smaller one taking over.
      await tester.pumpWidget(_app(withWordmarkSlot: true));
      await tester.pump(
        const Duration(milliseconds: ((LaunchCue.handoff + 0.95) * 1000) ~/ 1),
      );

      final flown = tester.getRect(find.byKey(_FlyingWordmark.key));
      final slot = tester.getRect(find.byType(LaunchWordmarkSlot));
      expect(flown.center.dx, closeTo(slot.center.dx, 1));
      expect(flown.center.dy, closeTo(slot.center.dy, 1));
      expect(
        flown.height,
        closeTo(slot.height, 1),
        reason: 'the word travels at its own size; it must not have resized',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('the frond lands on the masthead mark, beside the word', (
      tester,
    ) async {
      await tester.pumpWidget(_app(withWordmarkSlot: true));
      await tester.pump(
        const Duration(milliseconds: ((LaunchCue.handoff + 0.95) * 1000) ~/ 1),
      );

      final tile = tester.getRect(find.byKey(_FlyingFrondTile.key));
      final bounds = FrondGeometry.boundsOf(FrondVariant.full);
      final scale = tile.width / FrondGeometry.tile;
      final mark = Rect.fromLTWH(
        tile.left + bounds.left * scale,
        tile.top + bounds.top * scale,
        bounds.width * scale,
        bounds.height * scale,
      );
      final slot = tester.getRect(find.byType(LaunchLogoSlot));
      expect(mark.center.dx, closeTo(slot.center.dx, 1));
      expect(mark.center.dy, closeTo(slot.center.dy, 1));
      expect(mark.height, closeTo(slot.height, 1));

      await tester.pumpAndSettle();
    });

    testWidgets('two slots on screen at once do not collide', (tester) async {
      // A route transition can have the login masthead and the home header
      // mounted in the same frame; the slots used to share one global key,
      // which answers that with a crash rather than a landing.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (_, child) => LaunchAnimation(child: child!),
            home: const Scaffold(
              body: Column(
                children: [
                  LaunchLogoSlot(child: PatraFrond(height: 24)),
                  LaunchLogoSlot(child: PatraFrond(height: 44)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(LaunchLogoSlot), findsNWidgets(2));
    });

    testWidgets('less motion means no launch animation at all', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: true));
      await tester.pump();

      expect(_splashInk(), findsNothing);
    });
  });
}

/// The app-fading Opacity the splash wraps its child in.
Finder _appOpacity(WidgetTester tester) => find
    .descendant(
      of: find.byType(LaunchAnimation),
      matching: find.byType(Opacity),
    )
    .at(1);

/// The key the splash puts on the tile it paints the frond on.
abstract final class _FlyingFrondTile {
  static const key = ValueKey('launch-frond-tile');
}

/// The key the splash puts around its own wordmark, outside the transform that
/// flies it, so what a test measures is where the word has got to.
abstract final class _FlyingWordmark {
  static const key = ValueKey('launch-wordmark');
}

/// Whether any of the splash is still on screen. Once it is done it returns
/// the app bare rather than leaving a transparent overlay behind, so the ink
/// it paints on is the thing to look for.
Finder _splashInk() =>
    find.byWidgetPredicate((w) => w is ColoredBox && w.color == patraInk);
