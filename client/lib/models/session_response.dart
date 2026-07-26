import 'location_type.dart';

class ColorProbabilities {
  final double pink;
  final double purple;
  final double orange;
  final double red;
  final double golden;

  const ColorProbabilities({
    required this.pink,
    required this.purple,
    required this.orange,
    required this.red,
    required this.golden,
  });

  factory ColorProbabilities.fromJson(Map<String, dynamic> json) => ColorProbabilities(
        pink: (json['pink'] as num).toDouble(),
        purple: (json['purple'] as num).toDouble(),
        orange: (json['orange'] as num).toDouble(),
        red: (json['red'] as num).toDouble(),
        golden: (json['golden'] as num).toDouble(),
      );
}

class LocationResult {
  final String locationId;
  final String name;
  final LocationType type;
  final double distanceKm;

  // Kept as raw ISO strings (not DateTime) because the backend returns each
  // location's true local wall-clock time with an explicit UTC offset (e.g.
  // "-04:00" for NYC). Dart's DateTime.parse collapses that offset into UTC,
  // which would silently show the wrong clock time unless the viewing
  // device happens to share the same offset. See lib/utils/format.dart.
  final String eventTime;
  final int recommendedArrivalOffsetMinutes;
  final String bestViewingWindowStart;
  final String bestViewingWindowEnd;

  final double visibilityLikelihood;
  final String cloudCoverSummary;
  final ColorProbabilities colorProbabilities;
  final String? rainOrUnsafeAlert;
  final double preferenceMatchScore;
  final String? explanation;

  const LocationResult({
    required this.locationId,
    required this.name,
    required this.type,
    required this.distanceKm,
    required this.eventTime,
    required this.recommendedArrivalOffsetMinutes,
    required this.bestViewingWindowStart,
    required this.bestViewingWindowEnd,
    required this.visibilityLikelihood,
    required this.cloudCoverSummary,
    required this.colorProbabilities,
    required this.rainOrUnsafeAlert,
    required this.preferenceMatchScore,
    required this.explanation,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) => LocationResult(
        locationId: json['location_id'] as String,
        name: json['name'] as String,
        type: LocationType.fromApiValue(json['type'] as String),
        distanceKm: (json['distance_km'] as num).toDouble(),
        eventTime: json['event_time'] as String,
        recommendedArrivalOffsetMinutes: json['recommended_arrival_offset_minutes'] as int,
        bestViewingWindowStart: json['best_viewing_window_start'] as String,
        bestViewingWindowEnd: json['best_viewing_window_end'] as String,
        visibilityLikelihood: (json['visibility_likelihood'] as num).toDouble(),
        cloudCoverSummary: json['cloud_cover_summary'] as String,
        colorProbabilities:
            ColorProbabilities.fromJson(json['color_probabilities'] as Map<String, dynamic>),
        rainOrUnsafeAlert: json['rain_or_unsafe_alert'] as String?,
        preferenceMatchScore: (json['preference_match_score'] as num).toDouble(),
        explanation: json['explanation'] as String?,
      );
}

class SessionResponse {
  final List<LocationResult> recommendations;

  const SessionResponse({required this.recommendations});

  factory SessionResponse.fromJson(Map<String, dynamic> json) => SessionResponse(
        recommendations: (json['recommendations'] as List)
            .map((item) => LocationResult.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
