import 'package:flutter/material.dart';

import '../settings/reading_settings.dart';

/// A page glyph with the flow arrow *inside* it. Bare arrows read as
/// navigation, which is why the page outline is part of the mark. Icon-only
/// and language-free: the wording lives in the menu rows.
class DirectionIcon extends StatelessWidget {
  const DirectionIcon(
    this.direction, {
    super.key,
    this.size = 18,
    this.color = Colors.white,
  });

  final ReadingDirection direction;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _DirectionPainter(direction: direction, color: color),
    );
  }
}

class _DirectionPainter extends CustomPainter {
  const _DirectionPainter({required this.direction, required this.color});

  final ReadingDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 12;
    final page = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: .75)
      ..strokeJoin = StrokeJoin.round;
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.15
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The page: a portrait rectangle inset from the icon box. It has to read
    // as a page at 19px, so it takes most of the box and the arrow stays well
    // clear of its border — an arrow touching the frame reads as "exit".
    final rect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.06,
      size.width * 0.70,
      size.height * 0.88,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.08)),
      page,
    );

    final center = rect.center;
    final head = size.width * 0.11;
    switch (direction) {
      case ReadingDirection.leftToRight:
      case ReadingDirection.rightToLeft:
        final sign = direction == ReadingDirection.leftToRight ? 1.0 : -1.0;
        final half = rect.width * 0.20;
        final tip = Offset(center.dx + sign * half, center.dy);
        canvas.drawLine(Offset(center.dx - sign * half, center.dy), tip, arrow);
        canvas.drawLine(tip, tip.translate(-sign * head, -head), arrow);
        canvas.drawLine(tip, tip.translate(-sign * head, head), arrow);
      case ReadingDirection.webtoon:
        final half = rect.height * 0.22;
        final tip = Offset(center.dx, center.dy + half);
        canvas.drawLine(Offset(center.dx, center.dy - half), tip, arrow);
        canvas.drawLine(tip, tip.translate(-head, -head), arrow);
        canvas.drawLine(tip, tip.translate(head, -head), arrow);
    }
  }

  @override
  bool shouldRepaint(_DirectionPainter old) =>
      old.direction != direction || old.color != color;
}
