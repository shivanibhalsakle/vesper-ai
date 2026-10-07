import 'package:flutter/material.dart';

import '../models/saved_date.dart';
import '../models/session_request.dart';
import '../services/api_client.dart';
import '../services/push_notification_service.dart';

/// "Save this date": stores one place + day so it appears under Saved and
/// the user gets a reminder the day before.
class SaveDateButton extends StatefulWidget {
  final DateTime eventDate;
  final SunEvent event;
  final double lat;
  final double lon;
  final String label;
  final double? savedScore;
  final ApiClient? apiClient;
  final Future<String?> Function()? getFcmToken;

  const SaveDateButton({
    super.key,
    required this.eventDate,
    required this.event,
    required this.lat,
    required this.lon,
    required this.label,
    this.savedScore,
    this.apiClient,
    this.getFcmToken,
  });

  @override
  State<SaveDateButton> createState() => _SaveDateButtonState();
}

class _SaveDateButtonState extends State<SaveDateButton> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  bool _saving = false;
  bool _saved = false;
  bool _willRemind = false;
  String? _error;

  // Reminders need a device token. Not having one (permission denied, no
  // Firebase on this platform) shouldn't stop the date being saved.
  Future<String?> _token() async {
    try {
      final getToken = widget.getFcmToken ?? (() => PushNotificationService().getToken());
      return await getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await _token();
      await _apiClient.createSavedDate(SavedDateRequest(
        eventDate: widget.eventDate,
        event: widget.event,
        lat: widget.lat,
        lon: widget.lon,
        label: widget.label,
        savedScore: widget.savedScore,
        fcmToken: token,
      ));
      if (!mounted) return;
      setState(() {
        _saved = true;
        _willRemind = token != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          // The quieter sibling of the main button: blush fill, brown text
          // (tonal buttons would otherwise inherit the solid brown).
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            disabledBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
            disabledForegroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: _saving || _saved ? null : _save,
          icon: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
          label: Text(
            !_saved
                ? 'Save this date'
                : _willRemind
                    ? "Saved — we'll remind you the day before"
                    : 'Saved',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}
