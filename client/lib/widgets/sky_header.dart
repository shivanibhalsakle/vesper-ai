import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/day_phase.dart';

/// The soft sky behind the home screen's wordmark: a gradient that follows
/// the time of day, a sun (or moon), a couple of clouds and a white horizon
/// the page rises out of. [child] sits on top (wordmark and menu buttons).
class SkyHeader extends StatelessWidget {
  final DayPhase phase;
  final Widget child;
  final double topInset;

  const SkyHeader({
    super.key,
    required this.phase,
    required this.child,
    this.topInset = 0,
  });

  static const _contentHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final height = _contentHeight + topInset;
    final sky = phase.sky;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: sky,
                ),
              ),
            ),
          ),
          // Sun / moon, half sunk behind the horizon.
          Positioned(
            right: 36,
            top: topInset + 44,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: phase.orb.withValues(alpha: phase == DayPhase.night ? 1 : 0.9),
              ),
            ),
          ),
          Positioned(right: 130, top: topInset + 62, child: _cloud(64, 0.75)),
          Positioned(right: 20, top: topInset + 96, child: _cloud(46, 0.6)),
          // The page's white surface curving up over the bottom of the sky.
          Positioned(
            left: -24,
            right: -24,
            bottom: -34,
            height: 64,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.all(Radius.elliptical(400, 64)),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _cloud(double width, double alpha) => Container(
        width: width,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(12),
        ),
      );
}
