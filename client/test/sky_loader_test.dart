import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/best_date.dart';
import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/nearby_spot.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/models/sky_forecast.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/best_date_screen.dart';
import 'package:vesper/screens/nearby_spots_screen.dart';
import 'package:vesper/screens/today_sky_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/widgets/sky_loader.dart';

const _tips = ['First tip', 'Second tip', 'Third tip'];

Widget _host(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    theme: buildAppTheme(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: app!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

Rect _sunRect(WidgetTester tester) => tester.getRect(find.byKey(const Key('sky-loader-sun')));

/// Unmounts the loader so its timer and tickers are disposed before the
/// test ends (the framework fails tests that leave timers running).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  group('SkyLoader', () {
    testWidgets('shows the message, the first tip and a spoken label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const SkyLoader(message: 'Reading the sky', tips: _tips)));

      expect(find.text('Reading the sky'), findsOneWidget);
      expect(find.text('First tip'), findsOneWidget);
      expect(find.bySemanticsLabel('Reading the sky'), findsOneWidget);

      handle.dispose();
      await _unmount(tester);
    });

    testWidgets('rotates through the tips', (tester) async {
      await tester.pumpWidget(_host(const SkyLoader(message: 'Loading', tips: _tips)));

      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 500)); // let the cross-fade finish
      expect(find.text('Second tip'), findsOneWidget);
      expect(find.text('First tip'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Third tip'), findsOneWidget);

      // And it wraps around.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('First tip'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('the sun travels across the sky', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 360,
        child: SkyLoader(message: 'Loading', tips: _tips),
      )));

      final start = _sunRect(tester).center;
      await tester.pump(const Duration(seconds: 4));
      final later = _sunRect(tester).center;

      expect(later.dx, greaterThan(start.dx + 20));

      await _unmount(tester);
    });

    testWidgets('tapping the sun makes it pop and throw sparkles, then they fade', (tester) async {
      await tester.pumpWidget(_host(const SkyLoader(message: 'Loading', tips: _tips)));
      expect(find.byKey(const Key('sky-loader-sparkles')), findsNothing);

      await tester.tap(find.byKey(const Key('sky-loader-sun')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('sky-loader-sparkles')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const Key('sky-loader-sparkles')), findsNothing);

      await _unmount(tester);
    });

    testWidgets('reduced motion: a still sky, no rotating tips, no sparkles', (tester) async {
      await tester.pumpWidget(_host(
        const SkyLoader(message: 'Loading', tips: _tips),
        reduceMotion: true,
      ));
      // With nothing animating, the tree settles (it would time out otherwise).
      await tester.pumpAndSettle();

      final start = _sunRect(tester).center;
      await tester.pump(const Duration(seconds: 6));
      expect(_sunRect(tester).center, start);
      expect(find.text('First tip'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sky-loader-sun')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('sky-loader-sparkles')), findsNothing);

      await _unmount(tester);
    });

    testWidgets('turning reduced motion on while showing stops the motion', (tester) async {
      Widget app(bool reduce) =>
          _host(const SkyLoader(message: 'Loading', tips: _tips), reduceMotion: reduce);

      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();

      final frozen = _sunRect(tester).center;
      await tester.pump(const Duration(seconds: 5));
      expect(_sunRect(tester).center, frozen);

      await _unmount(tester);
    });

    testWidgets('a height gives a card of that height; none fills the space', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 360,
        child: SkyLoader(message: 'Loading', tips: _tips, height: 300),
      )));
      expect(tester.getSize(find.byType(SkyLoader)).height, 300);

      await tester.pumpWidget(_host(const SizedBox(
        width: 360,
        height: 520,
        child: SkyLoader(message: 'Loading', tips: _tips, height: null),
      )));
      expect(tester.getSize(find.byType(SkyLoader)).height, 520);

      await _unmount(tester);
    });

    testWidgets('the wordmark only shows when asked for', (tester) async {
      await tester.pumpWidget(_host(const SkyLoader(message: 'Loading', tips: _tips)));
      expect(find.text('Vesper'), findsNothing);

      await tester.pumpWidget(
          _host(const SkyLoader(message: 'Loading', tips: _tips, showWordmark: true)));
      expect(find.text('Vesper'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('disposes its timer and tickers when removed', (tester) async {
      await tester.pumpWidget(_host(const SkyLoader(message: 'Loading', tips: _tips)));
      await tester.pump(const Duration(seconds: 1));

      await _unmount(tester);
      // Time passing afterwards must not throw (a leaked timer would call
      // setState on a disposed State).
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });
  });

  group('screens show the loader while they work', () {
    testWidgets('best date: the whole screen becomes the loader, then the result', (tester) async {
      final api = _SlowApi();
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: BestDateScreen(apiClient: api),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with saved preferences'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkyLoader), findsOneWidget);
      expect(find.text('Looking at the next 7 days'), findsOneWidget);
      expect(find.text('Vesper'), findsOneWidget); // full-screen variant has the wordmark
      expect(find.text('Your sky taste'), findsNothing); // the form is out of the way

      api.bestDate.complete(_response);
      await tester.pumpAndSettle();

      expect(find.byType(SkyLoader), findsNothing);
      expect(find.text('Your best sky'), findsOneWidget);
    });

    testWidgets('best date: a failure brings the form back with the error', (tester) async {
      final api = _SlowApi();
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: BestDateScreen(apiClient: api),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with saved preferences'));
      await tester.pump();
      expect(find.byType(SkyLoader), findsOneWidget);

      api.bestDate.completeError(ApiException('Weather data is temporarily unavailable.'));
      await tester.pumpAndSettle();

      expect(find.byType(SkyLoader), findsNothing);
      expect(find.text('Weather data is temporarily unavailable.'), findsOneWidget);
      expect(find.text('Continue with saved preferences'), findsOneWidget);
    });

    testWidgets('todays sky: loader under the form until the sky arrives', (tester) async {
      final api = _SlowApi();
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: TodaySkyScreen(apiClient: api),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Show today's sky"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkyLoader), findsOneWidget);
      expect(find.text('Reading the sky'), findsWidgets);
      expect(find.text('Where are you looking?'), findsOneWidget); // form still there

      api.sky.complete(_sky);
      api.session.complete(const SessionResponse(recommendations: []));
      await tester.pumpAndSettle();

      expect(find.byType(SkyLoader), findsNothing);
      expect(find.text('Expected sky'), findsOneWidget);
    });

    testWidgets('viewing spots: loader under the button, then the list', (tester) async {
      final api = _SlowApi();
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: NearbySpotsScreen(apiClient: api),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find viewing spots'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkyLoader), findsOneWidget);
      expect(find.text('Finding viewing spots'), findsOneWidget);

      api.spots.complete(const [
        NearbySpot(
          id: 'o1',
          name: 'Brighton Beach',
          type: LocationType.beach,
          lat: 1,
          lon: 2,
          distanceKm: 3.2,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(SkyLoader), findsNothing);
      expect(find.text('Brighton Beach'), findsOneWidget);
    });
  });
}

const _home = PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn Bridge Park');

const _sky = SkyForecast(
  event: SunEvent.sunset,
  eventTime: '2026-10-08T18:03:00-04:00',
  eventPassed: false,
  recommendedArrivalOffsetMinutes: -20,
  bestViewingWindowStart: '2026-10-08T17:43:00-04:00',
  bestViewingWindowEnd: '2026-10-08T18:23:00-04:00',
  visibilityLikelihood: 0.9,
  cloudCoverSummary: 'light cloud cover',
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
  leadDays: 0,
  confidence: Confidence.high,
);

final _response = BestDateResponse(
  days: [DayScore(date: DateTime(2026, 10, 8), score: 0.84, confidence: Confidence.high, spotName: null)],
  best: BestDay(date: DateTime(2026, 10, 8), spot: null, sky: _sky),
  spotsConsidered: 0,
);

/// An API whose slow calls stay pending until the test completes them.
class _SlowApi extends ApiClient {
  final bestDate = Completer<BestDateResponse>();
  final sky = Completer<SkyForecast>();
  final session = Completer<SessionResponse>();
  final spots = Completer<List<NearbySpot>>();

  @override
  Future<UserPreferences?> fetchPreferences() async => const UserPreferences(
        home: _home,
        preferences: PreferenceProfile(goldenOrange: 0.9),
      );

  @override
  Future<BestDateResponse> fetchBestDate(BestDateRequest request) => bestDate.future;

  @override
  Future<SkyForecast> fetchSky(SkyRequest request) => sky.future;

  @override
  Future<SessionResponse> fetchSession(SessionRequest request) => session.future;

  @override
  Future<List<NearbySpot>> fetchNearbySpots({
    required double lat,
    required double lon,
    required double radiusKm,
    List<LocationType> placeTypes = const [],
  }) =>
      spots.future;
}
