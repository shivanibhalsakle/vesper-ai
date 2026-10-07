import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ten dots flying outward from [origin] and fading, for a one-shot burst.
/// Drive [t] from 0 to 1 (an animation's value) and repaint.
class SparklePainter extends CustomPainter {
  final Offset origin;
  final double t;
  final Color color;

  SparklePainter({required this.origin, required this.t, this.color = Colors.white});

  static const _count = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOut.transform(t);
    for (var i = 0; i < _count; i++) {
      final angle = i / _count * 2 * math.pi;
      final distance = 30 + 40 * eased;
      final at = origin + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        at,
        2 + 4 * (1 - t),
        Paint()..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(SparklePainter old) =>
      old.t != t || old.origin != origin || old.color != color;
}
