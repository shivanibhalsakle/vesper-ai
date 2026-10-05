import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/user_preferences.dart';

void main() {
  test('UserPreferences survives a JSON round trip', () {
    const original = UserPreferences(
      home: PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn'),
      radiusKm: 25,
      placeTypes: [LocationType.park, LocationType.elevatedViewpoint],
      event: SunEvent.sunrise,
      preferences: PreferenceProfile(pinkPurple: 0.7, cityScape: 0.4),
    );

    final restored = UserPreferences.fromJson(original.toJson());

    expect(restored.home!.label, 'Brooklyn');
    expect(restored.radiusKm, 25);
    expect(restored.placeTypes, [LocationType.park, LocationType.elevatedViewpoint]);
    expect(restored.event, SunEvent.sunrise);
    expect(restored.preferences.pinkPurple, 0.7);
    expect(restored.preferences.cityScape, 0.4);
  });

  test('A missing home location stays null', () {
    final restored = UserPreferences.fromJson(const UserPreferences().toJson());

    expect(restored.home, isNull);
    expect(restored.placeTypes, isEmpty);
  });
}
