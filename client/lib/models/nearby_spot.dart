import 'location_type.dart';

/// A viewing spot from the place search — location data only, no forecast.
class NearbySpot {
  final String id;
  final String name;
  final LocationType type;
  final double lat;
  final double lon;
  final double distanceKm;

  const NearbySpot({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    required this.distanceKm,
  });

  factory NearbySpot.fromJson(Map<String, dynamic> json) => NearbySpot(
        id: json['id'] as String,
        name: json['name'] as String,
        type: LocationType.fromApiValue(json['type'] as String),
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num).toDouble(),
      );
}
