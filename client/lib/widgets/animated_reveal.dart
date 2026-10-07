import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Plays a 0-to-1 animation once, when first shown, and hands the eased
/// value to [builder] every frame. Rings, bars and arcs use it to draw
/// themselves in. Under reduced motion the value is 1 from the start.
///
/// [delay] holds the animation at 0 first, so a group of these can start one
/// after another.
class AnimatedReveal extends StatefulWidget {
  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const AnimatedReveal({
    super.key,
    required this.builder,
    this.duration = AppMotion.dataDuration,
    this.delay = AppMotion.dataDelay,
    this.curve = AppMotion.curve,
  });

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.delay + widget.duration);
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMilliseconds / _controller.duration!.inMilliseconds,
      1.0,
      curve: widget.curve,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => widget.builder(context, _t.value),
    );
  }
}
