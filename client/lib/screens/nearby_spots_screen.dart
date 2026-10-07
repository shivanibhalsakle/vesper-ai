import 'package:flutter/material.dart';

import '../models/geocode_result.dart';
import '../models/location_type.dart';
import '../models/nearby_spot.dart';
import '../services/api_client.dart';
import '../theme/flows.dart';
import '../utils/maps.dart';
import '../widgets/flow_header.dart';
import '../widgets/location_picker.dart';
import '../widgets/rise_in.dart';
import '../widgets/sky_loader.dart';

/// Flow 3: pick a place, see good viewing spots around it.
class NearbySpotsScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const NearbySpotsScreen({super.key, this.apiClient});

  @override
  State<NearbySpotsScreen> createState() => _NearbySpotsScreenState();
}

class _NearbySpotsScreenState extends State<NearbySpotsScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  PickedLocation? _location;
  double _radiusKm = 10.0;
  List<LocationType> _placeTypes = const [];

  List<NearbySpot>? _spots;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _applySavedDefaults();
  }

  // Start from the user's Settings (home spot, radius, place types) when
  // they have any; failing to load them just leaves the form blank.
  Future<void> _applySavedDefaults() async {
    try {
      final saved = await _apiClient.fetchPreferences();
      if (!mounted || saved == null) return;
      setState(() {
        _location ??= saved.home;
        _radiusKm = saved.radiusKm.clamp(1.0, 50.0);
        _placeTypes = saved.placeTypes;
      });
    } catch (_) {
      // Settings are a convenience here, not a requirement.
    }
  }

  Future<void> _findSpots() async {
    final location = _location;
    if (location == null) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final spots = await _apiClient.fetchNearbySpots(
        lat: location.lat,
        lon: location.lon,
        radiusKm: _radiusKm,
        placeTypes: _placeTypes,
      );
      if (!mounted) return;
      setState(() => _spots = spots);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _spots = null;
        _error = '$e';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = _spots;

    return Scaffold(
      appBar: AppBar(title: const Text('Viewing spots')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FlowHeader(flow: Flows.spots),
          const SizedBox(height: 24),
          Text('Where are you looking?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          LocationPicker(
            value: _location,
            apiClient: _apiClient,
            onChanged: (location) => setState(() {
              _location = location;
              _spots = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          Text('Search radius: ${_radiusKm.toStringAsFixed(0)} km'),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            label: '${_radiusKm.toStringAsFixed(0)} km',
            onChanged: (value) => setState(() => _radiusKm = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _location == null || _searching ? null : _findSpots,
            child: const Text('Find viewing spots'),
          ),
          const SizedBox(height: 16),
          if (_searching) const SkyLoader(message: 'Finding viewing spots'),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          if (spots != null && spots.isEmpty)
            const Text(
              'No viewing spots found in this radius. Try a wider radius.',
            ),
          if (spots != null && spots.isNotEmpty) ...[
            Text('${spots.length} spots nearby', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < spots.length; i++)
              RiseIn(index: i, child: _SpotTile(spot: spots[i])),
          ],
        ],
      ),
    );
  }
}

class _SpotTile extends StatelessWidget {
  final NearbySpot spot;

  const _SpotTile({required this.spot});

  IconData get _icon => switch (spot.type) {
        LocationType.beach => Icons.beach_access,
        LocationType.park => Icons.park,
        LocationType.waterfront => Icons.water,
        LocationType.promenade => Icons.directions_walk,
        LocationType.elevatedViewpoint => Icons.landscape,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('spot-${spot.id}'),
        leading: Icon(_icon),
        title: Text(spot.name),
        subtitle: Text('${spot.type.label} · ${spot.distanceKm.toStringAsFixed(1)} km away'),
        trailing: Icon(Icons.map_outlined, color: Theme.of(context).colorScheme.primary),
        onTap: () => confirmAndOpenInMaps(
          context,
          name: spot.name,
          lat: spot.lat,
          lon: spot.lon,
        ),
      ),
    );
  }
}
