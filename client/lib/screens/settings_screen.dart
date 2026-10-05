import 'package:flutter/material.dart';

import '../models/geocode_result.dart';
import '../models/location_type.dart';
import '../models/preference_profile.dart';
import '../models/session_request.dart';
import '../models/trip_window.dart';
import '../models/user_preferences.dart';
import '../services/api_client.dart';
import '../widgets/location_picker.dart';
import '../widgets/preference_sliders.dart';
import 'trip_window_result_screen.dart';

/// Where the user's standing preferences live: home location, search
/// defaults and sky sliders. Loaded from and saved to the backend.
class SettingsScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const SettingsScreen({super.key, this.apiClient});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  bool _finding = false;

  PickedLocation? _home;
  SunEvent _event = SunEvent.sunset;
  double _radiusKm = 10.0;
  final Set<LocationType> _placeTypes = {};
  PreferenceProfile _preferences = const PreferenceProfile();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final saved = await _apiClient.fetchPreferences();
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _home = saved.home;
          _event = saved.event;
          _radiusKm = saved.radiusKm.clamp(1.0, 50.0);
          _placeTypes
            ..clear()
            ..addAll(saved.placeTypes);
          _preferences = saved.preferences;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  UserPreferences _current() => UserPreferences(
        home: _home,
        radiusKm: _radiusKm,
        placeTypes: _placeTypes.toList(),
        event: _event,
        preferences: _preferences,
      );

  void _toast(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _apiClient.savePreferences(_current());
      if (!mounted) return;
      _toast('Preferences saved');
    } catch (e) {
      if (!mounted) return;
      _toast('Could not save preferences: $e',
          action: SnackBarAction(label: 'Retry', onPressed: _save));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _findDate() async {
    final home = _home;
    if (home == null) {
      _toast('Choose a location first.');
      return;
    }
    setState(() => _finding = true);
    try {
      final today = DateTime.now();
      final request = TripWindowRequest(
        lat: home.lat,
        lon: home.lon,
        event: _event,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
        radiusKm: _radiusKm,
        placeTypes: _placeTypes.isEmpty ? LocationType.values.toList() : _placeTypes.toList(),
        preferences: _preferences,
      );
      final response = await _apiClient.fetchTripWindow(request);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripWindowResultScreen(response: response, event: _event),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Could not find a date: $e',
          action: SnackBarAction(label: 'Retry', onPressed: _findDate));
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load your settings: $_loadError',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your home spot', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          LocationPicker(
            value: _home,
            apiClient: _apiClient,
            onChanged: (location) => setState(() => _home = location),
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
          const SizedBox(height: 24),
          Text('Travel radius: ${_radiusKm.toStringAsFixed(0)} km'),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            label: '${_radiusKm.toStringAsFixed(0)} km',
            onChanged: (value) => setState(() => _radiusKm = value),
          ),
          const SizedBox(height: 8),
          Text('Place type', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LocationType.values.map((type) {
              return FilterChip(
                label: Text(type.label),
                selected: _placeTypes.contains(type),
                onSelected: (isSelected) => setState(() {
                  if (isSelected) {
                    _placeTypes.add(type);
                  } else {
                    _placeTypes.remove(type);
                  }
                }),
              );
            }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No selection = no preference (all types included).',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(height: 40),
          Text('How much do you love each of these?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          PreferenceSliders(
            value: _preferences,
            onChanged: (value) => setState(() => _preferences = value),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _saving || _finding ? null : _save,
              child: _saving ? const _Spinner() : const Text('Save preferences'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || _finding ? null : _findDate,
              child: _finding ? const _Spinner() : const Text('Find me a good viewing date'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
