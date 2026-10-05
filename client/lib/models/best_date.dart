import 'location_type.dart';
import 'preference_profile.dart';
import 'session_request.dart';
import 'sky_forecast.dart';

class BestDateRequest {
  final double lat;
  final double lon;
  final SunEvent event;
  final DateTime startDate;
  final int days;
  final double radiusKm;
  // Empty = all place types.
  final List<LocationType> placeTypes;
  final PreferenceProfile preferences;

  const BestDateRequest({
    required this.lat,
    required this.lon,
    required this.event,
    required this.startDate,
    this.days = 7,
    required this.radiusKm,
    this.placeTypes = const [],
    required this.preferences,
  });

  Map<String, dynamic> toJson() {
    final month = startDate.month.toString().padLeft(2, '0');
    final day = startDate.day.toString().padLeft(2, '0');
    return {
      'lat': lat,
      'lon': lon,
      'event': event.apiValue,
      'start_date': '${startDate.year}-$month-$day',
      'days': days,
      'radius_km': radiusKm,
      'place_types': placeTypes.map((t) => t.apiValue).toList(),
      'preferences': preferences.toJson(),
      'tz_name': 'auto',
    };
  }
}

class BestSpot {
  final String locationId;
  final String name;
  final LocationType type;
  final double lat;
  final double lon;
  final double distanceKm;

  const BestSpot({
    required this.locationId,
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    required this.distanceKm,
  });

  factory BestSpot.fromJson(Map<String, dynamic> json) => BestSpot(
        locationId: json['location_id'] as String,
        name: json['name'] as String,
        type: LocationType.fromApiValue(json['type'] as String),
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num).toDouble(),
      );
}

class DayScore {
  final DateTime date;
  final double score;
  final Confidence confidence;
  final String? spotName;

  const DayScore({
    required this.date,
    required this.score,
    required this.confidence,
    required this.spotName,
  });

  factory DayScore.fromJson(Map<String, dynamic> json) => DayScore(
        date: DateTime.parse(json['date'] as String),
        score: (json['score'] as num).toDouble(),
        confidence: Confidence.values.byName(json['confidence'] as String),
        spotName: json['spot_name'] as String?,
      );
}

class BestDay {
  final DateTime date;
  final BestSpot? spot;
  final SkyForecast sky;

  const BestDay({required this.date, required this.spot, required this.sky});

  factory BestDay.fromJson(Map<String, dynamic> json) => BestDay(
        date: DateTime.parse(json['date'] as String),
        spot: json['spot'] == null
            ? null
            : BestSpot.fromJson(json['spot'] as Map<String, dynamic>),
        sky: SkyForecast.fromJson(json['sky'] as Map<String, dynamic>),
      );
}

class BestDateResponse {
  final List<DayScore> days;
  final BestDay? best;
  final int spotsConsidered;

  const BestDateResponse({
    required this.days,
    required this.best,
    required this.spotsConsidered,
  });

  factory BestDateResponse.fromJson(Map<String, dynamic> json) => BestDateResponse(
        days: (json['days'] as List)
            .map((d) => DayScore.fromJson(d as Map<String, dynamic>))
            .toList(),
        best: json['best'] == null
            ? null
            : BestDay.fromJson(json['best'] as Map<String, dynamic>),
        spotsConsidered: json['spots_considered'] as int,
      );
}
