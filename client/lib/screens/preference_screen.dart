import 'package:flutter/material.dart';

import '../models/location_type.dart';
import '../models/preference_profile.dart';
import '../models/session_request.dart';
import '../services/api_client.dart';
import 'results_screen.dart';

class PreferenceScreen extends StatefulWidget {
  final double lat;
  final double lon;
  final SunEvent event;
  final DateTime date;
  final double radiusKm;
  final List<LocationType> placeTypes;

  const PreferenceScreen({
    super.key,
    required this.lat,
    required this.lon,
    required this.event,
    required this.date,
    required this.radiusKm,
    required this.placeTypes,
  });

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  double _clearSky = 0.0;
  double _dramaticClouds = 0.0;
  double _pinkPurple = 0.0;
  double _goldenOrange = 0.0;
  double _redSky = 0.0;
  double _silhouettes = 0.0;
  double _waterReflection = 0.0;
  double _cityScape = 0.0;
  double _unobstructedHorizon = 0.0;

  bool _loading = false;

  Future<void> _submit() async {
    final preferences = PreferenceProfile(
      clearSky: _clearSky,
      dramaticClouds: _dramaticClouds,
      pinkPurple: _pinkPurple,
      goldenOrange: _goldenOrange,
      redSky: _redSky,
      silhouettes: _silhouettes,
      waterReflection: _waterReflection,
      cityScape: _cityScape,
      unobstructedHorizon: _unobstructedHorizon,
    );

    final request = SessionRequest(
      lat: widget.lat,
      lon: widget.lon,
      event: widget.event,
      date: widget.date,
      radiusKm: widget.radiusKm,
      placeTypes: widget.placeTypes,
      preferences: preferences,
    );

    setState(() => _loading = true);
    try {
      final response = await ApiClient().fetchSession(request);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(response: response, event: widget.event),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not fetch recommendations: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 10,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sky preferences')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How much do you love each of these?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _slider('Clear sky, visible sun', _clearSky, (v) => setState(() => _clearSky = v)),
            _slider('Dramatic clouds', _dramaticClouds, (v) => setState(() => _dramaticClouds = v)),
            _slider('Pink / purple tones', _pinkPurple, (v) => setState(() => _pinkPurple = v)),
            _slider('Golden / orange light', _goldenOrange, (v) => setState(() => _goldenOrange = v)),
            _slider('Red skies', _redSky, (v) => setState(() => _redSky = v)),
            const Divider(height: 32),
            Text('Location composition', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Used for location matching once Phase 3+ wiring covers it — collected now for your profile.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _slider('Silhouettes', _silhouettes, (v) => setState(() => _silhouettes = v)),
            _slider(
                'Water reflection', _waterReflection, (v) => setState(() => _waterReflection = v)),
            _slider('City skyline', _cityScape, (v) => setState(() => _cityScape = v)),
            _slider('Unobstructed horizon', _unobstructedHorizon,
                (v) => setState(() => _unobstructedHorizon = v)),
            const Divider(height: 32),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Describe it in your own words (optional)',
                hintText: 'e.g. "I love when the clouds catch fire but I still want to see the sun"',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              enabled: false,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Free-text parsing arrives with the Explanation Generator (Claude API) — sliders above are fully wired for now.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Get recommendations'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
