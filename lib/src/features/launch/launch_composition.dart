import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// The launch animation's timeline, as pure functions of authored time.
///
/// This is a transcription of the design handoff's `patra-launch.jsx`, kept
/// separate from the widgets so the beats can be read — and pinned — without a
/// tree. Every number here comes from that file or from its scene list; none
/// of them are ours to round.
///
/// Five beats, in seconds:
///
/// | Beat     | Starts | Lasts | What happens                                |
/// |----------|--------|-------|---------------------------------------------|
/// | Stem     |    0.0 |   1.1 | one accent stem grows out of the ink        |
/// | Unfurl   |    1.1 |   2.3 | five blades are turned like pages, L to R   |
/// | Wordmark |    3.4 |   1.4 | the wordmark rises, its accent period pops  |
/// | Settle   |    4.8 |   0.8 | the frond breathes once and holds           |
/// | Handoff  |    5.6 |   2.2 | the frond flies to the header, the app rises|
abstract final class LaunchCue {
  static const stem = 0.0;
  static const unfurl = 1.1;
  static const wordmark = 3.4;
  static const settle = 4.8;
  static const handoff = 5.6;
  static const total = 7.8;
}

/// The four eases the composition is authored with.
abstract final class _Motion {
  /// Things arriving.
  static const enter = Curves.easeOutCubic;

  /// Things springing open — the stem, the wordmark's period.
  static const unfurl = Curves.easeOutBack;

  /// A page being turned.
  static const pageTurn = Curves.easeInOutCubic;

  /// Things leaving, and the flight into the header.
  static const exit = Curves.easeInOutQuart;
}

/// `from` before `start`, `to` after `end`, eased in between.
double _at(
  double t,
  double from,
  double to,
  double start,
  double end,
  Curve ease,
) {
  if (t <= start) return from;
  if (t >= end) return to;
  return from + (to - from) * ease.transform((t - start) / (end - start));
}

/// One blade mid-turn.
class BladeTurn {
  const BladeTurn({
    required this.rotation,
    required this.widthFactor,
    required this.opacity,
  });

  /// Where the blade is right now — it starts flat out at [LaunchStage.pageFrom]
  /// and swings to its place in the fan.
  final double rotation;

  /// How wide the blade is drawn as a fraction of its full width. A page
  /// reads as a page by foreshortening: thin as it crosses the spine, full
  /// once it has landed.
  final double widthFactor;

  final double opacity;
}

/// The whole composition at one instant.
class LaunchStage {
  const LaunchStage(this.t);

  /// Authored time, in seconds from the first frame.
  final double t;

  /// Every page starts its turn from here — flat out to the left, so the five
  /// of them sweep across the spine in order rather than growing in place.
  static const pageFrom = -72.0;

  /// One blade every 0.26s, in page order.
  static const bladeStagger = 0.26;
  static const bladeTurn = 0.72;

  bool get isDone => t >= LaunchCue.total;

  /// 0 to 1 with an overshoot, over the first 0.55s.
  double get stemGrow =>
      _at(t, 0, 1, LaunchCue.stem, LaunchCue.stem + 0.55, _Motion.unfurl);

  /// The breath: the frond swells 4% and holds there. It never comes back
  /// down — the hold is the point of the beat.
  double get frondScale =>
      _at(t, 1, 1.04, LaunchCue.settle, LaunchCue.settle + 0.5, _Motion.enter);

  /// What a piece of the lockup that is *landing* is worth: it holds until the
  /// thing it is arriving on has begun to fade in, and that tenth of a second
  /// of overlap is what makes it one mark arriving rather than two.
  double get landingOpacity => _at(
    t,
    1,
    0,
    LaunchCue.handoff + 0.82,
    LaunchCue.handoff + 1.0,
    _Motion.exit,
  );

  /// The flight into the header: 0 at the splash's centre, 1 landed.
  double get flight => _at(
    t,
    0,
    1,
    LaunchCue.handoff + 0.1,
    LaunchCue.handoff + 0.95,
    _Motion.exit,
  );

  /// The blade [index] in page order, on its way to [landsAt] degrees.
  BladeTurn blade(int index, double landsAt) {
    final start = LaunchCue.unfurl + index * bladeStagger;
    final turn = _at(t, 0, 1, start, start + bladeTurn, _Motion.pageTurn);
    final settled = ((turn - 0.55) / 0.45).clamp(0.0, 1.0);
    return BladeTurn(
      rotation: pageFrom + (landsAt - pageFrom) * turn,
      // The flip runs slightly ahead of the swing, so a blade has most of its
      // width back by the time it lands.
      widthFactor: 0.18 + 0.82 * math.min(1.0, math.pow(turn, 0.8).toDouble()),
      opacity: turn > 0 ? 0.55 + 0.45 * settled : 0,
    );
  }

  /// How far the wordmark still has to rise, in logical pixels.
  double get wordmarkRise => _at(
    t,
    14,
    0,
    LaunchCue.wordmark,
    LaunchCue.wordmark + 0.7,
    _Motion.enter,
  );

  /// The wordmark arriving, at the beat of its own name.
  double get wordmarkAppear =>
      _at(t, 0, 1, LaunchCue.wordmark, LaunchCue.wordmark + 0.5, _Motion.enter);

  /// The wordmark leaving at the handoff, which is what the composition does
  /// with it: the header it hands off to draws the word at its own smaller
  /// size, so there is nothing for it to land on. Where a screen *does* draw
  /// it at the splash's size it travels instead and holds — see
  /// [landingOpacity].
  double get wordmarkLeaves =>
      _at(t, 1, 0, LaunchCue.handoff, LaunchCue.handoff + 0.4, _Motion.exit);

  /// The composition's own wordmark opacity: it arrives, then it leaves.
  double get wordmarkOpacity => wordmarkAppear * wordmarkLeaves;

  /// The accent period pops in half a second after the word it belongs to.
  double get dotScale => _at(
    t,
    0,
    1,
    LaunchCue.wordmark + 0.5,
    LaunchCue.wordmark + 0.95,
    _Motion.unfurl,
  );

  /// The ink the splash is painted on, lifting off the app behind it. The app's
  /// own background is one shade darker, so this is the whole crossfade.
  double get inkOpacity =>
      _at(t, 1, 0, LaunchCue.handoff, LaunchCue.handoff + 0.9, _Motion.exit);

  static const _appIn = LaunchCue.handoff + 0.35;

  double get appOpacity => _at(t, 0, 1, _appIn, _appIn + 0.5, _Motion.enter);

  /// How far the app still has to rise, in logical pixels.
  double get appRise => _at(t, 18, 0, _appIn, _appIn + 0.7, _Motion.enter);

  /// The header's own logo, arriving as the flying frond leaves.
  double get logoReveal => _at(
    t,
    0,
    1,
    LaunchCue.handoff + 0.9,
    LaunchCue.handoff + 1.05,
    _Motion.enter,
  );
}
