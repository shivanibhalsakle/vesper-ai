import 'package:flutter/material.dart';

import '../models/geocode_result.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/flows.dart';
import '../utils/day_phase.dart';
import '../utils/sun_times.dart';
import '../widgets/gradient_icon_disc.dart';
import '../widgets/rise_in.dart';
import '../widgets/sky_header.dart';
import '../widgets/sun_arc.dart';
import 'best_date_screen.dart';
import 'nearby_spots_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'today_sky_screen.dart';

/// Post-sign-in landing page: a sky that follows the time of day, a greeting,
/// tonight's sun, and three big entry points. The menu (Profile, Settings,
/// Saved) sits on the sky.
class HomeScreen extends StatefulWidget {
  final AccountInfo account;
  final ApiClient? apiClient;

  /// Injectable clock, for tests.
  final DateTime? now;

  const HomeScreen({super.key, this.account = const AccountInfo(), this.apiClient, this.now});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  String? _name;
  PickedLocation? _home;

  @override
  void initState() {
    super.initState();
    _loadPersonalTouches();
  }

  // The name and home spot only personalise the page, so failing to fetch
  // them just leaves it generic.
  Future<void> _loadPersonalTouches() async {
    UserProfile? profile;
    UserPreferences? preferences;
    await Future.wait([
      () async {
        try {
          profile = await _apiClient.fetchProfile();
        } catch (_) {}
      }(),
      () async {
        try {
          preferences = await _apiClient.fetchPreferences();
        } catch (_) {}
      }(),
    ]);
    if (!mounted) return;
    setState(() {
      _name = profile?.displayName;
      _home = preferences?.home;
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String? get _firstName {
    final name = _name ?? widget.account.displayName;
    final first = name?.trim().split(RegExp(r'\s+')).first;
    return first == null || first.isEmpty ? null : first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = widget.now ?? DateTime.now();
    final phase = DayPhase.at(now);
    final greeting = greetingFor(now);
    final first = _firstName;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SkyHeader(
            phase: phase,
            topInset: topInset,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 8, 8, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    Text(
                      'Vesper',
                      style: theme.textTheme.displaySmall?.copyWith(fontSize: 34),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.person_outline),
                      tooltip: 'Profile',
                      onPressed: () => _open(ProfileScreen(account: widget.account)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      onPressed: () => _open(const SettingsScreen()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_outline),
                      tooltip: 'Saved',
                      onPressed: () => _open(const SavedScreen()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiseIn(
                  index: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first == null ? greeting : '$greeting, $first',
                        style: theme.textTheme.displaySmall?.copyWith(fontSize: 30),
                      ),
                      const SizedBox(height: 4),
                      Text('What would you like to do?', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                RiseIn(
                  index: 1,
                  child: _HomeOptionCard(
                    flow: Flows.bestDate,
                    onTap: () => _open(const BestDateScreen()),
                  ),
                ),
                RiseIn(
                  index: 2,
                  child: _HomeOptionCard(
                    flow: Flows.todaySky,
                    onTap: () => _open(const TodaySkyScreen()),
                  ),
                ),
                RiseIn(
                  index: 3,
                  child: _HomeOptionCard(
                    flow: Flows.spots,
                    onTap: () => _open(const NearbySpotsScreen()),
                  ),
                ),
                if (_home != null)
                  RiseIn(index: 4, child: _SunCard(home: _home!, now: now)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeOptionCard extends StatelessWidget {
  final FlowStyle flow;
  final VoidCallback onTap;

  const _HomeOptionCard({required this.flow, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // The disc glides into the header of the screen this opens.
              GradientIconDisc(
                icon: flow.icon,
                from: flow.from,
                to: flow.to,
                size: 48,
                heroTag: flow.heroTag,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flow.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(flow.subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the sun is over the user's home spot right now, and how long until
/// it sets (or, after dark, rises). Worked out on the phone, so it appears
/// instantly and needs no network.
class _SunCard extends StatelessWidget {
  final PickedLocation home;
  final DateTime now;

  const _SunCard({required this.home, required this.now});

  static String _duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final status = sunStatusAt(lat: home.lat, lon: home.lon, now: now);
    if (status == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final label = status.nextIsSunset
        ? '${_duration(status.untilNext)} until sunset'
        : 'Sunrise in ${_duration(status.untilNext)}';

    return Card(
      key: const Key('sun-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            SunArc(
              progress: status.progress,
              dotColor: status.isDay ? AppColors.sun : const Color(0xFFD9D2E9),
            ),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.titleMedium),
            Text(home.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
