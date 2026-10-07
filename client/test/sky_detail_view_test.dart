import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/models/sky_forecast.dart';
import 'package:vesper/widgets/sky_detail_view.dart';

SkyForecast _sky({double? score = 0.82, String? alert, bool passed = false, int lead = 0}) =>
    SkyForecast(
      event: SunEvent.sunrise,
      eventTime: '2026-10-06T06:58:00-04:00',
      eventPassed: passed,
      recommendedArrivalOffsetMinutes: 5,
      bestViewingWindowStart: '2026-10-06T06:48:00-04:00',
      bestViewingWindowEnd: '2026-10-06T07:33:00-04:00',
      visibilityLikelihood: 0.5,
      cloudCoverSummary: 'overcast',
      colorProbabilities:
          const ColorProbabilities(pink: 0, purple: 0, orange: 0, red: 0, golden: 0),
      skyProfile: const SkyProfile(
        clearSky: 0.1,
        dramaticClouds: 0.6,
        pinkPurple: 0.2,
        goldenOrange: 0.3,
        redSky: 0.0,
      ),
      rainOrUnsafeAlert: alert,
      preferenceMatchScore: score,
      leadDays: lead,
      confidence: lead >= 4 ? Confidence.low : Confidence.high,
    );

Future<void> _pump(WidgetTester tester, Widget view) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: view))));
}

void main() {
  testWidgets('Shows timing, conditions and the five sky bars', (tester) async {
    await _pump(tester, SkyDetailView(sky: _sky(score: null)));

    expect(find.text('Sunrise at 6:58 AM'), findsOneWidget);
    expect(find.text('Overcast'), findsOneWidget);
    expect(find.text('Dramatic clouds'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.textContaining('match with'), findsNothing);
  });

  testWidgets('Shows the match score and confidence when available', (tester) async {
    await _pump(tester, SkyDetailView(sky: _sky(lead: 5)));
    await tester.pumpAndSettle(); // the ring counts up to its score

    expect(find.text('82%'), findsOneWidget);
    expect(find.text('Low confidence · in 5 days'), findsOneWidget);
  });

  testWidgets('Rain alerts and already-happened events are called out', (tester) async {
    await _pump(
      tester,
      SkyDetailView(sky: _sky(alert: '60% chance of rain around this time.', passed: true)),
    );

    expect(find.text('60% chance of rain around this time.'), findsOneWidget);
    expect(find.text('Sunrise at 6:58 AM (already happened)'), findsOneWidget);
  });

  testWidgets('Preference markers appear only for tags the user wants', (tester) async {
    await _pump(
      tester,
      SkyDetailView(
        sky: _sky(),
        preferences: const PreferenceProfile(goldenOrange: 0.9, redSky: 0.5),
      ),
    );

    expect(find.byKey(const Key('preference-marker')), findsNWidgets(2));
    expect(find.textContaining('shows how much you want'), findsOneWidget);
  });

  testWidgets('No markers or legend without preferences', (tester) async {
    await _pump(tester, SkyDetailView(sky: _sky()));

    expect(find.byKey(const Key('preference-marker')), findsNothing);
    expect(find.textContaining('shows how much you want'), findsNothing);
  });
}
