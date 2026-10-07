import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Fades its child in while it rises a few pixels, once, when it first
/// appears. Give each item on a screen its position as [index] and they
/// arrive one after another (a short, capped stagger).
///
/// The child is on screen and tappable from the first frame: only its
/// opacity and offset animate, so this never delays anything. With reduced
/// motion it simply appears.
class RiseIn extends StatefulWidget {
  final Widget child;
  final int index;

  const RiseIn({super.key, required this.child, this.index = 0});

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final Duration _delay =
      AppMotion.riseStagger * widget.index.clamp(0, AppMotion.riseMaxSteps);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + AppMotion.riseDuration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    // Wait out the delay, then ease in over the item's own duration.
    curve: Interval(
      _delay.inMilliseconds / _controller.duration!.inMilliseconds,
      1.0,
      curve: AppMotion.curve,
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
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, AppMotion.riseDistance * (1 - _progress.value)),
          child: child,
        ),
      ),
    );
  }
}
