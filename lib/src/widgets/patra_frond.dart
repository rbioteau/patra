import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The palm frond — Patra's mark, as drawn in the design handoff's
/// `master/patra-frond.svg` and shipped as every app icon.
///
/// Geometry is kept in the SVG's own 88x88 tile space so this file, the
/// Android vector (`res/drawable/patra_mark.xml`) and the icon bitmaps can be
/// read against one another. Nothing here reads a token from the theme except
/// the accent: parchment is brand-mark-only and never appears in the UI, so it
/// deliberately has no token in `theme.dart`.

/// Brand-mark-only. Never use this for UI — see the handoff.
const _parchment = Color(0xFFE9E2D0);

/// One blade of the fan: its angle off the spine, its length, and how much
/// parchment it carries. The centre blade is the accent one and is the only
/// thing in the mark that is not parchment.
class FrondBlade {
  const FrondBlade(this.rotation, this.length, {this.alpha, this.halfWidth});

  final double rotation;
  final double length;

  /// Null on the accent blade, which is opaque.
  final double? alpha;
  final double? halfWidth;

  bool get isAccent => alpha == null;
  Color get color =>
      alpha == null ? patraAccent : _parchment.withValues(alpha: alpha);
}

/// Which fan to draw. The choice is a size rule, not a taste: the five blades
/// and the gaps between them close into a blob once the mark is drawn under
/// about 20pt, and the three-blade fan is what it becomes there.
///
/// Every icon *file* at or under 72px is rendered compact for that reason (see
/// `tool/gen_app_icons.sh`). In the app the mark is painted rather than
/// rasterised, so the answer is to draw it big enough for the full fan instead:
/// the header does exactly that.
enum FrondVariant { full, compact }

/// The mark in the design's own coordinates, so every consumer — this widget,
/// the launch animation, the Android vector — measures the same thing.
abstract final class FrondGeometry {
  /// The side of the square tile the mark is drawn on.
  static const tile = 88.0;

  /// Where every blade is hinged, per variant.
  static const fullPivot = Offset(44, 68);
  static const compactPivot = Offset(44, 66);

  /// In page order: left to right, which is also the order the launch
  /// animation turns them in.
  static const full = [
    FrondBlade(-50, 38, alpha: .34),
    FrondBlade(-26, 46, alpha: .58),
    FrondBlade(0, 52),
    FrondBlade(26, 46, alpha: .46),
    FrondBlade(50, 38, alpha: .26),
  ];

  static const compact = [
    FrondBlade(-32, 44, alpha: .45, halfWidth: 3.4),
    FrondBlade(0, 48, halfWidth: 3.4),
    FrondBlade(32, 44, alpha: .18, halfWidth: 3.4),
  ];

  /// Half the width of a blade, and so also the radius of its rounded ends:
  /// every blade is a capsule, never a rounded rectangle.
  static const bladeHalfWidth = 2.6;

  /// The short accent stem below the pivot, which the launch animation grows
  /// before any blade is turned.
  static const stemHalfWidth = 1.6;
  static const stemTop = -2.0;
  static const stemLength = 8.0;

  static List<FrondBlade> bladesOf(FrondVariant v) =>
      v == FrondVariant.full ? full : compact;

  static Offset pivotOf(FrondVariant v) =>
      v == FrondVariant.full ? fullPivot : compactPivot;

  /// What the mark actually covers inside the tile, which is not the tile: the
  /// fan sits low and leaves the top corners empty. Every caller that wants
  /// the mark to *fill* a box — the header logo, the launch animation's
  /// landing — has to size against this rather than against the tile, or the
  /// mark shrinks inside its own padding.
  static Rect boundsOf(FrondVariant v) {
    final pivot = pivotOf(v);
    var left = double.infinity, right = -double.infinity;
    var top = double.infinity, bottom = -double.infinity;

    // A capsule is the segment between its two end-cap centres, grown by the
    // radius in every direction — so its extremes come off the caps, not off
    // the corners a rectangle would have.
    void grow(Offset centre, double radius) {
      left = math.min(left, centre.dx - radius);
      right = math.max(right, centre.dx + radius);
      top = math.min(top, centre.dy - radius);
      bottom = math.max(bottom, centre.dy + radius);
    }

    for (final blade in bladesOf(v)) {
      final r = blade.halfWidth ?? bladeHalfWidth;
      final a = blade.rotation * math.pi / 180;
      for (final y in [-blade.length + r, -r]) {
        grow(
          Offset(-y * math.sin(a) + pivot.dx, y * math.cos(a) + pivot.dy),
          r,
        );
      }
    }
    if (v == FrondVariant.full) {
      grow(Offset(pivot.dx, pivot.dy + stemTop + stemHalfWidth), stemHalfWidth);
      grow(
        Offset(pivot.dx, pivot.dy + stemTop + stemLength - stemHalfWidth),
        stemHalfWidth,
      );
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Draws one blade, already rotated into place, as a capsule.
void paintBlade(
  Canvas canvas,
  FrondBlade blade, {
  required double length,
  required double halfWidth,
  required Color color,
}) {
  canvas.save();
  canvas.rotate(blade.rotation * math.pi / 180);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-halfWidth, -length, halfWidth * 2, length),
      Radius.circular(halfWidth),
    ),
    Paint()..color = color,
  );
  canvas.restore();
}

/// The app's own logo: the mark alone, fitted to the box it is given.
///
/// [height] is the height of the mark itself, not of the tile it is drawn on —
/// so a 16pt frond next to a wordmark stands 16pt tall rather than losing a
/// third of itself to the tile's empty top corners.
class PatraFrond extends StatelessWidget {
  const PatraFrond({
    super.key,
    required this.height,
    this.variant = FrondVariant.full,
  });

  final double height;

  /// The five-blade fan by default, because that is the mark — the app icon's
  /// and the one the launch animation unfurls. Drop to [FrondVariant.compact]
  /// only where the mark has to be drawn too small for it to stay open.
  final FrondVariant variant;

  @override
  Widget build(BuildContext context) {
    final bounds = FrondGeometry.boundsOf(variant);
    return SizedBox(
      width: height * bounds.width / bounds.height,
      height: height,
      // The mark carries no text of its own; the wordmark beside it is what
      // a screen reader reads.
      child: CustomPaint(painter: _FrondPainter(variant)),
    );
  }
}

class _FrondPainter extends CustomPainter {
  const _FrondPainter(this.variant);

  final FrondVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = FrondGeometry.boundsOf(variant);
    final scale = size.height / bounds.height;
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);

    final pivot = FrondGeometry.pivotOf(variant);
    canvas.translate(pivot.dx, pivot.dy);
    for (final blade in FrondGeometry.bladesOf(variant)) {
      paintBlade(
        canvas,
        blade,
        length: blade.length,
        halfWidth: blade.halfWidth ?? FrondGeometry.bladeHalfWidth,
        color: blade.color,
      );
    }
    if (variant == FrondVariant.full) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -FrondGeometry.stemHalfWidth,
            FrondGeometry.stemTop,
            FrondGeometry.stemHalfWidth * 2,
            FrondGeometry.stemLength,
          ),
          const Radius.circular(FrondGeometry.stemHalfWidth),
        ),
        Paint()..color = patraAccent,
      );
    }
  }

  @override
  bool shouldRepaint(_FrondPainter old) => old.variant != variant;
}
