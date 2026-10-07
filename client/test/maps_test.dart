import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/nearby_spot.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/nearby_spots_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/utils/maps.dart';

class _FakeApiClient extends ApiClient {
  @override
  Future<UserPreferences?> fetchPreferences() async => const UserPreferences(
        home: PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn'),
      );

  @override
  Future<List<NearbySpot>> fetchNearbySpots({
    required double lat,
    required double lon,
    required double radiusKm,
    List<LocationType> placeTypes = const [],
  }) async =>
      const [
        NearbySpot(
          id: 'osm-1',
          name: 'Brighton Beach',
          type: LocationType.beach,
          lat: 40.5776,
          lon: -73.9614,
          distanceKm: 3.2,
        ),
      ];
}

late List<Uri> _opened;
late bool _openResult;

void _install() {
  _opened = [];
  _openResult = true;
  final original = MapsLauncher.opener;
  MapsLauncher.opener = (uri) async {
    _opened.add(uri);
    return _openResult;
  };
  addTearDown(() => MapsLauncher.opener = original);
}

Future<void> _pumpSpots(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: NearbySpotsScreen(apiClient: _FakeApiClient())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Find viewing spots'));
  await tester.pumpAndSettle();
}

void main() {
  test('the link points at the exact coordinates', () {
    final uri = MapsLauncher.uriFor(40.5776, -73.9614);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], '40.5776,-73.9614');
  });

  testWidgets('tapping a spot asks first, and nothing opens until confirmed', (tester) async {
    _install();
    await _pumpSpots(tester);

    await tester.tap(find.byKey(const Key('spot-osm-1')));
    await tester.pumpAndSettle();

    expect(find.text('Open in Google Maps?'), findsOneWidget);
    expect(find.text('Brighton Beach'), findsWidgets);
    expect(_opened, isEmpty);

    await tester.tap(find.byKey(const Key('open-in-maps-confirm')));
    await tester.pumpAndSettle();

    expect(_opened.single, MapsLauncher.uriFor(40.5776, -73.9614));
    expect(find.byKey(const Key('open-in-maps-dialog')), findsNothing);
  });

  testWidgets('cancelling opens nothing', (tester) async {
    _install();
    await _pumpSpots(tester);

    await tester.tap(find.byKey(const Key('spot-osm-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-in-maps-cancel')));
    await tester.pumpAndSettle();

    expect(_opened, isEmpty);
    expect(find.byKey(const Key('open-in-maps-dialog')), findsNothing);
  });

  testWidgets('says so when the phone cannot open the link', (tester) async {
    _install();
    _openResult = false;
    await _pumpSpots(tester);

    await tester.tap(find.byKey(const Key('spot-osm-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-in-maps-confirm')));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't open Google Maps on this device."), findsOneWidget);
  });
}
