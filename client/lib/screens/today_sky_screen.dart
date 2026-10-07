import 'package:flutter/material.dart';

import '../models/geocode_result.dart';
import '../models/location_type.dart';
import '../models/preference_profile.dart';
import '../models/session_request.dart';
import '../models/session_response.dart';
import '../models/sky_forecast.dart';
import '../services/api_client.dart';
import '../utils/format.dart';
import '../utils/maps.dart';
import '../widgets/location_picker.dart';
import '../theme/flows.dart';
import '../widgets/flow_header.dart';
import '../widgets/rise_in.dart';
import '../widgets/save_date_button.dart';
import '../widgets/sky_loader.dart';
import '../widgets/sky_detail_view.dart';

/// Flow 2: how will the sky look today at a place, and where nearby is best
/// to watch it from.
class TodaySkyScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const TodaySkyScreen({super.key, this.apiClient});

  @override
  State<TodaySkyScreen> createState() => _TodaySkyScreenState();
}

class _TodaySkyScreenState extends State<TodaySkyScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  PickedLocation? _location;
  SunEvent _event = SunEvent.sunset;
  double _radiusKm = 10.0;
  List<LocationType> _placeTypes = const [];
  PreferenceProfile _preferences = const PreferenceProfile();

  bool _loadingSky = false;
  SkyForecast? _sky;
  String? _skyError;

  bool _loadingSpots = false;
  List<LocationResult>? _spots;
  String? _spotsError;

  // Bumped on every search so a slow, outdated response can't overwrite the
  // results of a newer one.
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    _applySavedDefaults();
  }

  Future<void> _applySavedDefaults() async {
    try {
      final saved = await _apiClient.fetchPreferences();
      if (!mounted || saved == null) return;
      setState(() {
        _location ??= saved.home;
        _event = saved.event;
        _radiusKm = saved.radiusKm.clamp(1.0, 50.0);
        _placeTypes = saved.placeTypes;
        _preferences = saved.preferences;
      });
    } catch (_) {
      // Settings are a convenience here, not a requirement.
    }
  }

  Future<void> _show() async {
    final location = _location;
    if (location == null) return;

    final searchId = ++_searchId;
    final today = DateTime.now();
    setState(() {
      _loadingSky = true;
      _loadingSpots = true;
      _sky = null;
      _skyError = null;
      _spots = null;
      _spotsError = null;
    });

    // The sky is one fast forecast call, the spots need a place search plus
    // scoring — run them side by side and show each as soon as it lands.
    _loadSky(searchId, location, today);
    _loadSpots(searchId, location, today);
  }

  Future<void> _loadSky(int searchId, PickedLocation location, DateTime today) async {
    try {
      final sky = await _apiClient.fetchSky(SkyRequest(
        lat: location.lat,
        lon: location.lon,
        event: _event,
        date: today,
        preferences: _preferences.hasSkyPreference ? _preferences : null,
      ));
      if (!mounted || searchId != _searchId) return;
      setState(() => _sky = sky);
    } catch (e) {
      if (!mounted || searchId != _searchId) return;
      setState(() => _skyError = '$e');
    } finally {
      if (mounted && searchId == _searchId) setState(() => _loadingSky = false);
    }
  }

  Future<void> _loadSpots(int searchId, PickedLocation location, DateTime today) async {
    try {
      final response = await _apiClient.fetchSession(SessionRequest(
        lat: location.lat,
        lon: location.lon,
        event: _event,
        date: today,
        radiusKm: _radiusKm,
        placeTypes: _placeTypes.isEmpty ? LocationType.values.toList() : _placeTypes,
        preferences: _preferences,
      ));
      if (!mounted || searchId != _searchId) return;
      setState(() => _spots = response.recommendations);
    } catch (e) {
      if (!mounted || searchId != _searchId) return;
      setState(() => _spotsError = '$e');
    } finally {
      if (mounted && searchId == _searchId) setState(() => _loadingSpots = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _loadingSky || _loadingSpots;

    return Scaffold(
      appBar: AppBar(title: const Text("Today's sky")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FlowHeader(flow: Flows.todaySky),
          const SizedBox(height: 24),
          Text('Where are you looking?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          LocationPicker(
            value: _location,
            apiClient: _apiClient,
            onChanged: (location) => setState(() {
              _location = location;
              _searchId++; // discard anything still in flight for the old place
              _loadingSky = _loadingSpots = false;
              _sky = null;
              _skyError = null;
              _spots = null;
              _spotsError = null;
            }),
          ),
          const SizedBox(height: 16),
          SegmentedButton<SunEvent>(
            segments: const [
              ButtonSegment(value: SunEvent.sunrise, label: Text('Sunrise')),
              ButtonSegment(value: SunEvent.sunset, label: Text('Sunset')),
            ],
            selected: {_event},
            onSelectionChanged: (selection) => setState(() {
              _event = selection.first;
              _searchId++;
              _loadingSky = _loadingSpots = false;
              _sky = null;
              _skyError = null;
              _spots = null;
              _spotsError = null;
            }),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _location == null || busy ? null : _show,
            child: Text(busy ? 'Reading the sky…' : "Show today's sky"),
          ),
          const SizedBox(height: 24),
          // Until the sky arrives (the spots can still be loading after it).
          if (_loadingSky && _sky == null)
            const SkyLoader(message: 'Reading the sky'),
          if (_skyError != null)
            Text(_skyError!, style: TextStyle(color: theme.colorScheme.error)),
          if (_sky != null) SkyDetailView(sky: _sky!, preferences: _preferences),
          if (_sky != null && _location != null) ...[
            const SizedBox(height: 16),
            SaveDateButton(
              // Key by search so a fresh search resets the saved state.
              key: ValueKey(_searchId),
              eventDate: DateTime.now(),
              event: _sky!.event,
              lat: _location!.lat,
              lon: _location!.lon,
              label: _location!.label,
              savedScore: _sky!.preferenceMatchScore,
              apiClient: _apiClient,
            ),
          ],
          if (_sky != null || _skyError != null) ...[
            const Divider(height: 40),
            Text('Best spots for this sky', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_loadingSpots) const Text('Finding the best places nearby…'),
            if (_spotsError != null)
              Text(_spotsError!, style: TextStyle(color: theme.colorScheme.error)),
            if (_spots != null && _spots!.isEmpty)
              const Text('No viewing spots found in this radius.'),
            if (_spots != null)
              for (var i = 0; i < _spots!.length; i++)
                RiseIn(
                  index: i,
                  child: _SpotCard(
                    rank: i + 1,
                    spot: _spots![i],
                    showMatch: _preferences.hasSkyPreference,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final int rank;
  final LocationResult spot;
  final bool showMatch;

  const _SpotCard({required this.rank, required this.spot, required this.showMatch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('spot-${spot.locationId}'),
        onTap: () => confirmAndOpenInMaps(
          context,
          name: spot.name,
          lat: spot.lat,
          lon: spot.lon,
        ),
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
                        Text(spot.name, style: theme.textTheme.titleMedium),
                        Text('${spot.type.label} · ${spot.distanceKm.toStringAsFixed(1)} km away'),
                      ],
                    ),
                  ),
                  if (showMatch)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatPercent(spot.preferenceMatchScore),
                            style: theme.textTheme.titleMedium),
                        const Text('match'),
                      ],
                    ),
                ],
              ),
              if (spot.explanation != null) ...[
                const SizedBox(height: 12),
                Text(
                  spot.explanation!,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.map_outlined, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Open in Google Maps',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
