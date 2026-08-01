import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/saved_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/screens/saved_profiles_screen.dart';
import 'package:vesper/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  final List<SavedProfileRecord> profiles;
  _FakeApiClient(this.profiles);

  @override
  Future<List<SavedProfileRecord>> fetchSavedProfiles(String userId) async => profiles;
}

void main() {
  testWidgets('Shows empty state when there are no saved profiles', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SavedProfilesScreen(
        apiClient: _FakeApiClient([]),
        getUserId: () => 'test-user',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No saved searches yet'), findsOneWidget);
  });

  testWidgets('Shows a list of saved profiles', (tester) async {
    const profile = SavedProfileRecord(
      id: 'profile-1',
      homeLat: 40.7,
      homeLon: -73.9,
      radiusKm: 5.0,
      placeTypes: [LocationType.beach],
      event: SunEvent.sunset,
      notificationEnabled: true,
      matchThreshold: 0.75,
    );

    await tester.pumpWidget(MaterialApp(
      home: SavedProfilesScreen(
        apiClient: _FakeApiClient([profile]),
        getUserId: () => 'test-user',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sunset within 5 km'), findsOneWidget);
    expect(find.textContaining('Notify at 75%+ match'), findsOneWidget);
  });

  testWidgets('Tapping + navigates to the new saved search form', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SavedProfilesScreen(
        apiClient: _FakeApiClient([]),
        getUserId: () => 'test-user',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New saved search'), findsOneWidget);
  });
}
