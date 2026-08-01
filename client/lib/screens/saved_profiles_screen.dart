import 'package:flutter/material.dart';

import '../models/saved_profile.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'saved_profile_form_screen.dart';

class SavedProfilesScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final String Function()? getUserId;

  const SavedProfilesScreen({super.key, this.apiClient, this.getUserId});

  @override
  State<SavedProfilesScreen> createState() => _SavedProfilesScreenState();
}

class _SavedProfilesScreenState extends State<SavedProfilesScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  late final String Function() _getUserId =
      widget.getUserId ?? (() => AuthService().currentUser!.uid);

  late Future<List<SavedProfileRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SavedProfileRecord>> _load() {
    return _apiClient.fetchSavedProfiles(_getUserId());
  }

  Future<void> _addProfile() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SavedProfileFormScreen()),
    );
    if (created == true) {
      setState(() => _future = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved searches')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProfile,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<SavedProfileRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load saved searches: ${snapshot.error}'),
              ),
            );
          }

          final profiles = snapshot.data!;
          if (profiles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No saved searches yet. Tap + to get notified when a great "
                  "sunrise or sunset match comes up near you.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    profile.event.label == 'Sunrise'
                        ? Icons.wb_twilight
                        : Icons.wb_sunny_outlined,
                  ),
                  title: Text('${profile.event.label} within ${profile.radiusKm.toStringAsFixed(0)} km'),
                  subtitle: Text(
                    'Notify at ${(profile.matchThreshold * 100).round()}%+ match · '
                    '${profile.placeTypes.map((t) => t.label).join(', ')}',
                  ),
                  trailing: Icon(
                    profile.notificationEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
