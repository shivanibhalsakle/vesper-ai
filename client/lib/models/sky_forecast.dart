import 'preference_profile.dart';
import 'session_request.dart';
import 'session_response.dart';

/// How strongly the forecast delivers each sky-condition tag (0-1). Mirrors
/// the five sky sliders in [PreferenceProfile] so the two can be compared.
class SkyProfile {
  final double clearSky;
  final double dramaticClouds;
  final double pinkPurple;
  final double goldenOrange;
  final double redSky;

  const SkyProfile({
    required this.clearSky,
    required this.dramaticClouds,
    required this.pinkPurple,
    required this.goldenOrange,
    required this.redSky,
  });

  factory SkyProfile.fromJson(Map<String, dynamic> json) => SkyProfile(
        clearSky: (json['clear_sky'] as num).toDouble(),
        dramaticClouds: (json['dramatic_clouds'] as num).toDouble(),
        pinkPurple: (json['pink_purple'] as num).toDouble(),
        goldenOrange: (json['golden_orange'] as num).toDouble(),
        redSky: (json['red_sky'] as num).toDouble(),
      );
}

enum Confidence {
  high,
  medium,
  low;

  String get label => switch (this) {
        Confidence.high => 'High confidence',
        Confidence.medium => 'Medium confidence',
        Confidence.low => 'Low confidence',
      };
}

class SkyRequest {
  final double lat;
  final double lon;
  final SunEvent event;
  final DateTime date;
  final PreferenceProfile? preferences;

  const SkyRequest({
    required this.lat,
    required this.lon,
    required this.event,
    required this.date,
    this.preferences,
  });

  Map<String, dynamic> toJson() {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return {
      'lat': lat,
      'lon': lon,
      'event': event.apiValue,
      'date': '${date.year}-$month-$day',
      if (preferences != null) 'preferences': preferences!.toJson(),
      // The backend resolves the place's own timezone from the coordinates.
      'tz_name': 'auto',
    };
  }
}

class SkyForecast {
  final SunEvent event;

  // Raw ISO strings, as on LocationResult: the backend sends local wall-clock
  // time with an explicit offset, which DateTime.parse would collapse to UTC.
  final String eventTime;
  final bool eventPassed;
  final int recommendedArrivalOffsetMinutes;
  final String bestViewingWindowStart;
  final String bestViewingWindowEnd;

  final double visibilityLikelihood;
  final String cloudCoverSummary;
  final ColorProbabilities colorProbabilities;
  final SkyProfile skyProfile;
  final String? rainOrUnsafeAlert;

  /// Null when no sky preferences were sent to match against.
  final double? preferenceMatchScore;

  final int leadDays;
  final Confidence confidence;

  const SkyForecast({
    required this.event,
    required this.eventTime,
    required this.eventPassed,
    required this.recommendedArrivalOffsetMinutes,
    required this.bestViewingWindowStart,
    required this.bestViewingWindowEnd,
    required this.visibilityLikelihood,
    required this.cloudCoverSummary,
    required this.colorProbabilities,
    required this.skyProfile,
    required this.rainOrUnsafeAlert,
    required this.preferenceMatchScore,
    required this.leadDays,
    required this.confidence,
  });

  factory SkyForecast.fromJson(Map<String, dynamic> json) => SkyForecast(
        event: SunEvent.fromApiValue(json['event'] as String),
        eventTime: json['event_time'] as String,
        eventPassed: json['event_passed'] as bool,
        recommendedArrivalOffsetMinutes: json['recommended_arrival_offset_minutes'] as int,
        bestViewingWindowStart: json['best_viewing_window_start'] as String,
        bestViewingWindowEnd: json['best_viewing_window_end'] as String,
        visibilityLikelihood: (json['visibility_likelihood'] as num).toDouble(),
        cloudCoverSummary: json['cloud_cover_summary'] as String,
        colorProbabilities:
            ColorProbabilities.fromJson(json['color_probabilities'] as Map<String, dynamic>),
        skyProfile: SkyProfile.fromJson(json['sky_profile'] as Map<String, dynamic>),
        rainOrUnsafeAlert: json['rain_or_unsafe_alert'] as String?,
        preferenceMatchScore: (json['preference_match_score'] as num?)?.toDouble(),
        leadDays: json['lead_days'] as int,
        confidence: Confidence.values.byName(json['confidence'] as String),
      );
}
