import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/settings_screen.dart';
import 'package:vesper/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  UserPreferences? stored;
  UserPreferences? saved;
  Object? loadError;
  List<PickedLocation> searchResults = const [];

  _FakeApiClient({this.stored});

  @override
  Future<UserPreferences?> fetchPreferences() async {
    if (loadError != null) throw loadError!;
    return stored;
  }

  @override
  Future<UserPreferences> savePreferences(UserPreferences preferences) async {
    saved = preferences;
    return preferences;
  }

  @override
  Future<List<PickedLocation>> geocode(String query) async => searchResults;
}

Future<void> _pump(WidgetTester tester, _FakeApiClient api) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: SettingsScreen(apiClient: api)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('New users see an empty form with no location', (tester) async {
    await _pump(tester, _FakeApiClient());

    expect(find.text('No location chosen'), findsOneWidget);
    expect(find.text('Save preferences'), findsOneWidget);
    expect(find.text('Find me a good viewing date'), findsOneWidget);
  });

  testWidgets('Saved preferences are loaded into the form', (tester) async {
    final api = _FakeApiClient(
      stored: const UserPreferences(
        home: PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn Bridge Park'),
        radiusKm: 20,
        placeTypes: [LocationType.beach],
        event: SunEvent.sunrise,
        preferences: PreferenceProfile(goldenOrange: 0.8),
      ),
    );
    await _pump(tester, api);

    expect(find.text('Brooklyn Bridge Park'), findsOneWidget);
    expect(find.text('Travel radius: 20 km'), findsOneWidget);
    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Beach'));
    expect(chip.selected, isTrue);
  });

  testWidgets('Save preferences sends the current form values', (tester) async {
    final api = _FakeApiClient(
      stored: const UserPreferences(
        home: PickedLocation(lat: 40.7, lon: -73.99, label: 'Home'),
      ),
    );
    await _pump(tester, api);

    await tester.tap(find.text('Sunrise'));
    await tester.tap(find.widgetWithText(FilterChip, 'Park'));
    await tester.pump();
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();

    expect(api.saved, isNotNull);
    expect(api.saved!.event, SunEvent.sunrise);
    expect(api.saved!.placeTypes, [LocationType.park]);
    expect(api.saved!.home!.label, 'Home');
    expect(find.text('Preferences saved'), findsOneWidget);
  });

  testWidgets('Searching and picking a result updates the home spot', (tester) async {
    final api = _FakeApiClient()
      ..searchResults = const [
        PickedLocation(lat: 34.1, lon: -118.3, label: 'Griffith Observatory, Los Angeles'),
      ];
    await _pump(tester, api);

    await tester.enterText(find.byType(TextField), 'griffith');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Powered by Geoapify'), findsOneWidget);
    await tester.tap(find.text('Griffith Observatory, Los Angeles'));
    await tester.pumpAndSettle();

    expect(find.text('34.1000, -118.3000'), findsOneWidget);
    expect(find.text('Powered by Geoapify'), findsNothing);
  });

  testWidgets('Finding a date without a location asks for one', (tester) async {
    await _pump(tester, _FakeApiClient());

    await tester.tap(find.text('Find me a good viewing date'));
    await tester.pump();

    expect(find.text('Choose a location first.'), findsOneWidget);
  });

  testWidgets('A load failure shows a retry button', (tester) async {
    final api = _FakeApiClient()..loadError = ApiException('boom');
    await _pump(tester, api);

    expect(find.textContaining('Could not load your settings'), findsOneWidget);

    api.loadError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Save preferences'), findsOneWidget);
  });
}
