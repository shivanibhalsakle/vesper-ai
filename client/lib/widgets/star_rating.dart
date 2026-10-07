import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Five tappable stars. Choosing one makes the stars up to it pop in a quick
/// wave from the first, each tinted a little further along the spectrum, with
/// a soft tick of haptics. Under reduced motion the stars simply fill.
class StarRating extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const StarRating({super.key, required this.value, required this.onChanged});

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> with SingleTickerProviderStateMixin {
  static const _stars = 5;

  // The wave: each star pops for [_pop] of the controller's run, starting
  // [_gap] after the one before it.
  static const _gap = 0.1;
  static const _pop = 0.35;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  int _waveTo = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _choose(int star) {
    AppHaptics.select();
    if (!AppMotion.reduced(context)) {
      _waveTo = star;
      _controller.forward(from: 0);
    }
    widget.onChanged(star);
  }

  double _scale(int star) {
    if (star > _waveTo) return 1;
    final local = ((_controller.value - (star - 1) * _gap) / _pop).clamp(0.0, 1.0);
    return 1 + 0.4 * math.sin(math.pi * local);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var star = 1; star <= _stars; star++)
            IconButton(
              key: Key('rate-$star'),
              tooltip: 'Rate $star ${star == 1 ? 'star' : 'stars'}',
              onPressed: () => _choose(star),
              icon: Transform.scale(
                key: Key('rate-scale-$star'),
                scale: _scale(star),
                child: Icon(
                  star <= widget.value ? Icons.star : Icons.star_border,
                  size: 32,
                  // Filled stars warm from amber toward dusk rose.
                  color: star <= widget.value
                      ? AppColors.spectrumAt(0.35 + 0.1 * (star - 1))
                      : theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
