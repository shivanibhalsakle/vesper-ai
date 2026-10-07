import 'package:flutter/material.dart';

import '../theme/flows.dart';
import 'gradient_icon_disc.dart';

/// The top of a flow screen: the same gradient disc as the home card that
/// opened it (sharing a hero tag, so it glides in from there) beside a line
/// saying what the screen is for.
class FlowHeader extends StatelessWidget {
  final FlowStyle flow;

  const FlowHeader({super.key, required this.flow});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GradientIconDisc(
          icon: flow.icon,
          from: flow.from,
          to: flow.to,
          size: 56,
          heroTag: flow.heroTag,
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(flow.subtitle, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}
