import 'package:flutter/services.dart';

/// Soft taps for the moments that deserve one: a date saved, a star chosen,
/// a calendar day picked, the sun poked. Light by design, never buzzy.
///
/// Haptics are best-effort: a device without a vibration motor, a web
/// browser, or a platform that refuses all just means no tap; the app never
/// notices. Android and iOS also let the user switch them off system-wide.
class AppHaptics {
  const AppHaptics._();

  /// A gentle bump: something happened.
  static void tap() => _run(HapticFeedback.lightImpact);

  /// A crisp tick: a choice was made.
  static void select() => _run(HapticFeedback.selectionClick);

  static void _run(Future<void> Function() haptic) {
    try {
      haptic().catchError((Object _) {});
    } catch (_) {
      // Synchronous failure (no binding yet): nothing to do.
    }
  }
}
