import 'location_type.dart';
import 'preference_profile.dart';
import 'session_request.dart';

class SavedProfileRequest {
  final String userId;
  final double homeLat;
  final double homeLon;
  final double radiusKm;
  final List<LocationType> placeTypes;
  final SunEvent event;
  final PreferenceProfile preferences;
  final String? fcmToken;
  final bool notificationEnabled;
  final double matchThreshold;
  final String tzName;

  const SavedProfileRequest({
    required this.userId,
    required this.homeLat,
    required this.homeLon,
    required this.radiusKm,
    required this.placeTypes,
    required this.event,
    required this.preferences,
    this.fcmToken,
    this.notificationEnabled = true,
    this.matchThreshold = 0.75,
    this.tzName = 'UTC',
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'home_lat': homeLat,
        'home_lon': homeLon,
        'radius_km': radiusKm,
        'place_types': placeTypes.map((t) => t.apiValue).toList(),
        'event': event.apiValue,
        'tz_name': tzName,
        'preference_profile': preferences.toJson(),
        'fcm_token': fcmToken,
        'notification_enabled': notificationEnabled,
        'match_threshold': matchThreshold,
      };
}

class SavedProfileRecord {
  final String id;
  final double homeLat;
  final double homeLon;
  final double radiusKm;
  final List<LocationType> placeTypes;
  final SunEvent event;
  final bool notificationEnabled;
  final double matchThreshold;

  const SavedProfileRecord({
    required this.id,
    required this.homeLat,
    required this.homeLon,
    required this.radiusKm,
    required this.placeTypes,
    required this.event,
    required this.notificationEnabled,
    required this.matchThreshold,
  });

  factory SavedProfileRecord.fromJson(Map<String, dynamic> json) => SavedProfileRecord(
        id: json['id'] as String,
        homeLat: (json['home_lat'] as num).toDouble(),
        homeLon: (json['home_lon'] as num).toDouble(),
        radiusKm: (json['radius_km'] as num).toDouble(),
        placeTypes: (json['place_types'] as List)
            .map((t) => LocationType.fromApiValue(t as String))
            .toList(),
        event: SunEvent.fromApiValue(json['event'] as String),
        notificationEnabled: json['notification_enabled'] as bool,
        matchThreshold: (json['match_threshold'] as num).toDouble(),
      );
}
