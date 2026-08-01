import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/saved_profile.dart';
import 'package:vesper/screens/saved_profile_form_screen.dart';
import 'package:vesper/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  SavedProfileRequest? lastRequest;

  @override
  Future<SavedProfileRecord> createSavedProfile(SavedProfileRequest request) async {
    lastRequest = request;
    return SavedProfileRecord(
      id: 'new-id',
      homeLat: request.homeLat,
      homeLon: request.homeLon,
      radiusKm: request.radiusKm,
      placeTypes: request.placeTypes,
      event: request.event,
      notificationEnabled: request.notificationEnabled,
      matchThreshold: request.matchThreshold,
    );
  }
}

void main() {
  testWidgets('Shows core inputs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SavedProfileFormScreen(
        apiClient: _FakeApiClient(),
        getUserId: () => 'test-user',
        getFcmToken: () async => null,
      ),
    ));

    expect(find.text('New saved search'), findsOneWidget);
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Submitting creates a profile and pops with true', (tester) async {
    final fakeClient = _FakeApiClient();
    bool? poppedValue;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            poppedValue = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => SavedProfileFormScreen(
                  apiClient: fakeClient,
                  getUserId: () => 'test-user',
                  getFcmToken: () async => 'fake-token',
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fakeClient.lastRequest, isNotNull);
    expect(fakeClient.lastRequest!.userId, 'test-user');
    expect(fakeClient.lastRequest!.fcmToken, 'fake-token');
    expect(poppedValue, true);
  });
}
