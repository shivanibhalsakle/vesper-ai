import 'package:flutter/material.dart';

import 'app_theme.dart';

/// How one of the three main flows looks wherever it appears: on its home
/// card and at the top of its own screen (where the shared [heroTag] lets the
/// card's disc glide into the header).
class FlowStyle {
  final String id;
  final IconData icon;
  final Color from;
  final Color to;
  final String title;
  final String subtitle;

  const FlowStyle({
    required this.id,
    required this.icon,
    required this.from,
    required this.to,
    required this.title,
    required this.subtitle,
  });

  Object get heroTag => 'flow-disc-$id';
}

class Flows {
  const Flows._();

  /// The discs step through the spectrum, one segment each.
  static final bestDate = FlowStyle(
    id: 'best-date',
    icon: Icons.event_available,
    from: AppColors.spectrum[2],
    to: AppColors.spectrum[3],
    title: 'Pick me a pretty sky',
    subtitle: 'Find the best date in the next week for the sky you like.',
  );

  static final todaySky = FlowStyle(
    id: 'today-sky',
    icon: Icons.wb_twilight,
    from: AppColors.spectrum[3],
    to: AppColors.spectrum[4],
    title: 'How will the sky look today?',
    subtitle: "See today's forecast for any place.",
  );

  static final spots = FlowStyle(
    id: 'spots',
    icon: Icons.place_outlined,
    from: AppColors.spectrum[4],
    to: AppColors.spectrum[5],
    title: 'Find viewing spots near me',
    subtitle: 'Beaches, parks and viewpoints around a location.',
  );
}
