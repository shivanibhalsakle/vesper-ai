import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/profile_photo_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

enum _Stage { loading, error, profile, prompt, preferences, home }

/// Decides what a signed-in user sees first. Someone without a profile is
/// taken through onboarding (profile, then an offer to set preferences);
/// everyone else goes straight to the home screen.
class OnboardingGate extends StatefulWidget {
  final AccountInfo account;
  final ApiClient? apiClient;
  final ProfilePhotos? photos;

  const OnboardingGate({
    super.key,
    this.account = const AccountInfo(),
    this.apiClient,
    this.photos,
  });

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  _Stage _stage = _Stage.loading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.loading;
      _error = null;
    });
    try {
      final profile = await _apiClient.fetchProfile();
      if (!mounted) return;
      setState(() => _stage = profile == null ? _Stage.profile : _Stage.home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = '$e';
      });
    }
  }

  void _go(_Stage stage) => setState(() => _stage = stage);

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Stage.error:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not reach Vesper: $_error', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _check, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        );
      case _Stage.profile:
        return ProfileScreen(
          onboarding: true,
          account: widget.account,
          apiClient: _apiClient,
          photos: widget.photos,
          onSaved: () => _go(_Stage.prompt),
        );
      case _Stage.prompt:
        return _PreferencesPrompt(
          onSetUp: () => _go(_Stage.preferences),
          onSkip: () => _go(_Stage.home),
        );
      case _Stage.preferences:
        return SettingsScreen(
          apiClient: _apiClient,
          onSaved: () => _go(_Stage.home),
          onSkip: () => _go(_Stage.home),
        );
      case _Stage.home:
        return HomeScreen(account: widget.account);
    }
  }
}

class _PreferencesPrompt extends StatelessWidget {
  final VoidCallback onSetUp;
  final VoidCallback onSkip;

  const _PreferencesPrompt({required this.onSetUp, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_twilight, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'What kind of sky do you love?',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us your home spot and taste, and Vesper can pick the best '
                  'days and places for you. It takes a minute.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(onPressed: onSetUp, child: const Text('Set my preferences')),
                const SizedBox(height: 8),
                TextButton(onPressed: onSkip, child: const Text('Skip for now')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
