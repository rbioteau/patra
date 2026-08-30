import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/patra_frond.dart';
import '../../widgets/patra_wordmark.dart';
import 'launch_composition.dart';

/// The app's launch animation, from the design handoff's `patra-launch.jsx`.
///
/// It wraps the whole app rather than being a route of its own, because the
/// last beat needs both at once: the frond flying across the screen and the
/// app it is flying into, laid out and ready underneath. Keeping the app in
/// the tree from the first frame also means its first requests are made — and
/// usually answered — while the splash is still playing, so the shelves that
/// fade up are the real ones rather than skeletons.
///
/// The splash never returns: it is created once, at app start, and takes
/// itself out of the tree when it is done. A resume is not a launch.
class LaunchAnimation extends StatefulWidget {
  const LaunchAnimation({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchAnimation> createState() => _LaunchAnimationState();
}

class _LaunchAnimationState extends State<LaunchAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: (LaunchCue.total * 1000) ~/ 1),
  );

  /// What the header's own logo is worth right now. Read by [LaunchLogoSlot]
  /// through the scope, so the header can hold its logo back until the flying
  /// frond is on top of it.
  final _logoReveal = ValueNotifier<double>(0);

  /// The places on screen the lockup is flying to, and where its own wordmark
  /// stands before it leaves. All measured once, when the flight begins,
  /// rather than every frame.
  ///
  /// A screen offering no mark slot — there is none while signing in with the
  /// keyboard up, or on any screen that is not the landing one — leaves the
  /// frond to fade where it stands. A screen offering no *wordmark* slot, which
  /// is every screen but the login masthead, leaves the wordmark to fade at the
  /// handoff as the composition authored it.
  Rect? _markSlot;
  Rect? _wordmarkSlot;
  Rect? _wordmarkRest;
  final _marks = LaunchSlot();
  final _wordmarks = LaunchSlot();
  final _wordmarkKey = GlobalKey();

  /// Measured, rather than "a slot was found": a screen offering none is a
  /// perfectly good answer, and asking again every frame would be the bug.
  bool _landingsMeasured = false;

  /// The stage the frame currently laid out was built from.
  ///
  /// Everything the animation measures, it measures through that frame's own
  /// offsets — and it is the *painted* one, not the current one, because a
  /// measurement taken in a tick reads the frame before it. At 60fps the two
  /// are a sixtieth of a second apart and the difference is a fraction of a
  /// pixel; in a test that pumps one large frame it is the whole of the rise.
  LaunchStage _painted = const LaunchStage(LaunchCue.stem);

  bool _done = false;
  bool _checkedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_tick);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedMotion) return;
    _checkedMotion = true;
    // Someone who has asked the OS for less motion is not asking to watch a
    // logo assemble itself for eight seconds.
    if (MediaQuery.disableAnimationsOf(context)) _finish();
  }

  void _tick() {
    final stage = LaunchStage(_controller.value * LaunchCue.total);
    if (stage.flight > 0 && !_landingsMeasured) _measureLandings();
    _logoReveal.value = stage.logoReveal;
    if (_controller.isCompleted) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _finish() {
    if (_done) return;
    _controller.stop();
    _logoReveal.value = 1;
    setState(() => _done = true);
  }

  /// Where each piece of the lockup is flying from, and to.
  ///
  /// The app is still riding its own rise when the flight begins, and a slot
  /// inside it can only be measured through that: taking a rect as it stands
  /// would aim a piece at where it is on its way in and land it a rise below
  /// where it ends up. The splash's own wordmark needs no such correction — it
  /// is not in the app — but it does have to be measured through the wrapper
  /// *outside* its flight transform, or the rest it reports is already moving.
  void _measureLandings() {
    _landingsMeasured = true;
    // A slot lives inside the app, so it is measured through the app's rise.
    final appRise = Offset(0, -_painted.appRise);
    _markSlot = _marks.rect()?.shift(appRise);
    _wordmarkSlot = _wordmarks.rect()?.shift(appRise);
    // The splash's own wordmark is not in the app, but it has a rise of its
    // own from the beat it arrived on.
    final rest = _wordmarkKey.currentContext?.findRenderObject();
    if (rest is RenderBox && rest.hasSize) {
      _wordmarkRest = (rest.localToGlobal(Offset.zero) & rest.size).shift(
        Offset(0, -_painted.wordmarkRise),
      );
    }
  }

  /// Skipping still lands: the frond is sent straight to the last beat and
  /// flies home, rather than the splash being cut out from under the app.
  void _skip() {
    if (_done) return;
    _controller.value = LaunchCue.handoff / LaunchCue.total;
    _controller.animateTo(1, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _controller.dispose();
    _logoReveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = LaunchScope(
      logoReveal: _logoReveal,
      marks: _marks,
      wordmarks: _wordmarks,
      child: widget.child,
    );
    if (_done) return app;

    final stage = LaunchStage(_controller.value * LaunchCue.total);
    final size = MediaQuery.sizeOf(context);
    _painted = stage;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The ground the splash is painted on, lifting to the app's own one
        // shade of background. The app above it is opaque, so once it has
        // faded in this is no longer visible at all.
        ColoredBox(color: patraBg),
        Opacity(
          opacity: stage.inkOpacity,
          child: const ColoredBox(color: patraInk),
        ),
        Opacity(
          opacity: stage.appOpacity,
          child: Transform.translate(
            offset: Offset(0, stage.appRise),
            child: app,
          ),
        ),
        _SplashWordmark(
          stage: stage,
          height: size.height,
          restKey: _wordmarkKey,
          rest: _wordmarkRest,
          slot: _wordmarkSlot,
        ),
        _FlyingFrond(stage: stage, screen: size, slot: _markSlot),
        // Above everything: the splash owns the screen until it is done, and
        // a tap anywhere sends it home.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

/// The wordmark, rising under the frond with its accent period a beat behind —
/// and then either fading at the handoff or travelling into place.
///
/// The composition fades it out, because the header it hands off to draws the
/// wordmark at its own smaller size and a shrinking word would only cross over
/// a different one. The login masthead draws it at the splash's own size, so
/// there the word does not resize at all: it travels, and the splash's lockup
/// simply becomes the screen's. That is the whole of the login outro.
class _SplashWordmark extends StatelessWidget {
  const _SplashWordmark({
    required this.stage,
    required this.height,
    required this.restKey,
    required this.rest,
    required this.slot,
  });

  final LaunchStage stage;
  final double height;

  /// Wraps the flight transform rather than sitting inside it, so what it
  /// measures is where the wordmark stands rather than where it has got to.
  final GlobalKey restKey;

  final Rect? rest;
  final Rect? slot;

  static const size = 40.0;

  /// On the word itself, *inside* the flight transform, so a test can measure
  /// where it actually landed. [restKey] wraps that transform and measures
  /// where it started; the two must not be the same key.
  static const flownKey = ValueKey('launch-wordmark');

  @override
  Widget build(BuildContext context) {
    final travelling = rest != null && slot != null;
    Widget wordmark = PatraWordmark(
      key: flownKey,
      size: size,
      dotScale: stage.dotScale,
    );

    if (travelling && stage.flight > 0) {
      final from = rest!, to = slot!;
      final shrink = 1 + (to.height / from.height - 1) * stage.flight;
      final travel = (to.center - from.center) * stage.flight;
      wordmark = Transform(
        origin: from.size.center(Offset.zero),
        transform: Matrix4.identity()
          ..translateByDouble(travel.dx, travel.dy, 0, 1)
          ..scaleByDouble(shrink, shrink, 1, 1),
        child: wordmark,
      );
    }

    return Positioned(
      top: height * 0.58 + stage.wordmarkRise,
      left: 0,
      right: 0,
      // The splash is drawn in MaterialApp's `builder`, which is above the
      // Navigator and so outside every Material in the app. Text there falls
      // back to Flutter's error style, and since the wordmark's own style sets
      // a size and a colour but no decoration, the one attribute that leaks
      // through is a yellow double underline. This is the ancestor that
      // supplies a real DefaultTextStyle; transparency so it paints nothing.
      child: Material(
        type: MaterialType.transparency,
        child: Opacity(
          opacity:
              stage.wordmarkAppear *
              (travelling ? stage.landingOpacity : stage.wordmarkLeaves),
          // Centre first, so the box measured is the word's own rather than
          // the full width of the screen the text is centred in.
          child: Center(
            child: KeyedSubtree(key: restKey, child: wordmark),
          ),
        ),
      ),
    );
  }
}

/// The frond itself: five blades turned like pages, then flown into the
/// header.
class _FlyingFrond extends StatelessWidget {
  const _FlyingFrond({
    required this.stage,
    required this.screen,
    required this.slot,
  });

  final LaunchStage stage;
  final Size screen;

  /// Where the header logo is, if the app on screen has one.
  final Rect? slot;

  /// The side of the square tile the frond is drawn on at rest. The mark
  /// covers rather less than this — the tile's top corners are empty — which
  /// is exactly why the flight is measured against the mark's own bounds.
  static const tileSide = 300.0;

  /// The centre of the tile, as a fraction of the screen. The frond sits above
  /// the middle so the wordmark can rise underneath it.
  static const tileCentre = Offset(0.5, 0.32);

  /// On the tile the frond is painted on, so a test can measure where the mark
  /// actually landed rather than trusting the numbers that put it there.
  static const tileKey = ValueKey('launch-frond-tile');

  @override
  Widget build(BuildContext context) {
    final bounds = FrondGeometry.boundsOf(FrondVariant.full);
    final scale = tileSide / FrondGeometry.tile;
    final tileOrigin = Offset(
      screen.width * tileCentre.dx - tileSide / 2,
      screen.height * tileCentre.dy - tileSide / 2,
    );
    // Where the mark — not the tile — stands at rest.
    final rest = Rect.fromLTWH(
      tileOrigin.dx + bounds.left * scale,
      tileOrigin.dy + bounds.top * scale,
      bounds.width * scale,
      bounds.height * scale,
    );
    final target = slot ?? rest;

    final flight = stage.flight;
    final shrink = 1 + (target.height / rest.height - 1) * flight;
    final travel = (target.center - rest.center) * flight;

    return Positioned(
      left: tileOrigin.dx,
      top: tileOrigin.dy,
      child: Transform(
        origin: rest.center - tileOrigin,
        transform: Matrix4.identity()
          ..translateByDouble(travel.dx, travel.dy, 0, 1)
          ..scaleByDouble(shrink, shrink, 1, 1),
        child: Opacity(
          opacity: stage.landingOpacity,
          child: SizedBox.square(
            key: tileKey,
            dimension: tileSide,
            child: CustomPaint(painter: _UnfurlPainter(stage)),
          ),
        ),
      ),
    );
  }
}

/// The frond mid-assembly. Draws the same blades as [PatraFrond], each caught
/// somewhere between flat out to the left and its place in the fan.
class _UnfurlPainter extends CustomPainter {
  const _UnfurlPainter(this.stage);

  final LaunchStage stage;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / FrondGeometry.tile);

    // The breath swells the frond about the tile's own centre, which is above
    // the pivot: the fan opens upward rather than growing off its stem.
    canvas.translate(44, 44);
    canvas.scale(stage.frondScale);
    canvas.translate(0, 24);

    final blades = FrondGeometry.full;
    for (var i = 0; i < blades.length; i++) {
      final blade = blades[i];
      final turn = stage.blade(i, blade.rotation);
      if (turn.opacity <= 0) continue;
      paintBlade(
        canvas,
        FrondBlade(turn.rotation, blade.length, alpha: blade.alpha),
        length: blade.length,
        halfWidth: FrondGeometry.bladeHalfWidth * turn.widthFactor,
        color: blade.color.withValues(alpha: blade.color.a * turn.opacity),
      );
    }

    final grown = FrondGeometry.stemLength * stage.stemGrow;
    if (grown > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -FrondGeometry.stemHalfWidth,
            FrondGeometry.stemTop,
            FrondGeometry.stemHalfWidth * 2,
            grown,
          ),
          Radius.circular(
            FrondGeometry.stemHalfWidth.clamp(0, grown / 2).toDouble(),
          ),
        ),
        Paint()..color = patraAccent,
      );
    }
  }

  @override
  bool shouldRepaint(_UnfurlPainter old) => old.stage.t != stage.t;
}

/// One place on screen the launch animation can land a piece of its lockup on.
///
/// A slot is registered by the widget that draws it and looked up by its
/// render box, rather than by a global key handed down: the login screen and
/// the home header both carry slots now, and a route transition can have both
/// mounted for a frame, which a single global key answers with a crash.
class LaunchSlot {
  final _mounted = <State<StatefulWidget>>[];

  void _add(State<StatefulWidget> slot) => _mounted.add(slot);
  void _remove(State<StatefulWidget> slot) => _mounted.remove(slot);

  /// Where the most recently mounted slot sits, in screen coordinates, or null
  /// when nothing on screen offers one.
  Rect? rect() {
    for (final slot in _mounted.reversed) {
      if (!slot.mounted) continue;
      final box = slot.context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        return box.localToGlobal(Offset.zero) & box.size;
      }
    }
    return null;
  }
}

/// Carries the launch animation down to the screen it hands off to.
class LaunchScope extends InheritedWidget {
  const LaunchScope({
    super.key,
    required this.logoReveal,
    required this.marks,
    required this.wordmarks,
    required super.child,
  });

  /// What a landing place is worth right now: 0 while the flying lockup still
  /// owns it, 1 once it has arrived.
  final ValueListenable<double> logoReveal;

  /// Where the frond lands. Every screen that shows the mark offers one.
  final LaunchSlot marks;

  /// Where the wordmark lands — offered only where the screen draws it at the
  /// splash's own size, which is the login masthead. Without one the wordmark
  /// simply fades at the handoff, as authored.
  final LaunchSlot wordmarks;

  static LaunchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LaunchScope>();

  @override
  bool updateShouldNotify(LaunchScope old) =>
      old.logoReveal != logoReveal ||
      old.marks != marks ||
      old.wordmarks != wordmarks;
}

/// The frond as a screen's own logo, and the place the launch animation flies
/// its frond to.
class LaunchLogoSlot extends StatefulWidget {
  const LaunchLogoSlot({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchLogoSlot> createState() => _LaunchLogoSlotState();
}

class _LaunchLogoSlotState extends _SlotState<LaunchLogoSlot> {
  @override
  LaunchSlot slotOf(LaunchScope scope) => scope.marks;

  @override
  Widget get slotChild => widget.child;
}

/// The wordmark as a screen's own, and the place the launch animation flies
/// its wordmark to. Only a screen drawing it at the splash's size should offer
/// one: the point of the landing is that the word does not resize, it travels.
class LaunchWordmarkSlot extends StatefulWidget {
  const LaunchWordmarkSlot({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchWordmarkSlot> createState() => _LaunchWordmarkSlotState();
}

class _LaunchWordmarkSlotState extends _SlotState<LaunchWordmarkSlot> {
  @override
  LaunchSlot slotOf(LaunchScope scope) => scope.wordmarks;

  @override
  Widget get slotChild => widget.child;
}

/// Registers itself with the scope while mounted, and holds its child back
/// until the flying piece is on top of it.
abstract class _SlotState<W extends StatefulWidget> extends State<W> {
  LaunchSlot slotOf(LaunchScope scope);
  Widget get slotChild;

  LaunchSlot? _registered;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = LaunchScope.maybeOf(context);
    final slot = scope == null ? null : slotOf(scope);
    if (identical(slot, _registered)) return;
    _registered?._remove(this);
    _registered = slot?.._add(this);
  }

  @override
  void dispose() {
    _registered?._remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = LaunchScope.maybeOf(context);
    if (scope == null) return slotChild;
    return ValueListenableBuilder<double>(
      valueListenable: scope.logoReveal,
      builder: (_, reveal, child) => Opacity(opacity: reveal, child: child),
      child: slotChild,
    );
  }
}
