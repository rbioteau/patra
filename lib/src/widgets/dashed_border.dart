import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A dashed rounded outline: the handoff's mark for **a place to fill**.
///
/// It is what tells the "add a server" slot from the sign-in button beside
/// it, and what tells an empty library from a library still loading. Solid
/// borders in this design enclose something that is already there.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    this.radius = radiusCard,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash + gap) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
