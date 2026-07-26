import 'location_type.dart';
import 'preference_profile.dart';

enum SunEvent {
  sunrise,
  sunset;

  String get apiValue => name;
  String get label => name[0].toUpperCase() + name.substring(1);
}

class SessionRequest {
  final double lat;
  final double lon;
  final SunEvent event;
  final DateTime date;
  final double radiusKm;
  final List<LocationType> placeTypes;
  final PreferenceProfile preferences;
  final String tzName;

  const SessionRequest({
    required this.lat,
    required this.lon,
    required this.event,
    required this.date,
    required this.radiusKm,
    required this.placeTypes,
    required this.preferences,
    this.tzName = 'UTC',
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'event': event.apiValue,
        'date': _formatDate(date),
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
