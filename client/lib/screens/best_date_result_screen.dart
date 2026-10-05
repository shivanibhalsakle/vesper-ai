import 'package:flutter/material.dart';

import '../models/best_date.dart';
import '../models/preference_profile.dart';
import '../utils/format.dart';
import '../widgets/sky_detail_view.dart';

/// The answer to "give me a pretty sky": the best day in the coming week,
/// how every day scored, and that day's forecast set against the user's taste.
class BestDateResultScreen extends StatelessWidget {
  final BestDateResponse response;
  final PreferenceProfile preferences;

  const BestDateResultScreen({super.key, required this.response, required this.preferences});

  @override
  Widget build(BuildContext context) {
    final best = response.best;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Your best sky')),
      body: best == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No upcoming days could be scored. Try again a little later.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(formatLongDate(best.date), style: theme.textTheme.headlineSmall),
                if (best.spot != null)
                  Text(
                    'Best spot: ${best.spot!.name} · ${best.spot!.type.label} · '
                    '${best.spot!.distanceKm.toStringAsFixed(1)} km away',
                    style: theme.textTheme.bodyMedium,
                  ),
                const SizedBox(height: 16),
                Text('How the week looks', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in response.days)
                      _DayTile(day: day, isBest: day.date == best.date),
                  ],
                ),
                const Divider(height: 40),
                SkyDetailView(sky: best.sky, preferences: preferences),
              ],
            ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DayScore day;
  final bool isBest;

  const _DayTile({required this.day, required this.isBest});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: isBest ? const Key('best-day-tile') : null,
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isBest ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isBest ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(formatShortWeekday(day.date)),
          Text('${day.date.day}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            formatPercent(day.score),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
