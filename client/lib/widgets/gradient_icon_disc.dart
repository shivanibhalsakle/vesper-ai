import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// A round badge holding a white icon on a two-colour gradient, used to give
/// each action a splash of the dawn-to-dusk palette.
///
/// With a [heroTag], the disc glides between screens that show the same tag
/// (the home card's disc travels into its screen's header). Under reduced
/// motion it stays put and no flight happens.
class GradientIconDisc extends StatelessWidget {
  final IconData icon;
  final Color from;
  final Color to;
  final double size;
  final Object? heroTag;

  const GradientIconDisc({
    super.key,
    required this.icon,
    required this.from,
    required this.to,
    this.size = 44,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );

    if (heroTag == null || AppMotion.reduced(context)) return disc;
    return Hero(tag: heroTag!, child: disc);
  }
}
