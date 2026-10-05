import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/saved_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/trip_window.dart';

// Requests must ask for the place's own timezone ('auto'); a hard-coded UTC
// made sunset times show in UTC and picked the wrong forecast hour.
void main() {
  test('Search requests default to the place timezone', () {
    final session = SessionRequest(
      lat: 34.0,
      lon: -118.5,
      event: SunEvent.sunset,
      date: DateTime(2026, 10, 5),
      radiusKm: 5,
      placeTypes: const [LocationType.beach],
      preferences: const PreferenceProfile(),
    );
    final trip = TripWindowRequest(
      lat: 34.0,
      lon: -118.5,
      event: SunEvent.sunset,
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 11),
      radiusKm: 5,
      placeTypes: const [LocationType.beach],
      preferences: const PreferenceProfile(),
    );
    const saved = SavedProfileRequest(
      homeLat: 34.0,
      homeLon: -118.5,
      radiusKm: 5,
      placeTypes: [LocationType.beach],
      event: SunEvent.sunset,
      preferences: PreferenceProfile(),
    );

    expect(session.toJson()['tz_name'], 'auto');
    expect(trip.toJson()['tz_name'], 'auto');
    expect(saved.toJson()['tz_name'], 'auto');
  });
}
