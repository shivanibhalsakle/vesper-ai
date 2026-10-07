import 'dart:math' as math;

/// Sunrise and sunset for one place on one calendar day, as UTC instants.
class SunTimes {
  final DateTime sunrise;
  final DateTime sunset;

  const SunTimes({required this.sunrise, required this.sunset});

  /// How far through the daylight [now] is: 0 at sunrise, 1 at sunset.
  /// Clamped, so night reads as 0 (before dawn) or 1 (after dusk).
  double progressAt(DateTime now) {
    final total = sunset.difference(sunrise).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(sunrise).inSeconds / total).clamp(0.0, 1.0);
  }
}

/// Sunrise and sunset at [lat], [lon] on the calendar day of [date] (only its
/// year, month and day are used, as the day at that place). Returns null in
/// polar day or polar night, when the sun doesn't rise or set.
///
/// This is the NOAA solar-position method, accurate to about a minute away
/// from the poles - plenty for a countdown, and it needs no network. Showing
/// the clock time still needs the place's own timezone, so callers that don't
/// know it should show a countdown instead.
SunTimes? sunTimesFor({required double lat, required double lon, required DateTime date}) {
  final base = DateTime.utc(date.year, date.month, date.day);
  final dayOfYear = base.difference(DateTime.utc(date.year, 1, 1)).inDays + 1;

  final rise = _eventMinutes(lat, lon, dayOfYear, rising: true);
  final set = _eventMinutes(lat, lon, dayOfYear, rising: false);
  if (rise == null || set == null) return null;

  DateTime at(double minutes) =>
      base.add(Duration(seconds: (minutes * 60).round()));
  return SunTimes(sunrise: at(rise), sunset: at(set));
}

double _rad(double degrees) => degrees * math.pi / 180;
double _deg(double radians) => radians * 180 / math.pi;

/// Minutes after 00:00 UTC of the day (can be negative or above 1440 for
/// places far from Greenwich) at which the sun crosses the horizon.
double? _eventMinutes(double lat, double lon, int dayOfYear, {required bool rising}) {
  var minutes = 720 - 4 * lon; // first guess: solar noon
  // Two passes: the sun's declination and the equation of time are taken
  // at the moment of the event, not at noon.
  for (var pass = 0; pass < 3; pass++) {
    final gamma = 2 * math.pi / 365 * (dayOfYear - 1 + (minutes / 60 - 12) / 24);
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final latRad = _rad(lat);
    final cosHa = math.cos(_rad(90.833)) / (math.cos(latRad) * math.cos(decl)) -
        math.tan(latRad) * math.tan(decl);
    if (cosHa < -1 || cosHa > 1) return null; // the sun never crosses the horizon
    final hourAngle = _deg(math.acos(cosHa));

    minutes = 720 - 4 * (lon + (rising ? hourAngle : -hourAngle)) - eqTime;
  }
  return minutes;
}

/// Where the sun is right now at a place, and what happens next.
class SunStatus {
  /// True between sunrise and sunset.
  final bool isDay;

  /// Through the day: 0 at sunrise, 1 at sunset. At night the sun rests on a
  /// horizon: the sunset one (1) for the first half of the night, the sunrise
  /// one (0) for the second half, so it is back where it will rise by dawn.
  final double progress;

  /// Whether the next event is a sunset (otherwise a sunrise).
  final bool nextIsSunset;

  final Duration untilNext;

  const SunStatus({
    required this.isDay,
    required this.progress,
    required this.nextIsSunset,
    required this.untilNext,
  });
}

/// The sun's state at [now] for a place, found from the sunrises and sunsets
/// of the days around it. Looking across several days means the answer
/// doesn't depend on which calendar day (or timezone) the caller is in.
/// Null in polar day or night.
SunStatus? sunStatusAt({required double lat, required double lon, required DateTime now}) {
  final utc = now.toUtc();
  final events = <(DateTime, bool)>[]; // (instant, isSunrise)
  for (var offset = -1; offset <= 1; offset++) {
    final times = sunTimesFor(lat: lat, lon: lon, date: utc.add(Duration(days: offset)));
    if (times == null) return null;
    events
      ..add((times.sunrise, true))
      ..add((times.sunset, false));
  }
  events.sort((a, b) => a.$1.compareTo(b.$1));

  final nextIndex = events.indexWhere((e) => e.$1.isAfter(utc));
  if (nextIndex <= 0) return null;
  final last = events[nextIndex - 1];
  final next = events[nextIndex];

  final isDay = last.$2; // last event was a sunrise
  final elapsed = utc.difference(last.$1).inSeconds / next.$1.difference(last.$1).inSeconds;
  final progress = isDay ? elapsed : (elapsed < 0.5 ? 1.0 : 0.0);
  return SunStatus(
    isDay: isDay,
    progress: progress.clamp(0.0, 1.0),
    nextIsSunset: !next.$2,
    untilNext: next.$1.difference(utc),
  );
}
