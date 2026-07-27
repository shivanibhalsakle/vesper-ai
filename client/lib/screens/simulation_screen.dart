import 'package:flutter/material.dart';

import '../models/simulation.dart';
import '../services/api_client.dart';
import 'dart:convert';

Widget _buildImage(String imageUrl) {
  // gpt-image-2 only returns base64 data (data: URI), not a hosted URL —
  // Image.network can't decode that, so route data: URIs through
  // Image.memory instead.
  if (imageUrl.startsWith('data:')) {
    final base64Data = imageUrl.split(',').last;
    return Image.memory(base64Decode(base64Data), fit: BoxFit.cover);
  }
  return Image.network(imageUrl);
}

class SimulationScreen extends StatefulWidget {
  final SimulationRequest request;
  final String locationName;

  const SimulationScreen({
    super.key,
    required this.request,
    required this.locationName,
  });

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  late final Future<SimulationResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient().fetchSimulation(widget.request);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview: ${widget.locationName}')),
      body: FutureBuilder<SimulationResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not generate a preview: ${snapshot.error}'),
              ),
            );
          }

          final result = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImage(result.imageUrl!),
                  )
                else
                  _ImagePlaceholder(providerStatus: result.providerStatus),
                const SizedBox(height: 20),
                Text('Illustrative description', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(result.prompt),
                const SizedBox(height: 20),
                Text(
                  result.disclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String providerStatus;

  const _ImagePlaceholder({required this.providerStatus});

  @override
  Widget build(BuildContext context) {
    final message = providerStatus == 'not_configured'
        ? "Image preview coming soon — here's the description it would be generated from:"
        : 'Could not generate an image preview right now.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
