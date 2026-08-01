import 'package:flutter/material.dart';

import '../models/location_type.dart';
import '../models/session_request.dart';
import '../services/location_service.dart';
import 'preference_screen.dart';
import 'saved_profiles_screen.dart';


class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {

  // Prefilled with Brooklyn Bridge Park (our test location throughout the
  // backend build) as a fallback if geolocation isn't available/permitted —
  // see _useCurrentLocation for the real location picker.
  final _latController = TextEditingController(text: '40.7003');
  final _lonController = TextEditingController(text: '-73.9967');

  SunEvent _event = SunEvent.sunset;
  DateTime _date = DateTime.now();
  double _radiusKm = 5.0;
  final Set<LocationType> _placeTypes = {};
    bool _isDateRange = false;
  DateTimeRange? _dateRange;
  bool _locating = false;

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

    Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await LocationService().getCurrentPosition();
      _latController.text = position.latitude.toStringAsFixed(4);
      _lonController.text = position.longitude.toStringAsFixed(4);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get your location: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _goToPreferences() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid latitude and longitude.')),
      );
      return;
    }
    if (_isDateRange && _dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pick a date range for your trip.")),
      );
      return;
    }

    final types = _placeTypes.isEmpty ? LocationType.values.toList() : _placeTypes.toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreferenceScreen(
          lat: lat,
          lon: lon,
          event: _event,
          date: _date,
          dateRange: _isDateRange ? _dateRange : null,
          radiusKm: _radiusKm,
          placeTypes: types,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vesper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Saved searches',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedProfilesScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where and when?', style: Theme.of(context).textTheme.titleLarge),
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
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Single date')),
                ButtonSegment(value: true, label: Text('Date range (trip)')),
              ],
              selected: {_isDateRange},
              onSelectionChanged: (selection) => setState(() => _isDateRange = selection.first),
            ),
            const SizedBox(height: 8),
            if (_isDateRange)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Trip dates'),
                subtitle: Text(
                  _dateRange == null
                      ? "Tap to choose your trip's date range"
                      : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}',
                ),
                trailing: const Icon(Icons.date_range),
                onTap: _pickDateRange,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(_formatDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            const SizedBox(height: 16),

            
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _goToPreferences,
                child: const Text('Next: sky preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
