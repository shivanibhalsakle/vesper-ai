import 'package:flutter/material.dart';

import '../models/saved_date.dart';
import '../models/session_request.dart';
import '../services/api_client.dart';
import '../services/push_notification_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'sparkle_burst.dart';

/// "Save this date": stores one place + day so it appears under Saved and
/// the user gets a reminder the day before.
///
/// When the save works, the button shrinks into a brown circle holding a
/// tick, throws a little burst of sparkles, gives a soft haptic tap, and a
/// line underneath says what happens next. Under reduced motion it switches
/// state at once.
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

class _SaveDateButtonState extends State<SaveDateButton> with SingleTickerProviderStateMixin {
  static const _height = 52.0;

  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  bool _saving = false;
  bool _saved = false;
  bool _willRemind = false;
  String? _error;

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

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
      AppHaptics.tap();
      if (!AppMotion.reduced(context)) _burst.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _face(ThemeData theme) {
    if (_saved) {
      return const Icon(Icons.check, key: Key('save-tick'), color: Colors.white, size: 26);
    }
    if (_saving) {
      return SizedBox(
        key: const Key('save-spinner'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }
    // Scaled rather than clipped, so the label shrinks away cleanly if the
    // button is mid-squeeze.
    return FittedBox(
      key: const Key('save-label'),
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_add_outlined, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            'Save this date',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = AppMotion.reduced(context);
    final morph = reduced ? Duration.zero : const Duration(milliseconds: 420);
    final radius = BorderRadius.circular(_saved ? _height / 2 : 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: morph,
                  curve: Curves.easeInOutCubic,
                  width: _saved ? _height : constraints.maxWidth,
                  height: _height,
                  decoration: BoxDecoration(
                    color: _saved ? AppColors.brown : theme.colorScheme.primaryContainer,
                    borderRadius: radius,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: _saving || _saved ? null : _save,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
                          child: _face(theme),
                        ),
                      ),
                    ),
                  ),
                ),
                // The sparkle burst, drawn over a margin around the button.
                AnimatedBuilder(
                  animation: _burst,
                  builder: (context, _) => !_burst.isAnimating
                      ? const SizedBox.shrink()
                      : Positioned(
                          left: -40,
                          right: -40,
                          top: -40,
                          bottom: -40,
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const Key('save-sparkles'),
                              painter: SparklePainter(
                                origin: Offset(constraints.maxWidth / 2 + 40, _height / 2 + 40),
                                t: _burst.value,
                                color: AppColors.sun,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_saved)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduced ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 350),
            builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _willRemind ? "Saved — we'll remind you the day before" : 'Saved',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
