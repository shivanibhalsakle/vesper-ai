import 'package:flutter/material.dart';

import '../models/best_date.dart';
import '../models/geocode_result.dart';
import '../models/preference_profile.dart';
import '../models/session_request.dart';
import '../models/user_preferences.dart';
import '../services/api_client.dart';
import '../theme/flows.dart';
import '../widgets/flow_header.dart';
import '../widgets/location_picker.dart';
import '../widgets/preference_sliders.dart';
import '../widgets/sky_loader.dart';
import 'best_date_result_screen.dart';

/// Flow 1: confirm (or tweak, for this search only) your taste and where
/// you'll be, then get the best sky date in the coming week.
class BestDateScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const BestDateScreen({super.key, this.apiClient});

  @override
  State<BestDateScreen> createState() => _BestDateScreenState();
}

class _BestDateScreenState extends State<BestDateScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  bool _loadingSaved = true;
  String? _loadError;
  bool _searching = false;
  String? _searchError;

  UserPreferences _saved = const UserPreferences();
  // The taste used for this search. It starts as the saved one and can be
  // adjusted here, but is never written back: saved preferences stay as they are.
  PreferenceProfile _taste = const PreferenceProfile();
  PickedLocation? _location;
  SunEvent _event = SunEvent.sunset;

  @override
  void initState() {
    super.initState();
    _loadSaved(initial: true);
  }

  Future<void> _loadSaved({bool initial = false}) async {
    setState(() {
      _loadingSaved = true;
      _loadError = null;
    });
    try {
      final saved = await _apiClient.fetchPreferences();
      if (!mounted) return;
      setState(() {
        _saved = saved ?? const UserPreferences();
        _taste = _saved.preferences;
        // Keep a location the user already picked here; otherwise start from
        // their saved home spot.
        if (initial || _location == null) _location = _saved.home;
        _event = _saved.event;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _findDate() async {
    final location = _location;
    if (location == null) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final response = await _apiClient.fetchBestDate(BestDateRequest(
        lat: location.lat,
        lon: location.lon,
        event: _event,
        startDate: DateTime.now(),
        radiusKm: _saved.radiusKm,
        placeTypes: _saved.placeTypes,
        preferences: _taste,
      ));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BestDateResultScreen(
            response: response,
            preferences: _taste,
            location: location,
            apiClient: _apiClient,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick me a pretty sky')),
      body: _loadingSaved
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load your preferences: $_loadError',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _loadSaved, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _searching
                  // The search takes a few seconds: give it the whole screen
                  // and something lovely to look at.
                  ? const SkyLoader(
                      message: 'Looking at the next 7 days',
                      height: null,
                      showWordmark: true,
                    )
                  : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final hasTaste = _taste.hasSkyPreference;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FlowHeader(flow: Flows.bestDate),
        const SizedBox(height: 24),
        Text('Your sky taste', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          _saved.preferences.hasSkyPreference
              ? 'Start from your saved taste and tweak it for this search. '
                  'Your saved preferences stay as they are.'
              : 'Tell us what you love and we will find the day that matches. '
                  'This is just for this search.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        PreferenceSliders(
          value: _taste,
          onChanged: (taste) => setState(() => _taste = taste),
        ),
        const Divider(height: 40),
        Text('Where will you be?', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          _saved.home != null
              ? 'Starting from your saved location. Pick another if you are going elsewhere.'
              : 'Choose where you want to watch from.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        LocationPicker(
          value: _location,
          apiClient: _apiClient,
          onChanged: (location) => setState(() => _location = location),
        ),
        const SizedBox(height: 16),
        SegmentedButton<SunEvent>(
          segments: const [
            ButtonSegment(value: SunEvent.sunrise, label: Text('Sunrise')),
            ButtonSegment(value: SunEvent.sunset, label: Text('Sunset')),
          ],
          selected: {_event},
          onSelectionChanged: (selection) => setState(() => _event = selection.first),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _location == null || !hasTaste || _searching ? null : _findDate,
          child: const Text('Find my best day'),
        ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_searchError!, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
