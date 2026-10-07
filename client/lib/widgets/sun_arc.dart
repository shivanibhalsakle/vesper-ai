import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The sun's path across the sky as a half-circle. It can show how far the
/// sun has travelled ([progress]), highlight a stretch of the path
/// ([highlight], as fractions 0 to 1), or both.
class SunArc extends StatelessWidget {
  /// Where the sun is along the path (0 = sunrise horizon, 1 = sunset
  /// horizon). Null draws no sun.
  final double? progress;

  /// A stretch of the path to emphasise, e.g. the best viewing window.
  final (double, double)? highlight;

  /// Colour of the dot: the sun by day, something paler for the moon.
  final Color dotColor;

  final double height;

  const SunArc({
    super.key,
    this.progress,
    this.highlight,
    this.dotColor = AppColors.sun,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    // Capped width keeps the arc a pleasing half-circle on wide screens
    // instead of stretching into a flat sliver.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SunArcPainter(
              progress: progress,
              highlight: highlight,
              dotColor: dotColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  final double? progress;
  final (double, double)? highlight;
  final Color dotColor;

  _SunArcPainter({required this.progress, required this.highlight, required this.dotColor});

  static const _inset = 14.0;
  static const _dotRadius = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    // The arc is the top half of an ellipse whose centre sits on the bottom
    // edge, leaving room at the sides for the dot.
    final rx = size.width / 2 - _inset;
    final ry = size.height - _dotRadius - 2;
    final centre = Offset(size.width / 2, size.height - _dotRadius - 2);
    final oval = Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.beigeBorder;

    // Dashed ground path.
    final path = Path()..addArc(oval, math.pi, math.pi);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), base);
        distance += 10;
      }
    }

    void arcSegment(double from, double to, Paint paint) {
      canvas.drawArc(oval, math.pi + from * math.pi, (to - from) * math.pi, false, paint);
    }

    final p = progress;
    if (p != null && p > 0) {
      arcSegment(
        0,
        p.clamp(0.0, 1.0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = AppColors.sun,
      );
    }

    final h = highlight;
    if (h != null) {
      arcSegment(
        h.$1.clamp(0.0, 1.0),
        h.$2.clamp(0.0, 1.0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = AppColors.spectrum[3],
      );
    }

    if (p != null) {
      final angle = math.pi + p.clamp(0.0, 1.0) * math.pi;
      final dot = Offset(centre.dx + rx * math.cos(angle), centre.dy + ry * math.sin(angle));
      canvas.drawCircle(dot, _dotRadius + 2, Paint()..color = AppColors.white);
      canvas.drawCircle(dot, _dotRadius, Paint()..color = dotColor);
    }
  }

  @override
  bool shouldRepaint(_SunArcPainter old) =>
      old.progress != progress || old.highlight != highlight || old.dotColor != dotColor;
}
