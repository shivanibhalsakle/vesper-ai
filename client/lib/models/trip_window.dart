import 'location_type.dart';
import 'preference_profile.dart';
import 'session_request.dart';
import 'session_response.dart';

class TripWindowRequest {
  final double lat;
  final double lon;
  final SunEvent event;
  final DateTime startDate;
  final DateTime endDate;
  final double radiusKm;
  final List<LocationType> placeTypes;
  final PreferenceProfile preferences;
  final String tzName;

  const TripWindowRequest({
    required this.lat,
    required this.lon,
    required this.event,
    required this.startDate,
    required this.endDate,
    required this.radiusKm,
    required this.placeTypes,
    required this.preferences,
    this.tzName = 'UTC',
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'event': event.apiValue,
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
        'radius_km': radiusKm,
        'place_types': placeTypes.map((t) => t.apiValue).toList(),
        'preferences': preferences.toJson(),
        'tz_name': tzName,
      };

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class TripWindowResult {
  final String locationId;
  final String name;
  final LocationType type;
  final double distanceKm;
  final String date; // "YYYY-MM-DD", as returned by the backend

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

  const TripWindowResult({
    required this.locationId,
    required this.name,
    required this.type,
    required this.distanceKm,
    required this.date,
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

  factory TripWindowResult.fromJson(Map<String, dynamic> json) => TripWindowResult(
        locationId: json['location_id'] as String,
        name: json['name'] as String,
        type: LocationType.fromApiValue(json['type'] as String),
        distanceKm: (json['distance_km'] as num).toDouble(),
        date: json['date'] as String,
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

class TripWindowResponse {
  final TripWindowResult? best;
  final int candidatesConsidered;
  final int daysConsidered;

  const TripWindowResponse({
    required this.best,
    required this.candidatesConsidered,
    required this.daysConsidered,
  });

  factory TripWindowResponse.fromJson(Map<String, dynamic> json) => TripWindowResponse(
        best: json['best'] == null
            ? null
            : TripWindowResult.fromJson(json['best'] as Map<String, dynamic>),
        candidatesConsidered: json['candidates_considered'] as int,
        daysConsidered: json['days_considered'] as int,
      );
}