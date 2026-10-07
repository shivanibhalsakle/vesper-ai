import 'package:flutter/material.dart';

import '../models/best_date.dart';
import '../models/geocode_result.dart';
import '../models/preference_profile.dart';
import '../services/api_client.dart';
import '../utils/format.dart';
import '../widgets/rise_in.dart';
import '../widgets/save_date_button.dart';
import '../widgets/sky_detail_view.dart';
import '../widgets/week_chart.dart';

/// The answer to "give me a pretty sky": the best day in the coming week,
/// how every day scored, and that day's forecast set against the user's taste.
class BestDateResultScreen extends StatelessWidget {
  final BestDateResponse response;
  final PreferenceProfile preferences;

  /// Where the search was centred; used to label the saved date when the
  /// best day has no specific mapped spot.
  final PickedLocation location;

  final ApiClient? apiClient;

  const BestDateResultScreen({
    super.key,
    required this.response,
    required this.preferences,
    required this.location,
    this.apiClient,
  });

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
                RiseIn(
                  index: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatLongDate(best.date), style: theme.textTheme.headlineSmall),
                      if (best.spot != null)
                        Text(
                          'Best spot: ${best.spot!.name} · ${best.spot!.type.label} · '
                          '${best.spot!.distanceKm.toStringAsFixed(1)} km away',
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RiseIn(
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How the week looks', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      WeekChart(days: response.days, bestDate: best.date),
                    ],
                  ),
                ),
                const Divider(height: 40),
                RiseIn(
                  index: 2,
                  child: SkyDetailView(sky: best.sky, preferences: preferences),
                ),
                const SizedBox(height: 16),
                RiseIn(
                  index: 3,
                  child: SaveDateButton(
                    eventDate: best.date,
                    event: best.sky.event,
                    lat: best.spot?.lat ?? location.lat,
                    lon: best.spot?.lon ?? location.lon,
                    label: best.spot?.name ?? location.label,
                    savedScore: best.sky.preferenceMatchScore,
                    apiClient: apiClient,
                  ),
                ),
              ],
            ),
    );
  }
}
