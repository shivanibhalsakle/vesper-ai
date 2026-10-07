import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/best_date.dart';
import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/models/sky_forecast.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/best_date_result_screen.dart';
import 'package:vesper/screens/best_date_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/utils/format.dart';
import 'package:vesper/widgets/spectrum_slider.dart';

const _sky = SkyForecast(
  event: SunEvent.sunset,
  eventTime: '2026-10-07T18:08:00-04:00',
  eventPassed: false,
  recommendedArrivalOffsetMinutes: -20,
  bestViewingWindowStart: '2026-10-07T17:48:00-04:00',
  bestViewingWindowEnd: '2026-10-07T18:28:00-04:00',
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
  preferenceMatchScore: 0.84,
  leadDays: 2,
  confidence: Confidence.medium,
);

final _response = BestDateResponse(
  days: [
    DayScore(
        date: DateTime(2026, 10, 5),
        score: 0.41,
        confidence: Confidence.high,
        spotName: 'Pier 1'),
    DayScore(
        date: DateTime(2026, 10, 6),
        score: 0.55,
        confidence: Confidence.high,
        spotName: 'Pier 1'),
    DayScore(
        date: DateTime(2026, 10, 7),
        score: 0.84,
        confidence: Confidence.medium,
        spotName: 'Brooklyn Bridge Park'),
  ],
  best: BestDay(
    date: DateTime(2026, 10, 7),
    spot: const BestSpot(
      locationId: 'osm-1',
      name: 'Brooklyn Bridge Park',
      type: LocationType.waterfront,
      lat: 40.7,
      lon: -73.99,
      distanceKm: 0.8,
    ),
    sky: _sky,
  ),
  spotsConsidered: 5,
);

const _taste = PreferenceProfile(goldenOrange: 0.9, clearSky: 0.4);
const _home = PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn Bridge Park');

class _FakeApiClient extends ApiClient {
  UserPreferences? stored;
  Object? bestError;
  final List<BestDateRequest> requests = [];
  final List<UserPreferences> saved = [];

  @override
  Future<UserPreferences?> fetchPreferences() async => stored;

  @override
  Future<UserPreferences> savePreferences(UserPreferences preferences) async {
    saved.add(preferences);
    return preferences;
  }

  @override
  Future<BestDateResponse> fetchBestDate(BestDateRequest request) async {
    requests.add(request);
    if (bestError != null) throw bestError!;
    return _response;
  }
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  group('BestDateResultScreen', () {
    testWidgets('shows the best date, the week and the sky bars', (tester) async {
      await _pump(
        tester,
        BestDateResultScreen(response: _response, preferences: _taste, location: _home),
      );

      expect(find.text('Wednesday, October 7'), findsOneWidget);
      expect(find.textContaining('Brooklyn Bridge Park · Waterfront'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('41%'), findsOneWidget);
      expect(find.byKey(const Key('best-day-tile')), findsOneWidget);
      expect(find.text('Expected sky'), findsOneWidget);
      // Preference markers: golden/orange and clear sky are turned up.
      expect(find.byKey(const Key('preference-marker')), findsNWidgets(2));
    });

    testWidgets('explains itself when nothing could be scored', (tester) async {
      await _pump(
        tester,
        const BestDateResultScreen(
          response: BestDateResponse(days: [], best: null, spotsConsidered: 0),
          preferences: _taste,
          location: _home,
        ),
      );

      expect(find.textContaining('No upcoming days could be scored'), findsOneWidget);
    });
  });

  group('BestDateScreen', () {
    testWidgets('without saved preferences the sliders start empty and the search waits',
        (tester) async {
      final api = _FakeApiClient()..stored = const UserPreferences(home: _home);
      await _pump(tester, BestDateScreen(apiClient: api));

      expect(find.byType(SpectrumSlider), findsNWidgets(5));
      expect(find.textContaining('Tell us what you love'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('the sliders start at the saved taste; there is no Edit preferences button',
        (tester) async {
      final api = _FakeApiClient()
        ..stored = const UserPreferences(home: _home, preferences: _taste);
      await _pump(tester, BestDateScreen(apiClient: api));

      expect(find.text('Edit preferences'), findsNothing);
      expect(find.text('Set my preferences'), findsNothing);
      final sliders = tester.widgetList<SpectrumSlider>(find.byType(SpectrumSlider)).toList();
      expect(sliders.map((s) => s.value), [0.4, 0.0, 0.0, 0.9, 0.0]);
    });

    testWidgets('tweaking a slider is used for this search only, never saved', (tester) async {
      final api = _FakeApiClient()
        ..stored = const UserPreferences(home: _home, preferences: _taste);
      await _pump(tester, BestDateScreen(apiClient: api));

      // Turn "Red skies" (the fifth slider) up to its maximum.
      final redSkies = find.byType(SpectrumSlider).at(4);
      await tester.drag(redSkies, const Offset(2000, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find my best day'));
      await tester.pumpAndSettle();

      expect(api.requests.single.preferences.redSky, 1.0);
      expect(api.requests.single.preferences.goldenOrange, 0.9);
      expect(api.saved, isEmpty);
    });

    testWidgets('a search can start from nothing by turning a slider up', (tester) async {
      final api = _FakeApiClient()..stored = const UserPreferences(home: _home);
      await _pump(tester, BestDateScreen(apiClient: api));

      await tester.drag(find.byType(SpectrumSlider).first, const Offset(2000, 0));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows the saved taste and sends it with the saved location', (tester) async {
      final api = _FakeApiClient()
        ..stored = const UserPreferences(
          home: _home,
          radiusKm: 15,
          placeTypes: [LocationType.beach],
          event: SunEvent.sunrise,
          preferences: _taste,
        );
      await _pump(tester, BestDateScreen(apiClient: api));

      expect(find.text('Brooklyn Bridge Park'), findsOneWidget);

      await tester.tap(find.text('Find my best day'));
      await tester.pumpAndSettle();

      final request = api.requests.single;
      expect(request.lat, 40.7);
      expect(request.radiusKm, 15);
      expect(request.event, SunEvent.sunrise);
      expect(request.placeTypes, [LocationType.beach]);
      expect(request.preferences.goldenOrange, 0.9);
      expect(find.text('Wednesday, October 7'), findsOneWidget);
    });

    testWidgets('shows the error when the search fails', (tester) async {
      final api = _FakeApiClient()
        ..stored = const UserPreferences(home: _home, preferences: _taste)
        ..bestError = ApiException('Weather data is temporarily unavailable.');
      await _pump(tester, BestDateScreen(apiClient: api));

      await tester.tap(find.text('Find my best day'));
      await tester.pumpAndSettle();

      expect(find.text('Weather data is temporarily unavailable.'), findsOneWidget);
    });

    testWidgets('needs a location before continuing', (tester) async {
      final api = _FakeApiClient()..stored = const UserPreferences(preferences: _taste);
      await _pump(tester, BestDateScreen(apiClient: api));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('BestDateResponse.fromJson', () {
    test('parses a full response', () {
      final json = {
        'spots_considered': 3,
        'days': [
          {
            'date': '2026-10-07',
            'score': 0.84,
            'confidence': 'medium',
            'spot_name': 'Brooklyn Bridge Park',
          },
        ],
        'best': {
          'date': '2026-10-07',
          'spot': {
            'location_id': 'osm-1',
            'name': 'Brooklyn Bridge Park',
            'type': 'waterfront',
            'lat': 40.7,
            'lon': -73.99,
            'distance_km': 0.8,
          },
          'sky': {
            'event': 'sunset',
            'event_time': '2026-10-07T18:08:00-04:00',
            'event_passed': false,
            'recommended_arrival_offset_minutes': -20,
            'best_viewing_window_start': '2026-10-07T17:48:00-04:00',
            'best_viewing_window_end': '2026-10-07T18:28:00-04:00',
            'visibility_likelihood': 0.9,
            'cloud_cover_summary': 'mostly clear skies',
            'color_probabilities': {
              'pink': 0.1,
              'purple': 0.1,
              'orange': 0.5,
              'red': 0.1,
              'golden': 0.6,
            },
            'sky_profile': {
              'clear_sky': 0.9,
              'dramatic_clouds': 0.1,
              'pink_purple': 0.1,
              'golden_orange': 0.55,
              'red_sky': 0.1,
            },
            'rain_or_unsafe_alert': null,
            'preference_match_score': 0.84,
            'lead_days': 2,
            'confidence': 'medium',
          },
        },
      };

      final parsed = BestDateResponse.fromJson(json);

      expect(parsed.days.single.confidence, Confidence.medium);
      expect(parsed.best!.spot!.name, 'Brooklyn Bridge Park');
      expect(parsed.best!.sky.skyProfile.goldenOrange, 0.55);
      expect(parsed.best!.sky.leadDays, 2);
    });

    test('a best day without a mapped spot parses', () {
      final parsed = BestDateResponse.fromJson({
        'spots_considered': 0,
        'days': <Object>[],
        'best': null,
      });

      expect(parsed.best, isNull);
    });
  });

  group('date formatting', () {
    test('long date and short weekday', () {
      expect(formatLongDate(DateTime(2026, 10, 7)), 'Wednesday, October 7');
      expect(formatShortWeekday(DateTime(2026, 10, 5)), 'Mon');
    });

  });
}
