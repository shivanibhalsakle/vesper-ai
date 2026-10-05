import 'geocode_result.dart';
import 'location_type.dart';
import 'preference_profile.dart';
import 'session_request.dart';

/// What the user saved in Settings: home location, search defaults and the
/// sky-preference sliders. Stored server-side so it follows them across
/// devices.
class UserPreferences {
  final PickedLocation? home;
  final double radiusKm;
  // Empty = no preference (all place types).
  final List<LocationType> placeTypes;
  final SunEvent event;
  final PreferenceProfile preferences;

  const UserPreferences({
    this.home,
    this.radiusKm = 10.0,
    this.placeTypes = const [],
    this.event = SunEvent.sunset,
    this.preferences = const PreferenceProfile(),
  });

  Map<String, dynamic> toJson() => {
        'home_lat': home?.lat,
        'home_lon': home?.lon,
        'home_label': home?.label,
        'radius_km': radiusKm,
        'place_types': placeTypes.map((t) => t.apiValue).toList(),
        'event': event.apiValue,
        'preference_profile': preferences.toJson(),
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final lat = json['home_lat'];
    final lon = json['home_lon'];
    return UserPreferences(
      home: lat is num && lon is num
          ? PickedLocation(
              lat: lat.toDouble(),
              lon: lon.toDouble(),
              label: (json['home_label'] as String?) ?? 'Saved location',
            )
          : null,
      radiusKm: (json['radius_km'] as num).toDouble(),
      placeTypes: (json['place_types'] as List)
          .map((t) => LocationType.fromApiValue(t as String))
          .toList(),
      event: SunEvent.fromApiValue(json['event'] as String),
      preferences:
          PreferenceProfile.fromJson(json['preference_profile'] as Map<String, dynamic>),
    );
  }
}
