import 'package:flutter/material.dart';

import '../theme.dart';
import 'patra_logo_paths.dart';

/// The Latin signature: the word "patra" in the brand kit's own outlines,
/// plus the accent period. One definition shared by the wordmark widget,
/// the launch animation, and the web mark generator.
///
/// The kit exports the signature **without** the period — the lockup it ships
/// is the word alone — so the period is drawn here, measured off the outlines
/// rather than eyed: the letters' x-height is 13.97 and Source Serif 4's is
/// 486/1000 em, which puts the em at 28.7, and a period is about .115em
/// across, its gap its own left side bearing. A tenth of a unit is a tenth of
/// a pixel at the size this is drawn, so the numbers below can be the round
/// ones.
const _dotRadius = 1.7;
const _dotGap = 2.2;

/// The letters' baseline, in the kit's own units.
///
/// The letters bottom out between 28.31 and 28.39 depending on whether they
/// are flat or round, and a tenth of a unit is a tenth of a pixel at the size
/// this is drawn, so it can simply be the round one.
const _baseline = 28.39;

/// Where the period's centre sits: on the baseline, a side bearing past the
/// final "a".
const _dotCentre = Offset(
  PatraLogoPaths.wordmarkWidth + _dotGap + _dotRadius,
  _baseline - _dotRadius,
);

/// The signature's own extent: the word and its period together, measured off
/// the outlines rather than taken from the box the kit draws in.
///
/// That box reserves the room the em needs above the letters, so a widget
/// measured by it would carry its ink a third of an em below the box's middle
/// — and the mark beside it is measured by its ink (`PatraMark`), so the two
/// would sit at different heights in one row. 0.8 em of word beside 0.832 em
/// of signature is exactly what puts the two spans on top of one another,
/// which is the whole of what [PatraWordmark.markEm] claims; that only holds
/// if both are centred on what they actually draw.
final Rect signatureBounds = Path.combine(
  PathOperation.union,
  PatraLogoPaths.wordmark,
  Path()..addOval(Rect.fromCircle(center: _dotCentre, radius: _dotRadius)),
).getBounds();

/// The width the signature occupies in the kit's own units, the period
/// included. Centring on the word alone and appending the period hangs the
/// lockup off to the right of the mark's own axis, so both are centred
/// together.
final double signatureWidth = signatureBounds.width;

/// Derived from the letters' x-height of 13.97 and Source Serif 4's 486/1000
/// em: 13.97 / 0.486 ≈ 28.7. This is the one number that ties the outlines
/// to a point size — [size] in [PatraWordmark] and [PatraLockup] has always
/// meant the font size (the em), not the box height.
const _em = 28.7;

/// Converts a font size in points into the width the signature occupies.
double widthFor(double size) => signatureBounds.width * size / _em;

/// Converts a font size in points into the height the signature occupies.
double heightFor(double size) => signatureBounds.height * size / _em;

/// Paints the signature in the kit's raw coordinate space (1 unit = 1 point
/// at the em of 28.7), without font-size scaling. Used by the launch animation
/// which composes the signature in the mark's coordinate space.
void paintSignatureRaw(
  Canvas canvas, {
  required double dotScale,
  required double opacity,
}) {
  // Draw the word in patraText.
  final wordPaint = Paint()
    ..color = patraText.withValues(alpha: opacity);
  canvas.drawPath(PatraLogoPaths.wordmark, wordPaint);

  // Draw the period in patraAccent.
  if (dotScale > 0) {
    canvas.save();
    canvas.translate(_dotCentre.dx, _dotCentre.dy);
    canvas.scale(dotScale);
    final dotPaint = Paint()
      ..color = patraAccent.withValues(alpha: opacity);
    canvas.drawCircle(Offset.zero, _dotRadius, dotPaint);
    canvas.restore();
  }
}

/// A painter that draws the signature for use in [CustomPaint].
class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.size,
    this.dotScale = 1.0,
    this.opacity = 1.0,
  });

  final double size;
  final double dotScale;
  final double opacity;

  @override
  void paint(Canvas canvas, Size sz) {
    canvas.scale(size / _em);
    // The widget's box is the signature's ink, and the outlines are drawn in
    // the kit's own coordinates — so the ink is put at the box's corner.
    canvas.translate(-signatureBounds.left, -signatureBounds.top);
    paintSignatureRaw(canvas, dotScale: dotScale, opacity: opacity);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.dotScale != dotScale ||
      oldDelegate.opacity != opacity;
}

/// A widget that draws the signature from outlines.
///
/// The signature is the brand kit's, and the app's serif is not the kit's
/// any more (it is Literata). Drawing it from the paths is what keeps the
/// mark the kit's — and what makes the launch animation land on the screens
/// exactly, which is the one moment the two are compared directly.
class PatraSignature extends StatelessWidget {
  const PatraSignature({
    super.key,
    required this.size,
    this.dotScale = 1.0,
    this.opacity = 1.0,
  });

  /// The signature's font size in points (the em).
  final double size;

  /// The accent period springs in a beat after the word during the launch
  /// animation. Everywhere else it is simply there.
  final double dotScale;

  /// The launch fades the word in; everywhere else it is opaque.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Patra',
      image: true,
      child: SizedBox(
        width: widthFor(size),
        height: heightFor(size),
        child: CustomPaint(
          painter: _SignaturePainter(
            size: size,
            dotScale: dotScale,
            opacity: opacity,
          ),
        ),
      ),
    );
  }
}