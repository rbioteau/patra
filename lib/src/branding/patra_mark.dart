import 'package:flutter/material.dart';

import '../theme.dart';
import 'patra_logo_paths.dart';

/// The word's own extent, measured once off the two leaves together.
///
/// The 150-unit box the paths are drawn in carries the room the shirorekha
/// needs above and the matras below, so a widget measured by the box would
/// reserve two and a half times the height the word actually occupies — which
/// in the home header is the difference between a 24pt mark and a 57pt hole.
/// [PatraMark] is asked for the word's height and answers with exactly it.
final Rect _wordBounds = Path.combine(
  PathOperation.union,
  PatraLogoPaths.leaf1,
  PatraLogoPaths.leaf2,
).getBounds();

/// The brand mark: the word पत्र, drawn in the accent gold.
///
/// Outlines rather than text, and so no font to load and nothing to fetch —
/// see [PatraLogoPaths]. It therefore costs nothing to draw on the first
/// frame, which is the frame the launch animation is painted on, and it is
/// the same shape at every size, from the home header to the gate screens.
///
/// The word alone. Where the Latin signature goes with it — the home header,
/// the two gate screens — it is `PatraWordmark` beside it, which is what this
/// app has always drawn; the kit's stacked lockup is the launch animation's
/// composition, not a screen's.
class PatraMark extends StatelessWidget {
  const PatraMark({super.key, required this.height, this.color});

  /// The height of the word itself.
  final double height;

  /// Defaults to [patraAccent], the brand gold. The mark is identity, and the
  /// accent is the one token that means it.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scale = height / _wordBounds.height;
    return Semantics(
      label: 'Patra',
      image: true,
      child: SizedBox(
        width: _wordBounds.width * scale,
        height: height,
        child: CustomPaint(painter: _MarkPainter(color: color ?? patraAccent)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _wordBounds.height;
    canvas.scale(scale);
    canvas.translate(-_wordBounds.left, -_wordBounds.top);
    final paint = Paint()..color = color;
    canvas.drawPath(PatraLogoPaths.leaf1, paint);
    canvas.drawPath(PatraLogoPaths.leaf2, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
