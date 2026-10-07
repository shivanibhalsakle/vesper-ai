import 'package:flutter/material.dart';

import '../models/preference_profile.dart';
import '../models/session_request.dart';
import '../models/sky_forecast.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'score_ring.dart';
import 'sun_arc.dart';

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
        if (score != null)
          Center(
            child: Column(
              children: [
                ScoreRing(score: score),
                const SizedBox(height: 4),
                Text('match with your taste', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        Center(child: Chip(label: Text('${sky.confidence.label} · $_leadText'))),
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
        // The window drawn on the sun's path: at the end of the day for a
        // sunset, at the start for a sunrise. Illustrative, not to scale.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SunArc(
            height: 56,
            highlight: sky.event == SunEvent.sunset ? (0.80, 0.96) : (0.04, 0.20),
          ),
        ),
        const SizedBox(height: 4),
        Text('Sun visibility: ${formatPercent(sky.visibilityLikelihood)}'),
        Text(sky.cloudCoverSummary[0].toUpperCase() + sky.cloudCoverSummary.substring(1)),
        const Divider(height: 32),
        Text('Expected sky', style: theme.textTheme.titleMedium),
        if (wanted != null && wanted.hasSkyPreference)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              'The sun shows how much you want each one.',
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

/// A read-only bar filled with the dawn-to-dusk spectrum up to [level]. When
/// [wanted] is set, a small sun sits at that position: how much the user
/// asked for, so forecast and taste can be compared at a glance.
class LevelBar extends StatelessWidget {
  final String label;
  final double level;
  final double? wanted;

  const LevelBar({super.key, required this.label, required this.level, this.wanted});

  static const _barHeight = 12.0;
  static const _sunSize = 24.0;

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
            height: _sunSize,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const barTop = (_sunSize - _barHeight) / 2;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: barTop,
                      height: _barHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(_barHeight / 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: barTop,
                      height: _barHeight,
                      width: width * level.clamp(0.0, 1.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_barHeight / 2),
                        // The gradient spans the whole bar and is revealed up
                        // to the level, so a colour always means the same
                        // amount (not "squeezed" into short bars).
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: width,
                          maxWidth: width,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(gradient: AppColors.spectrumGradient),
                          ),
                        ),
                      ),
                    ),
                    if (marker != null)
                      Positioned(
                        left: (width * marker.clamp(0.0, 1.0) - _sunSize / 2)
                            .clamp(-2.0, width - _sunSize + 2),
                        top: 0,
                        child: const _SunMarker(key: Key('preference-marker')),
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

class _SunMarker extends StatelessWidget {
  const _SunMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LevelBar._sunSize,
      height: LevelBar._sunSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.beigeBorder),
      ),
      child: const Icon(Icons.wb_sunny_rounded, size: 17, color: AppColors.sun),
    );
  }
}
