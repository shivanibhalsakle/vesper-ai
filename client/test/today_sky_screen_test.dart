import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/models/sky_forecast.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/today_sky_screen.dart';
import 'package:vesper/services/api_client.dart';

const _sky = SkyForecast(
  event: SunEvent.sunset,
  eventTime: '2026-10-05T18:12:00-04:00',
  eventPassed: false,
  recommendedArrivalOffsetMinutes: -20,
  bestViewingWindowStart: '2026-10-05T17:52:00-04:00',
  bestViewingWindowEnd: '2026-10-05T18:32:00-04:00',
  visibilityLikelihood: 0.9,
  cloudCoverSummary: 'light cloud cover (high clouds)',
  colorProbabilities:
      ColorProbabilities(pink: 0.4, purple: 0.3, orange: 0.7, red: 0.2, golden: 0.8),
  skyProfile: SkyProfile(
    clearSky: 0.8,
    dramaticClouds: 0.3,
    pinkPurple: 0.35,
    goldenOrange: 0.75,
    redSky: 0.2,
  ),
  rainOrUnsafeAlert: null,
  preferenceMatchScore: 0.82,
  leadDays: 0,
  confidence: Confidence.high,
);

const _spot = LocationResult(
  locationId: 'osm-1',
  name: 'Brooklyn Bridge Park',
  type: LocationType.waterfront,
  distanceKm: 0.8,
  eventTime: '2026-10-05T18:12:00-04:00',
  recommendedArrivalOffsetMinutes: -20,
  bestViewingWindowStart: '2026-10-05T17:52:00-04:00',
  bestViewingWindowEnd: '2026-10-05T18:32:00-04:00',
  visibilityLikelihood: 0.9,
  cloudCoverSummary: 'light cloud cover',
  colorProbabilities:
      ColorProbabilities(pink: 0.4, purple: 0.3, orange: 0.7, red: 0.2, golden: 0.8),
  rainOrUnsafeAlert: null,
  preferenceMatchScore: 0.77,
  explanation: 'Open water view west over the harbour.',
);

class _FakeApiClient extends ApiClient {
  UserPreferences? stored;
  Object? skyError;
  Object? spotsError;
  final List<SkyRequest> skyRequests = [];
  final List<SessionRequest> sessionRequests = [];

  @override
  Future<UserPreferences?> fetchPreferences() async => stored;

  @override
  Future<SkyForecast> fetchSky(SkyRequest request) async {
    skyRequests.add(request);
    if (skyError != null) throw skyError!;
    return _sky;
  }

  @override
  Future<SessionResponse> fetchSession(SessionRequest request) async {
    sessionRequests.add(request);
    if (spotsError != null) throw spotsError!;
    return const SessionResponse(recommendations: [_spot]);
  }
}

const _home = PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn Bridge Park');

Future<void> _pump(WidgetTester tester, _FakeApiClient api) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: TodaySkyScreen(apiClient: api)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Show button is disabled until a location is chosen', (tester) async {
    await _pump(tester, _FakeApiClient());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Shows the sky details and the suggested spots', (tester) async {
    final api = _FakeApiClient()
      ..stored = const UserPreferences(
        home: _home,
        event: SunEvent.sunset,
        preferences: PreferenceProfile(goldenOrange: 0.9),
      );
    await _pump(tester, api);

    await tester.tap(find.text("Show today's sky"));
    await tester.pumpAndSettle();

    expect(api.skyRequests.single.lat, 40.7);
    expect(api.skyRequests.single.preferences, isNotNull);
    expect(api.sessionRequests.single.event, SunEvent.sunset);

    expect(find.text('82%'), findsOneWidget);
    expect(find.text('Sunset at 6:12 PM'), findsOneWidget);
    expect(find.text('Expected sky'), findsOneWidget);
    expect(find.text('Best spots for this sky'), findsOneWidget);
    expect(find.text('Brooklyn Bridge Park'), findsWidgets);
    expect(find.text('Open water view west over the harbour.'), findsOneWidget);
    expect(find.text('77%'), findsOneWidget);
  });

  testWidgets('Without sky preferences no match score is requested or shown', (tester) async {
    final api = _FakeApiClient()..stored = const UserPreferences(home: _home);
    await _pump(tester, api);

    await tester.tap(find.text("Show today's sky"));
    await tester.pumpAndSettle();

    expect(api.skyRequests.single.preferences, isNull);
    expect(find.text('77%'), findsNothing);
  });

  testWidgets('A spots failure does not hide the sky', (tester) async {
    final api = _FakeApiClient()
      ..stored = const UserPreferences(home: _home)
      ..spotsError = ApiException('Place data is temporarily unavailable.');
    await _pump(tester, api);

    await tester.tap(find.text("Show today's sky"));
    await tester.pumpAndSettle();

    expect(find.text('Expected sky'), findsOneWidget);
    expect(find.text('Place data is temporarily unavailable.'), findsOneWidget);
  });

  testWidgets('A sky failure shows the error', (tester) async {
    final api = _FakeApiClient()
      ..stored = const UserPreferences(home: _home)
      ..skyError = ApiException('Weather data is temporarily unavailable.');
    await _pump(tester, api);

    await tester.tap(find.text("Show today's sky"));
    await tester.pumpAndSettle();

    expect(find.text('Weather data is temporarily unavailable.'), findsOneWidget);
    expect(find.text('Expected sky'), findsNothing);
  });
}
