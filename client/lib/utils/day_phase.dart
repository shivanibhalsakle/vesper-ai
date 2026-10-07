import 'package:flutter/material.dart';

/// The mood of the sky for a given local hour. It tints the home header and
/// picks the greeting, so the app feels like it knows what time it is.
enum DayPhase {
  dawn,
  day,
  dusk,
  night;

  static DayPhase at(DateTime local) {
    final hour = local.hour;
    if (hour >= 5 && hour < 10) return DayPhase.dawn;
    if (hour >= 10 && hour < 16) return DayPhase.day;
    if (hour >= 16 && hour < 21) return DayPhase.dusk;
    return DayPhase.night;
  }

  /// Top, middle and bottom colours of the sky gradient.
  List<Color> get sky => switch (this) {
        DayPhase.dawn => const [Color(0xFFCFE0F5), Color(0xFFF6C7B6), Color(0xFFFCEBDD)],
        DayPhase.day => const [Color(0xFFFDF1D6), Color(0xFFFCEBDD), Color(0xFFFFF8F3)],
        DayPhase.dusk => const [Color(0xFFF3C9D2), Color(0xFFF8D7BE), Color(0xFFFCEBDD)],
        DayPhase.night => const [Color(0xFFCFC8E8), Color(0xFFE7C9DC), Color(0xFFFBF1EC)],
      };

  /// The sun (or the moon, at night).
  Color get orb => switch (this) {
        DayPhase.dawn => const Color(0xFFF2A65A),
        DayPhase.day => const Color(0xFFFFD27A),
        DayPhase.dusk => const Color(0xFFE5736B),
        DayPhase.night => const Color(0xFFF4EEE0),
      };
}

/// "Good morning" / "Good afternoon" / "Good evening" for a local time.
String greetingFor(DateTime local) {
  final hour = local.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}
