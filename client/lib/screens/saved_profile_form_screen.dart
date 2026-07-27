import 'package:flutter/material.dart';

import '../models/location_type.dart';
import '../models/preference_profile.dart';
import '../models/saved_profile.dart';
import '../models/session_request.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

class SavedProfileFormScreen extends StatefulWidget {
  const SavedProfileFormScreen({super.key});

  @override
  State<SavedProfileFormScreen> createState() => _SavedProfileFormScreenState();
}

class _SavedProfileFormScreenState extends State<SavedProfileFormScreen> {
  final _latController = TextEditingController(text: '40.7003');
  final _lonController = TextEditingController(text: '-73.9967');

  SunEvent _event = SunEvent.sunset;
  double _radiusKm = 5.0;
  final Set<LocationType> _placeTypes = {};
  double _matchThreshold = 0.75;
  bool _notificationEnabled = true;

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

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid latitude and longitude.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = AuthService().currentUser;
      final fcmToken = await PushNotificationService().getToken();
      final types = _placeTypes.isEmpty ? LocationType.values.toList() : _placeTypes.toList();

      final request = SavedProfileRequest(
        userId: user!.uid,
        homeLat: lat,
        homeLon: lon,
        radiusKm: _radiusKm,
        placeTypes: types,
        event: _event,
        preferences: PreferenceProfile(
          clearSky: _clearSky,
          dramaticClouds: _dramaticClouds,
          pinkPurple: _pinkPurple,
          goldenOrange: _goldenOrange,
          redSky: _redSky,
          silhouettes: _silhouettes,
          waterReflection: _waterReflection,
          cityScape: _cityScape,
          unobstructedHorizon: _unobstructedHorizon,
        ),
        fcmToken: fcmToken,
        notificationEnabled: _notificationEnabled,
        matchThreshold: _matchThreshold,
      );

      await ApiClient().createSavedProfile(request);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
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
      appBar: AppBar(title: const Text('New saved search')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Home location', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SegmentedButton<SunEvent>(
              segments: const [
                ButtonSegment(value: SunEvent.sunrise, label: Text('Sunrise')),
                ButtonSegment(value: SunEvent.sunset, label: Text('Sunset')),
              ],
              selected: {_event},
              onSelectionChanged: (selection) => setState(() => _event = selection.first),
            ),
            const SizedBox(height: 16),
            Text('Travel radius: ${_radiusKm.toStringAsFixed(0)} km'),
            Slider(
              value: _radiusKm,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_radiusKm.toStringAsFixed(0)} km',
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
            const SizedBox(height: 16),
            Text('Place type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LocationType.values.map((type) {
                final selected = _placeTypes.contains(type);
                return FilterChip(
                  label: Text(type.label),
                  selected: selected,
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        _placeTypes.add(type);
                      } else {
                        _placeTypes.remove(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No selection = no preference (all types included).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(height: 32),
            Text('How much do you love each of these?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _slider('Clear sky, visible sun', _clearSky, (v) => setState(() => _clearSky = v)),
            _slider(
                'Dramatic clouds', _dramaticClouds, (v) => setState(() => _dramaticClouds = v)),
            _slider('Pink / purple tones', _pinkPurple, (v) => setState(() => _pinkPurple = v)),
            _slider(
                'Golden / orange light', _goldenOrange, (v) => setState(() => _goldenOrange = v)),
            _slider('Red skies', _redSky, (v) => setState(() => _redSky = v)),
            _slider('Silhouettes', _silhouettes, (v) => setState(() => _silhouettes = v)),
            _slider('Water reflection', _waterReflection,
                (v) => setState(() => _waterReflection = v)),
            _slider('City skyline', _cityScape, (v) => setState(() => _cityScape = v)),
            _slider('Unobstructed horizon', _unobstructedHorizon,
                (v) => setState(() => _unobstructedHorizon = v)),
            const Divider(height: 32),
            Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Alert me when the match score is at least '
                '${(_matchThreshold * 100).round()}%'),
            Slider(
              value: _matchThreshold,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(_matchThreshold * 100).round()}%',
              onChanged: (value) => setState(() => _matchThreshold = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notifications enabled'),
              value: _notificationEnabled,
              onChanged: (value) => setState(() => _notificationEnabled = value),
            ),
            const SizedBox(height: 24),
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
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
