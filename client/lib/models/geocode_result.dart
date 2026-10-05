/// A place the user picked, from address search or the device GPS.
class PickedLocation {
  final double lat;
  final double lon;
  final String label;

  const PickedLocation({required this.lat, required this.lon, required this.label});

  factory PickedLocation.fromJson(Map<String, dynamic> json) => PickedLocation(
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        label: json['label'] as String,
      );
}
