import 'package:flutter/material.dart';

import '../models/simulation.dart';
import '../screens/sky_preview_screen.dart';
import '../services/api_client.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// "Preview this sky": nothing is generated until the person taps it and then
/// confirms, with their remaining allowance for the day in plain view.
class PreviewSkyButton extends StatefulWidget {
  final SimulationRequest request;
  final ApiClient? apiClient;

  /// A quieter text button, for use inside a card.
  final bool compact;

  const PreviewSkyButton({
    super.key,
    required this.request,
    this.apiClient,
    this.compact = false,
  });

  @override
  State<PreviewSkyButton> createState() => _PreviewSkyButtonState();
}

class _PreviewSkyButtonState extends State<PreviewSkyButton> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  bool _checking = false;

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _checking = true);

    final RemainingPreviews remaining;
    try {
      remaining = await _apiClient.fetchRemainingPreviews();
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not check your previews: $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);

    final go = await showPreviewConfirmDialog(
      context,
      remaining: remaining.remainingToday,
      limit: remaining.dailyLimit,
    );
    if (!go || !mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => SkyPreviewScreen(request: widget.request, apiClient: _apiClient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(_checking ? 'One moment…' : 'Preview this sky');
    const icon = Icon(Icons.auto_awesome, size: 20);
    final onPressed = _checking ? null : _start;

    return widget.compact
        ? TextButton.icon(
            key: const Key('preview-sky'), onPressed: onPressed, icon: icon, label: label)
        : OutlinedButton.icon(
            key: const Key('preview-sky'), onPressed: onPressed, icon: icon, label: label);
  }
}

/// Asks "make this preview?" with [remaining] of [limit] suns lit. Returns
/// true only when the person chose to generate.
Future<bool> showPreviewConfirmDialog(
  BuildContext context, {
  required int remaining,
  required int limit,
}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (_) => _PreviewConfirmDialog(remaining: remaining, limit: limit),
  );
  return go == true;
}

class _PreviewConfirmDialog extends StatefulWidget {
  final int remaining;
  final int limit;

  const _PreviewConfirmDialog({required this.remaining, required this.limit});

  @override
  State<_PreviewConfirmDialog> createState() => _PreviewConfirmDialogState();
}

class _PreviewConfirmDialogState extends State<_PreviewConfirmDialog>
    with SingleTickerProviderStateMixin {
  // The next sun lifts off when "Generate" is tapped, then the dialog closes.
  late final AnimationController _lift =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  bool _confirming = false;

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_confirming) return;
    AppHaptics.tap();
    if (AppMotion.reduced(context)) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _confirming = true);
    await _lift.forward();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = widget.limit - widget.remaining;
    final hasAny = widget.remaining > 0;

    return AlertDialog(
      key: const Key('preview-confirm-dialog'),
      title: Text(hasAny ? 'Preview this sky?' : 'No previews left today'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.limit; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _SunDot(
                      key: Key('preview-sun-$i'),
                      state: i < used
                          ? _SunState.used
                          : (i == used ? _SunState.next : _SunState.available),
                      lift: _lift,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasAny
                ? 'You have ${widget.remaining} of ${widget.limit} previews left today. '
                    'This one will use 1.'
                : "You've used all ${widget.limit} previews for today. Skies you've already "
                    'previewed still open from Saved → Sky previews.',
            style: theme.textTheme.bodyMedium,
          ),
          if (hasAny) ...[
            const SizedBox(height: 8),
            Text(
              'A sky you have already previewed opens again for free.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: hasAny
          ? [
              TextButton(
                key: const Key('preview-cancel'),
                onPressed: _confirming ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('preview-generate'),
                onPressed: _confirming ? null : _generate,
                child: const Text('Generate'),
              ),
            ]
          : [
              FilledButton(
                key: const Key('preview-ok'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('OK'),
              ),
            ],
    );
  }
}

enum _SunState { used, next, available }

class _SunDot extends StatelessWidget {
  final _SunState state;
  final Animation<double> lift;

  const _SunDot({super.key, required this.state, required this.lift});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _SunState.used:
        return const Icon(Icons.wb_sunny_outlined, size: 30, color: AppColors.outline);
      case _SunState.available:
        return const Icon(Icons.wb_sunny_rounded, size: 30, color: AppColors.sun);
      case _SunState.next:
        // The one this preview will use: ringed, and it floats up and fades
        // when the person confirms.
        return AnimatedBuilder(
          animation: lift,
          builder: (context, child) {
            final t = Curves.easeOut.transform(lift.value);
            return Transform.translate(
              offset: Offset(0, -22 * t),
              child: Opacity(
                opacity: 1 - 0.85 * t,
                child: Transform.scale(scale: 1 + 0.7 * t, child: child),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brown, width: 2),
            ),
            child: const Icon(Icons.wb_sunny_rounded, size: 26, color: AppColors.sun),
          ),
        );
    }
  }
}
