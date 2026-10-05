import 'package:flutter/material.dart';

import '../models/preference_profile.dart';
import '../models/sky_forecast.dart';
import '../utils/format.dart';

/// The predicted sky for one place and day: timing, conditions and the
/// five sky tags as bars. When [preferences] is given, each bar also shows a
/// marker for how much the user wants that tag, so forecast and taste can be
/// compared at a glance.
class SkyDetailView extends StatelessWidget {
  final SkyForecast sky;
  final PreferenceProfile? preferences;

  const SkyDetailView({super.key, required this.sky, this.preferences});

  String get _leadText => switch (sky.leadDays) {
        0 => 'today',
        1 => 'tomorrow',
        final days => 'in $days days',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventLabel = sky.event.label;
    final wanted = preferences;
    final score = sky.preferenceMatchScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (score != null) ...[
              Text(formatPercent(score), style: theme.textTheme.displaySmall),
              const SizedBox(width: 8),
              const Text('match with\nyour taste'),
              const Spacer(),
            ],
            Chip(label: Text('${sky.confidence.label} · $_leadText')),
          ],
        ),
        const SizedBox(height: 8),
        if (sky.rainOrUnsafeAlert != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sky.rainOrUnsafeAlert!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          '$eventLabel at ${formatClockTime(sky.eventTime)}'
          '${sky.eventPassed ? ' (already happened)' : ''}',
          style: theme.textTheme.titleMedium,
        ),
        Text(formatArrivalOffset(
            sky.recommendedArrivalOffsetMinutes, eventLabel.toLowerCase())),
        Text('Best viewing window: ${formatClockTime(sky.bestViewingWindowStart)} – '
            '${formatClockTime(sky.bestViewingWindowEnd)}'),
        const SizedBox(height: 12),
        Text('Sun visibility: ${formatPercent(sky.visibilityLikelihood)}'),
        Text(sky.cloudCoverSummary[0].toUpperCase() + sky.cloudCoverSummary.substring(1)),
        const Divider(height: 32),
        Text('Expected sky', style: theme.textTheme.titleMedium),
        if (wanted != null && wanted.hasSkyPreference)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              'The marker (│) shows how much you want each one.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        LevelBar(
            label: 'Clear sky, visible sun',
            level: sky.skyProfile.clearSky,
            wanted: wanted?.clearSky),
        LevelBar(
            label: 'Dramatic clouds',
            level: sky.skyProfile.dramaticClouds,
            wanted: wanted?.dramaticClouds),
        LevelBar(
            label: 'Pink / purple tones',
            level: sky.skyProfile.pinkPurple,
            wanted: wanted?.pinkPurple),
        LevelBar(
            label: 'Golden / orange light',
            level: sky.skyProfile.goldenOrange,
            wanted: wanted?.goldenOrange),
        LevelBar(label: 'Red skies', level: sky.skyProfile.redSky, wanted: wanted?.redSky),
        const SizedBox(height: 8),
        Text(
          'A forecast-based estimate, not a guarantee. Skies are hardest to call '
          'several days ahead.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A read-only, slider-styled bar: filled to [level], with an optional
/// marker at [wanted].
class LevelBar extends StatelessWidget {
  final String label;
  final double level;
  final double? wanted;

  const LevelBar({super.key, required this.label, required this.level, this.wanted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marker = wanted != null && wanted! > 0 ? wanted! : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(formatPercent(level))],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      top: 4,
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 4,
                      bottom: 4,
                      width: width * level.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    if (marker != null)
                      Positioned(
                        left: (width * marker.clamp(0.0, 1.0)) - 1.5,
                        top: 0,
                        bottom: 0,
                        width: 3,
                        child: DecoratedBox(
                          key: const Key('preference-marker'),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
