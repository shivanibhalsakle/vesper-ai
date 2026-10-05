import 'package:flutter/material.dart';

import 'coming_soon_screen.dart';
import 'saved_profiles_screen.dart';
import 'session_setup_screen.dart';
import 'settings_screen.dart';

/// Post-sign-in landing page: three big entry points plus the top-bar menu
/// (Profile, Settings, Saved).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vesper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => _open(
              context,
              const ComingSoonScreen(
                title: 'Profile',
                description: 'Your name, photo and account details.',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _open(context, const SettingsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Saved',
            // Interim: saved searches only; saved dates join them later.
            onPressed: () => _open(context, const SavedProfilesScreen()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'What would you like to do?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _HomeOptionCard(
            icon: Icons.event_available,
            title: 'Pick me a pretty sky',
            subtitle: 'Find the best date in the next week for the sky you like.',
            // Interim: the existing date search until the new flow is built.
            onTap: () => _open(context, const SessionSetupScreen()),
          ),
          _HomeOptionCard(
            icon: Icons.wb_twilight,
            title: 'How will the sky look today?',
            subtitle: "See today's forecast for any place.",
            onTap: () => _open(
              context,
              const ComingSoonScreen(
                title: "Today's sky",
                description: "Choose a place and see how today's sky is shaping up.",
              ),
            ),
          ),
          _HomeOptionCard(
            icon: Icons.place_outlined,
            title: 'Find viewing spots near me',
            subtitle: 'Beaches, parks and viewpoints around a location.',
            onTap: () => _open(
              context,
              const ComingSoonScreen(
                title: 'Viewing spots',
                description: 'Enter a location and see good places to watch from.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
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
