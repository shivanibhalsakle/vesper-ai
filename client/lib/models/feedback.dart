import 'location_type.dart';
import 'preference_profile.dart';
import 'session_request.dart';
import 'session_response.dart';

class ForecastSnapshot {
  final String cloudCoverSummary;
  final double visibilityLikelihood;
  final ColorProbabilities colorProbabilities;
  final double preferenceMatchScore;

  const ForecastSnapshot({
    required this.cloudCoverSummary,
    required this.visibilityLikelihood,
    required this.colorProbabilities,
    required this.preferenceMatchScore,
  });

  Map<String, dynamic> toJson() => {
        'cloud_cover_summary': cloudCoverSummary,
        'visibility_likelihood': visibilityLikelihood,
        'color_probabilities': colorProbabilities.toJson(),
        'preference_match_score': preferenceMatchScore,
      };
}

class FeedbackRequest {
  final String locationId;
  final String locationName;
  final LocationType locationType;
  final SunEvent event;
  final DateTime eventDate;
  final String photoStoragePath;
  final PreferenceProfile preferenceProfile;
  final ForecastSnapshot forecastSnapshot;
  final String? userId;

  const FeedbackRequest({
    required this.locationId,
    required this.locationName,
    required this.locationType,
    required this.event,
    required this.eventDate,
    required this.photoStoragePath,
    required this.preferenceProfile,
    required this.forecastSnapshot,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'location_id': locationId,
        'location_name': locationName,
        'location_type': locationType.apiValue,
        'event': event.apiValue,
        'event_date': _formatDate(eventDate),
        'photo_storage_path': photoStoragePath,
        'preference_profile': preferenceProfile.toJson(),
        'forecast_snapshot': forecastSnapshot.toJson(),
        'user_id': userId,
      };

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class FeedbackRecord {
  final String id;
  final String locationName;

  const FeedbackRecord({required this.id, required this.locationName});

  factory FeedbackRecord.fromJson(Map<String, dynamic> json) => FeedbackRecord(
        id: json['id'] as String,
        locationName: json['location_name'] as String,
      );
}
