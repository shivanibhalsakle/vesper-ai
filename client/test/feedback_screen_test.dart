import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/feedback.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/screens/feedback_screen.dart';
import 'package:vesper/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  @override
  Future<FeedbackRecord> createFeedback(FeedbackRequest request) async =>
      FeedbackRecord(id: 'fb-1', locationName: request.locationName);
}

Widget _buildScreen({ApiClient? apiClient}) {
  return MaterialApp(
    home: FeedbackScreen(
      locationId: 'loc-1',
      locationName: 'Golden Point',
      locationType: LocationType.elevatedViewpoint,
      event: SunEvent.sunset,
      eventDate: DateTime(2026, 7, 27),
      preferenceProfile: const PreferenceProfile(goldenOrange: 1.0),
      forecastSnapshot: const ForecastSnapshot(
        cloudCoverSummary: 'clear skies',
        visibilityLikelihood: 0.9,
        colorProbabilities: ColorProbabilities(
          pink: 0.2,
          purple: 0.1,
          orange: 0.8,
          red: 0.1,
          golden: 0.9,
        ),
        preferenceMatchScore: 0.85,
      ),
      apiClient: apiClient,
      getUserId: () => 'test-user',
    ),
  );
}

void main() {
  testWidgets('Shows title and photo placeholder', (tester) async {
    await tester.pumpWidget(_buildScreen());

    expect(find.text('How was Golden Point?'), findsOneWidget);
    expect(find.text('Tap to add a photo'), findsOneWidget);
    expect(find.text('Submit feedback'), findsOneWidget);
  });

  testWidgets('Submitting without a photo shows a validation message', (tester) async {
    await tester.pumpWidget(_buildScreen(apiClient: _FakeApiClient()));

    await tester.ensureVisible(find.text('Submit feedback'));
    await tester.pump();
    await tester.tap(find.text('Submit feedback'));
    await tester.pump();

    expect(find.text('Add a photo before submitting.'), findsOneWidget);
  });
}
