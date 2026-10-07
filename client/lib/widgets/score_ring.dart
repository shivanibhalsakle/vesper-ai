import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'animated_reveal.dart';

/// A ring that fills to [score] (0 to 1) in the dawn-to-dusk spectrum, with
/// the percentage in brush script at its centre. The ring's end colour is
/// the spectrum colour for the score, matching the sliders and bars.
///
/// When it first appears the ring fills and the number counts up to the
/// score. Screen readers get the final value straight away.
class ScoreRing extends StatelessWidget {
  final double score;
  final double size;

  const ScoreRing({super.key, required this.score, this.size = 124});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0.0, 1.0);
    return Semantics(
      label: '${formatPercent(clamped)} match',
      // The visible percentage is the same information; don't read it twice.
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedReveal(
          builder: (context, t) {
            final shown = clamped * t;
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: Size.square(size), painter: _RingPainter(shown)),
                Text(
                  formatPercent(shown),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: size * 0.3),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double score;

  _RingPainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.095;
    final rect = Offset(stroke / 2, stroke / 2) & Size.square(size.width - stroke);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.sand,
    );

    if (score <= 0) return;
    final sweep = 2 * math.pi * score;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          colors: AppColors.spectrum,
          stops: AppColors.spectrumStops,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );

    // Round the two ends by hand, each in its own spectrum colour. A round
    // stroke cap would sample the gradient *behind* the start and paint the
    // dusk colour onto the dawn end.
    final radius = rect.width / 2;
    void cap(double angle, Color colour) => canvas.drawCircle(
          rect.center + Offset(math.cos(angle), math.sin(angle)) * radius,
          stroke / 2,
          Paint()..color = colour,
        );
    cap(-math.pi / 2, AppColors.spectrumAt(0));
    cap(-math.pi / 2 + sweep, AppColors.spectrumAt(score));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.score != score;
}
