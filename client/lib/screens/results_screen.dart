import 'package:flutter/material.dart';

import '../models/session_request.dart';
import '../models/session_response.dart';
import '../utils/format.dart';

class ResultsScreen extends StatelessWidget {
  final SessionResponse response;
  final SunEvent event;

  const ResultsScreen({super.key, required this.response, required this.event});

  @override
  Widget build(BuildContext context) {
    final recommendations = response.recommendations;

    return Scaffold(
      appBar: AppBar(title: const Text('Top spots')),
      body: recommendations.isEmpty
          ? const Center(child: Text('No locations found in this radius.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recommendations.length,
              itemBuilder: (context, index) => _LocationCard(
                result: recommendations[index],
                rank: index + 1,
                event: event,
              ),
            ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LocationResult result;
  final int rank;
  final SunEvent event;

  const _LocationCard({required this.result, required this.rank, required this.event});

  @override
  Widget build(BuildContext context) {
    final eventLabel = event.label.toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('$rank')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('${result.type.label} · ${result.distanceKm.toStringAsFixed(1)} km away'),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatPercent(result.preferenceMatchScore),
                        style: Theme.of(context).textTheme.titleMedium),
                    const Text('match'),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            if (result.rainOrUnsafeAlert != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.rainOrUnsafeAlert!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('${event.label} at ${formatClockTime(result.eventTime)}'),
            Text(formatArrivalOffset(result.recommendedArrivalOffsetMinutes, eventLabel)),
            Text('Best viewing window: ${formatClockTime(result.bestViewingWindowStart)} – '
                '${formatClockTime(result.bestViewingWindowEnd)}'),
            const SizedBox(height: 12),
            Text('Sun visibility: ${formatPercent(result.visibilityLikelihood)}'),
            Text(
              result.cloudCoverSummary[0].toUpperCase() + result.cloudCoverSummary.substring(1),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _ColorChip('Pink', result.colorProbabilities.pink, Colors.pinkAccent),
                _ColorChip('Purple', result.colorProbabilities.purple, Colors.deepPurpleAccent),
                _ColorChip('Orange', result.colorProbabilities.orange, Colors.orangeAccent),
                _ColorChip('Red', result.colorProbabilities.red, Colors.redAccent),
                _ColorChip('Golden', result.colorProbabilities.golden, Colors.amber),
              ],
            ),
            if (result.explanation == null) ...[
              const SizedBox(height: 12),
              Text(
                'Personalized explanation coming soon (Explanation Generator).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final double probability;
  final Color color;

  const _ColorChip(this.label, this.probability, this.color);

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text('$label ${formatPercent(probability)}'),
    );
  }
}
