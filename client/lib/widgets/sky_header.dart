import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/day_phase.dart';

/// The soft sky behind the home screen's wordmark: a gradient that follows
/// the time of day, a sun (or moon), a couple of clouds and a white horizon
/// the page rises out of. [child] sits on top (wordmark and menu buttons).
///
/// The sky is alive, gently: the clouds drift across and the sun bobs. Both
/// are slow and quiet, stop when the screen is covered by another one, and
/// freeze under reduced motion.
class SkyHeader extends StatefulWidget {
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
  State<SkyHeader> createState() => _SkyHeaderState();
}

class _SkyHeaderState extends State<SkyHeader> with TickerProviderStateMixin {
  // The big cloud crosses in 45s, the small one in 90s.
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 90));
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final alive = AppMotion.ambientLoops && !AppMotion.reduced(context);
    if (alive) {
      if (!_drift.isAnimating) _drift.repeat();
      if (!_bob.isAnimating) _bob.repeat(reverse: true);
    } else {
      _drift
        ..stop()
        ..value = 0;
      _bob
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = SkyHeader._contentHeight + widget.topInset;
    final inset = widget.topInset;
    final phase = widget.phase;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: phase.sky,
                      ),
                    ),
                  ),
                ),
                // Sun / moon, half sunk behind the horizon, bobbing gently.
                Positioned(
                  right: 36,
                  top: inset + 44,
                  child: AnimatedBuilder(
                    animation: _bob,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, -6 * Curves.easeInOut.transform(_bob.value)),
                      child: child,
                    ),
                    child: Container(
                      key: const Key('header-sun'),
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: phase.orb.withValues(alpha: phase == DayPhase.night ? 1 : 0.9),
                      ),
                    ),
                  ),
                ),
                // Where each cloud rests when nothing moves: the layout the
                // header has always had.
                _cloud(const Key('header-cloud-0'), width, 64, inset + 62, 0.75,
                    rest: width - 194, laps: 2),
                _cloud(const Key('header-cloud-1'), width, 46, inset + 96, 0.6,
                    rest: width - 66, laps: 1),
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
                Positioned.fill(child: widget.child),
              ],
            ),
          );
        },
      ),
    );
  }

  /// A cloud that loops across the header [laps] times per drift cycle,
  /// starting from its resting spot. Whole laps keep the loop seamless.
  Widget _cloud(
    Key key,
    double headerWidth,
    double cloudWidth,
    double top,
    double alpha, {
    required double rest,
    required int laps,
  }) {
    final span = headerWidth + cloudWidth;
    final restFraction = (rest + cloudWidth) / span;

    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) {
        final v = (restFraction + _drift.value * laps) % 1.0;
        return Positioned(left: -cloudWidth + span * v, top: top, child: child!);
      },
      child: Container(
        key: key,
        width: cloudWidth,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
