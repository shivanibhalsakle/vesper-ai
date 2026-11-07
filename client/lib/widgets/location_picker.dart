import 'package:flutter/material.dart';

import '../models/coverage.dart';
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
  Coverage? _coverage;

  @override
  void initState() {
    super.initState();
    _apiClient.fetchCoverage().then((coverage) {
      if (mounted) setState(() => _coverage = coverage);
    });
  }

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
    final coverage = _coverage;

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
        if (coverage != null && coverage.regions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _CoverageNote(
            coverage: coverage,
            outside: value != null && coverage.covers(value.lat, value.lon) == false,
          ),
        ],
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
                subtitle: coverage?.covers(result.lat, result.lon) == false
                    ? const Text('Outside our current coverage')
                    : null,
                onTap: () => _select(result),
              ),
          // Required by Geoapify's free-plan terms.
          Text('Powered by Geoapify', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Where Vesper works today. A quiet caption normally; a clearer notice when
/// the chosen place is outside it (the search itself would be refused).
class _CoverageNote extends StatelessWidget {
  final Coverage coverage;
  final bool outside;

  const _CoverageNote({required this.coverage, required this.outside});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (outside) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Vesper doesn't cover this area yet. "
                'It currently works in ${coverage.summary}, with more on the way.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      'Currently available in ${coverage.summary}, with more on the way.',
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
