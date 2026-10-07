import 'package:flutter/material.dart';

import '../models/preference_profile.dart';
import '../models/saved_date.dart';
import '../models/session_request.dart';
import '../models/sky_forecast.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/gradient_icon_disc.dart';
import '../widgets/saved_dates_calendar.dart';
import '../widgets/sky_detail_view.dart';
import 'saved_profiles_screen.dart';

// Open-Meteo's forecast horizon: beyond this there is nothing to show yet.
const _forecastHorizonDays = 15;

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Everything the user has saved: dates (with a calendar and a live forecast
/// for each), plus saved searches. Photos and AI previews come later.
class SavedScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final DateTime? today; // injectable for tests

  const SavedScreen({super.key, this.apiClient, this.today});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  bool _loading = true;
  String? _error;
  List<SavedDate> _dates = const [];
  PreferenceProfile _preferences = const PreferenceProfile();
  DateTime? _selectedDay;

  DateTime get _today => _dayOnly(widget.today ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dates = await _apiClient.fetchSavedDates();
      // Preferences only add the "what you wanted" markers; the page works
      // without them.
      PreferenceProfile preferences = const PreferenceProfile();
      try {
        preferences = (await _apiClient.fetchPreferences())?.preferences ?? preferences;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _dates = dates;
        _preferences = preferences;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _setNotifications(SavedDate date, bool enabled) async {
    try {
      final updated = await _apiClient.setSavedDateNotifications(date.id, enabled: enabled);
      if (!mounted) return;
      setState(() => _dates = [for (final d in _dates) d.id == date.id ? updated : d]);
    } catch (e) {
      if (!mounted) return;
      _toast('Could not update reminder: $e');
    }
  }

  Future<void> _remove(SavedDate date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this saved date?'),
        content: Text('${formatLongDate(date.eventDate)} at ${date.label}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _apiClient.deleteSavedDate(date.id);
      if (!mounted) return;
      setState(() => _dates = _dates.where((d) => d.id != date.id).toList());
    } catch (e) {
      if (!mounted) return;
      _toast('Could not remove it: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load your saved items: $_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedDay;
    final visible = selected == null
        ? _dates
        : _dates.where((d) => _dayOnly(d.eventDate) == selected).toList();
    final upcoming = visible.where((d) => !_dayOnly(d.eventDate).isBefore(_today)).toList();
    final past = visible.where((d) => _dayOnly(d.eventDate).isBefore(_today)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SavedDatesCalendar(
          today: _today,
          markedDates: {for (final d in _dates) _dayOnly(d.eventDate)},
          dotColors: _dotColors(),
          selected: selected,
          onSelected: (day) => setState(() => _selectedDay = day),
        ),
        if (selected != null)
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text('Showing ${formatLongDate(selected)}'),
              onDeleted: () => setState(() => _selectedDay = null),
              deleteButtonTooltipMessage: 'Show all',
            ),
          ),
        const SizedBox(height: 16),
        if (_dates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No saved dates yet. When you find a sky you like, tap '
              '"Save this date" and it will show up here.',
            ),
          )
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nothing saved for this day.'),
          ),
        if (upcoming.isNotEmpty) ...[
          Text('Upcoming', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final date in upcoming) _tile(date, isPast: false),
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Past', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final date in past) _tile(date, isPast: true),
        ],
        const Divider(height: 40),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Saved searches'),
          subtitle: const Text('Areas we watch for you'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SavedProfilesScreen()),
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: false,
          leading: Icon(Icons.photo_library_outlined),
          title: Text('Photos & sky previews'),
          subtitle: Text('Coming soon'),
        ),
      ],
    );
  }

  // Each saved day's dot takes the spectrum colour of its (best) score, so
  // the calendar reads as a little heat map of good skies.
  Map<DateTime, Color> _dotColors() {
    final best = <DateTime, double>{};
    for (final d in _dates) {
      final score = d.savedScore;
      if (score == null) continue;
      final day = _dayOnly(d.eventDate);
      if (score > (best[day] ?? -1)) best[day] = score;
    }
    return {for (final e in best.entries) e.key: AppColors.spectrumAt(e.value)};
  }

  Widget _tile(SavedDate date, {required bool isPast}) {
    return _SavedDateTile(
      key: ValueKey(date.id),
      date: date,
      isPast: isPast,
      today: _today,
      preferences: _preferences,
      apiClient: _apiClient,
      onNotificationsChanged: (enabled) => _setNotifications(date, enabled),
      onRemove: () => _remove(date),
    );
  }
}

class _SavedDateTile extends StatelessWidget {
  final SavedDate date;
  final bool isPast;
  final DateTime today;
  final PreferenceProfile preferences;
  final ApiClient apiClient;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onRemove;

  const _SavedDateTile({
    super.key,
    required this.date,
    required this.isPast,
    required this.today,
    required this.preferences,
    required this.apiClient,
    required this.onNotificationsChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final saved = date.savedScore;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: GradientIconDisc(
          icon: date.event == SunEvent.sunrise ? Icons.wb_twilight : Icons.wb_sunny_outlined,
          // Sunrises sit at the dawn end of the spectrum, sunsets at dusk's.
          from: date.event == SunEvent.sunrise ? AppColors.spectrum[0] : AppColors.spectrum[2],
          to: date.event == SunEvent.sunrise ? AppColors.spectrum[2] : AppColors.spectrum[4],
          size: 40,
        ),
        title: Text(formatLongDate(date.eventDate)),
        subtitle: Text(
          '${date.event.label} · ${date.label}'
          '${saved != null ? ' · ${formatPercent(saved)} when saved' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SavedDateDetail(
            date: date,
            isPast: isPast,
            today: today,
            preferences: preferences,
            apiClient: apiClient,
          ),
          const SizedBox(height: 8),
          if (!isPast)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me the day before'),
              value: date.notificationEnabled,
              onChanged: onNotificationsChanged,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The forecast for a saved date, fetched when the tile is first opened.
class _SavedDateDetail extends StatefulWidget {
  final SavedDate date;
  final bool isPast;
  final DateTime today;
  final PreferenceProfile preferences;
  final ApiClient apiClient;

  const _SavedDateDetail({
    required this.date,
    required this.isPast,
    required this.today,
    required this.preferences,
    required this.apiClient,
  });

  @override
  State<_SavedDateDetail> createState() => _SavedDateDetailState();
}

class _SavedDateDetailState extends State<_SavedDateDetail> {
  Future<SkyForecast>? _sky;

  int get _daysAhead => _dayOnly(widget.date.eventDate).difference(widget.today).inDays;

  @override
  void initState() {
    super.initState();
    if (!widget.isPast && _daysAhead <= _forecastHorizonDays) {
      _sky = widget.apiClient.fetchSky(SkyRequest(
        lat: widget.date.lat,
        lon: widget.date.lon,
        event: widget.date.event,
        date: widget.date.eventDate,
        preferences: widget.preferences.hasSkyPreference ? widget.preferences : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPast) return const Text('This date has passed.');
    final sky = _sky;
    if (sky == null) {
      return const Text(
        'Forecasts open up about two weeks before the day. Check back closer to the date.',
      );
    }
    return FutureBuilder<SkyForecast>(
      future: sky,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text(
            '${snapshot.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        return SkyDetailView(sky: snapshot.data!, preferences: widget.preferences);
      },
    );
  }
}
