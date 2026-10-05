import 'package:flutter/material.dart';

import '../models/geocode_result.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

/// Shared "where?" control: shows the chosen place, lets the user switch to
/// their GPS position or search for another place by name or address.
class LocationPicker extends StatefulWidget {
  final PickedLocation? value;
  final ValueChanged<PickedLocation> onChanged;
  final ApiClient? apiClient;
  final LocationService? locationService;

  const LocationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.apiClient,
    this.locationService,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  late final LocationService _locationService = widget.locationService ?? LocationService();
  final _searchController = TextEditingController();

  List<PickedLocation>? _results;
  bool _searching = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      _select(PickedLocation(
        lat: position.latitude,
        lon: position.longitude,
        label: 'Current location',
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not get your location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await _apiClient.geocode(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(PickedLocation location) {
    setState(() {
      _results = null;
      _error = null;
      _searchController.clear();
    });
    widget.onChanged(location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    final results = _results;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(value?.label ?? 'No location chosen'),
            subtitle: value == null
                ? const Text('Search below or use your current location')
                : Text('${value.lat.toStringAsFixed(4)}, ${value.lon.toStringAsFixed(4)}'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Search a place or address',
            border: const OutlineInputBorder(),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search',
                    onPressed: _search,
                  ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: const Text('Use my current location'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (results != null) ...[
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No places found. Try a different spelling or add a city.'),
            )
          else
            for (final result in results)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(result.label),
                onTap: () => _select(result),
              ),
          // Required by Geoapify's free-plan terms.
          Text('Powered by Geoapify', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
