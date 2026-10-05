import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/nearby_spot.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/nearby_spots_screen.dart';
import 'package:vesper/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  UserPreferences? stored;
  List<NearbySpot> spots = const [];
  Object? spotsError;
  final List<Map<String, Object?>> calls = [];

  @override
  Future<UserPreferences?> fetchPreferences() async => stored;

  @override
  Future<List<NearbySpot>> fetchNearbySpots({
    required double lat,
    required double lon,
    required double radiusKm,
    List<LocationType> placeTypes = const [],
  }) async {
    calls.add({'lat': lat, 'lon': lon, 'radius': radiusKm, 'types': placeTypes});
    if (spotsError != null) throw spotsError!;
    return spots;
  }
}

const _home = PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn Bridge Park');

Future<void> _pump(WidgetTester tester, _FakeApiClient api) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: NearbySpotsScreen(apiClient: api)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Find button is disabled until a location is chosen', (tester) async {
    await _pump(tester, _FakeApiClient());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Starts from the saved home spot, radius and place types', (tester) async {
    final api = _FakeApiClient()
      ..stored = const UserPreferences(
        home: _home,
        radiusKm: 20,
        placeTypes: [LocationType.beach],
      )
      ..spots = const [
        NearbySpot(
          id: 'osm-1',
          name: 'Brighton Beach',
          type: LocationType.beach,
          lat: 40.57,
          lon: -73.96,
          distanceKm: 3.2,
        ),
      ];
    await _pump(tester, api);

    expect(find.text('Brooklyn Bridge Park'), findsOneWidget);
    await tester.tap(find.text('Find viewing spots'));
    await tester.pumpAndSettle();

    expect(api.calls.single['radius'], 20.0);
    expect(api.calls.single['types'], [LocationType.beach]);
    expect(find.text('1 spots nearby'), findsOneWidget);
    expect(find.text('Brighton Beach'), findsOneWidget);
    expect(find.text('Beach · 3.2 km away'), findsOneWidget);
  });

  testWidgets('Shows a friendly message when nothing is found', (tester) async {
    final api = _FakeApiClient()..stored = const UserPreferences(home: _home);
    await _pump(tester, api);

    await tester.tap(find.text('Find viewing spots'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No viewing spots found'), findsOneWidget);
  });

  testWidgets('Shows the error when the search fails', (tester) async {
    final api = _FakeApiClient()
      ..stored = const UserPreferences(home: _home)
      ..spotsError = ApiException('Place data is temporarily unavailable.');
    await _pump(tester, api);

    await tester.tap(find.text('Find viewing spots'));
    await tester.pumpAndSettle();

    expect(find.text('Place data is temporarily unavailable.'), findsOneWidget);
  });
}
