import 'package:flutter/material.dart';

/// A round badge holding a white icon on a two-colour gradient, used to give
/// each action a splash of the dawn-to-dusk palette.
class GradientIconDisc extends StatelessWidget {
  final IconData icon;
  final Color from;
  final Color to;
  final double size;

  const GradientIconDisc({
    super.key,
    required this.icon,
    required this.from,
    required this.to,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}
