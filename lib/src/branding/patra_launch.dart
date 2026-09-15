import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'patra_logo_paths.dart';

/// The key on the ground the splash paints. It is the same colour as the page
/// — the point of the brand is that the two are one surface — so a test cannot
/// tell the splash from a scaffold by colour alone.
const patraLaunchSplashKey = ValueKey('patra-launch-splash');

/// Two leaves drift in and settle into पत्र, the signature rises under it,
/// and the whole thing fades into [child]. 4.8 s.
///
/// The child is mounted and laid out underneath from the first frame — it is
/// only painted through the fade — so its first requests are made and usually
/// answered while this plays, and what fades up is the real screen rather than
/// a skeleton.
///
/// Mount once per app session and keep its key stable: it runs from its own
/// mount, not from a navigation.
class PatraLaunch extends StatefulWidget {
  const PatraLaunch({
    super.key,
    required this.child,
    this.ready = true,
    this.enabled = true,
    this.onFinished,
  });

  final Widget child;

  /// False holds the assembled mark before the final fade. Set it true once
  /// local initialisation is done **or** an error screen is up — it is not a
  /// question about the server, and waiting on one leaves somebody staring at
  /// a logo because their Kavita is on another network.
  final bool ready;

  /// False plays nothing at all — a handover, or a widget test.
  final bool enabled;

  final VoidCallback? onFinished;

  @override
  State<PatraLaunch> createState() => _PatraLaunchState();
}

class _PatraLaunchState extends State<PatraLaunch>
    with SingleTickerProviderStateMixin {
  static const _total = 4800.0;

  /// Where the mark is assembled and the fade begins.
  static const _holdPoint = 4050 / _total;

  late final AnimationController _controller =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 4800),
        )
        ..addListener(_handleTick)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });

  /// Whether there is anything to play, known before the first build: a
  /// splash that mounted and then took itself away would flash a frame of
  /// ink over whoever the app was just handed to.
  var _play = true;
  var _started = false;
  var _holding = false;
  var _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs before the first build, which is what lets `build` above decide
    // rather than undo.
    _play = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _resume();
    }
  }

  @override
  void didUpdateWidget(covariant PatraLaunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_finished || !_play) return;
    if (widget.ready && !oldWidget.ready) {
      _holding = false;
      _resume();
    }
  }

  /// Starts or picks the animation back up, from the frame after this one:
  /// `forward` marks the `AnimatedBuilder` dirty, which it must not do from
  /// inside a build.
  void _resume() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished) return;
      _controller.forward();
    });
  }

  void _handleTick() {
    if (!widget.ready && !_holding && _controller.value >= _holdPoint) {
      _holding = true;
      _controller.stop();
      _controller.value = _holdPoint;
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    setState(() => _finished = true);
    widget.onFinished?.call();
  }

  /// A tap sends it home: it seeks to the fade and lands, rather than cutting
  /// the animation out from under the app it is standing in front of.
  void skip() {
    if (_finished || !_play) return;
    _holding = false;
    _controller.stop();
    _controller.value = _holdPoint;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (!_play || _finished) return child;
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final ms = _controller.value * _total;
        final fade = Curves.easeInOut.transform(_interval(ms, 4050, 750));
        return Stack(
          fit: StackFit.expand,
          children: [
            // The app, mounted and laid out, waiting behind the fade.
            IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(opacity: fade, child: child),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: skip,
                child: Opacity(
                  opacity: 1 - fade,
                  child: ColoredBox(
                    key: patraLaunchSplashKey,
                    color: patraBg,
                    child: ClipRect(
                      child: Semantics(
                        label: 'Patra',
                        image: true,
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(0, -12),
                            child: SizedBox(
                              width: PatraLogoPaths.markWidth,
                              height: 181.4,
                              child: CustomPaint(painter: _LaunchPainter(ms)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _interval(double ms, double start, double duration) =>
    ((ms - start) / duration).clamp(0.0, 1.0).toDouble();

class _LaunchPainter extends CustomPainter {
  const _LaunchPainter(this.ms);

  final double ms;

  @override
  void paint(Canvas canvas, Size size) {
    if (ms >= 2950) {
      // One coordinate system for both outlines: exact final top-line join.
      final paint = Paint()..color = patraAccent;
      canvas.drawPath(PatraLogoPaths.leaf1, paint);
      canvas.drawPath(PatraLogoPaths.leaf2, paint);
    } else {
      _leaf(
        canvas,
        PatraLogoPaths.leaf1,
        start: 100,
        side: -1,
        height: 170,
        phase: 0,
        origin: Offset(PatraLogoPaths.splitX / 2, 81),
      );
      _leaf(
        canvas,
        PatraLogoPaths.leaf2,
        start: 550,
        side: 1,
        height: 145,
        phase: 1.2,
        origin: Offset(
          (PatraLogoPaths.splitX + PatraLogoPaths.markWidth) / 2,
          81,
        ),
      );
    }
    final t = Curves.easeOutCubic.transform(_interval(ms, 2400, 800));
    if (t > 0) {
      canvas.save();
      canvas.translate(
        (PatraLogoPaths.markWidth - PatraLogoPaths.wordmarkWidth) / 2,
        145 + 7 * (1 - t),
      );
      canvas.drawPath(
        PatraLogoPaths.wordmark,
        Paint()..color = patraText.withValues(alpha: t),
      );
      canvas.restore();
    }
  }

  void _leaf(
    Canvas canvas,
    Path path, {
    required double start,
    required double side,
    required double height,
    required double phase,
    required Offset origin,
  }) {
    final t = _interval(ms, start, 2400);
    if (t == 0) return;
    final r = 1 - t;
    final damping = r * r;
    final x =
        side * (96 * damping + 55 * math.sin(2.2 * math.pi * t) * damping);
    final y =
        -height * math.pow(r, 1.8) + 20 * math.sin(2 * math.pi * t) * damping;
    final rotation =
        side * (58 * damping + 38 * math.sin(3 * math.pi * t) * damping);
    final tilt = side * 38 * math.sin(3.5 * math.pi * t + phase) * damping;
    final scale = 1 - .12 * damping;
    final opacity = (t / .16).clamp(0.0, 1.0).toDouble();
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, -1 / 700)
      ..rotateZ(rotation * math.pi / 180)
      ..rotateY(tilt * math.pi / 180);
    canvas.save();
    canvas.translate(origin.dx + x, origin.dy + y);
    canvas.transform(matrix.storage);
    canvas.scale(scale);
    canvas.translate(-origin.dx, -origin.dy);
    canvas.drawPath(
      path,
      Paint()..color = patraAccent.withValues(alpha: opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LaunchPainter oldDelegate) =>
      oldDelegate.ms != ms;
}
