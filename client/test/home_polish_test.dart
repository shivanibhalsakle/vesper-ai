import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/best_date.dart';
import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/saved_date.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/sky_forecast.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/models/user_profile.dart';
import 'package:vesper/screens/home_screen.dart';
import 'package:vesper/screens/saved_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/utils/day_phase.dart';
import 'package:vesper/widgets/gradient_icon_disc.dart';
import 'package:vesper/widgets/saved_dates_calendar.dart';
import 'package:vesper/widgets/score_ring.dart';
import 'package:vesper/widgets/sun_arc.dart';
import 'package:vesper/widgets/week_chart.dart';

const _home = PickedLocation(lat: 40.7128, lon: -74.0060, label: 'Brooklyn Bridge Park');

class _Api extends ApiClient {
  UserProfile? profile;
  UserPreferences? preferences;
  bool failProfile = false;
  List<SavedDate> saved = const [];

  _Api({this.profile, this.preferences});

  @override
  Future<UserProfile?> fetchProfile() async {
    if (failProfile) throw ApiException('down');
    return profile;
  }

  @override
  Future<UserPreferences?> fetchPreferences() async => preferences;

  @override
  Future<List<SavedDate>> fetchSavedDates() async => saved;
}

Future<void> _pumpHome(
  WidgetTester tester,
  _Api api,
  DateTime now, {
  AccountInfo account = const AccountInfo(),
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: HomeScreen(account: account, apiClient: api, now: now),
  ));
  await tester.pumpAndSettle();
}

SavedDate _saved(String id, DateTime date, SunEvent event, double? score) => SavedDate(
      id: id,
      eventDate: date,
      event: event,
      lat: 1,
      lon: 2,
      label: id.toUpperCase(),
      savedScore: score,
      notificationEnabled: true,
    );

void main() {
  group('DayPhase and greeting', () {
    test('phases follow the hour', () {
      expect(DayPhase.at(DateTime(2026, 10, 6, 6)), DayPhase.dawn);
      expect(DayPhase.at(DateTime(2026, 10, 6, 12)), DayPhase.day);
      expect(DayPhase.at(DateTime(2026, 10, 6, 18)), DayPhase.dusk);
      expect(DayPhase.at(DateTime(2026, 10, 6, 23)), DayPhase.night);
      expect(DayPhase.at(DateTime(2026, 10, 6, 3)), DayPhase.night);
    });

    test('greetings follow the hour', () {
      expect(greetingFor(DateTime(2026, 10, 6, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 10, 6, 13)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 10, 6, 19)), 'Good evening');
      expect(greetingFor(DateTime(2026, 10, 6, 2)), 'Good evening');
    });

    test('every phase has a three-colour sky and an orb', () {
      for (final phase in DayPhase.values) {
        expect(phase.sky, hasLength(3));
        expect(phase.orb.a, 1.0);
      }
    });
  });

  group('HomeScreen', () {
    testWidgets('greets by time of day and by first name from the profile', (tester) async {
      final api = _Api(profile: const UserProfile(displayName: 'Shivani Bhalsakle'));
      await _pumpHome(tester, api, DateTime(2026, 10, 6, 19, 0));

      expect(find.text('Good evening, Shivani'), findsOneWidget);
    });

    testWidgets('falls back to the Google name, then to no name', (tester) async {
      final api = _Api()..failProfile = true;
      await _pumpHome(tester, api, DateTime(2026, 10, 6, 8, 0),
          account: const AccountInfo(displayName: 'Priya Rao'));
      expect(find.text('Good morning, Priya'), findsOneWidget);

      await _pumpHome(tester, _Api(), DateTime(2026, 10, 6, 14, 0));
      expect(find.text('Good afternoon'), findsOneWidget);
    });

    testWidgets('shows the three actions with the menu on the sky', (tester) async {
      await _pumpHome(tester, _Api(), DateTime(2026, 10, 6, 12, 0));

      expect(find.text('Pick me a pretty sky'), findsOneWidget);
      expect(find.text('How will the sky look today?'), findsOneWidget);
      expect(find.text('Find viewing spots near me'), findsOneWidget);
      expect(find.byTooltip('Profile'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('Saved'), findsOneWidget);
      expect(find.byType(GradientIconDisc), findsNWidgets(3));
      expect(find.text('Vesper'), findsOneWidget);
    });

    testWidgets('with a home spot, counts down to sunset', (tester) async {
      final api = _Api(preferences: const UserPreferences(home: _home));
      // 19:00Z is mid-afternoon in New York; sunset is at about 22:29Z.
      await _pumpHome(tester, api, DateTime.utc(2026, 10, 6, 19, 0));

      expect(find.byKey(const Key('sun-card')), findsOneWidget);
      // About 3h30m; the on-device sun maths is good to roughly two minutes.
      final countdown = RegExp(r'^3h (2[7-9]|3[0-3])m until sunset$');
      expect(
        find.byWidgetPredicate((w) => w is Text && countdown.hasMatch(w.data ?? '')),
        findsOneWidget,
      );
      expect(find.text('Brooklyn Bridge Park'), findsOneWidget);
      expect(find.byType(SunArc), findsOneWidget);
    });

    testWidgets('after dark, counts down to sunrise', (tester) async {
      final api = _Api(preferences: const UserPreferences(home: _home));
      await _pumpHome(tester, api, DateTime.utc(2026, 10, 7, 2, 0));

      expect(find.textContaining('Sunrise in'), findsOneWidget);
      expect(find.textContaining('until sunset'), findsNothing);
    });

    testWidgets('without a home spot there is no sun card', (tester) async {
      await _pumpHome(
          tester, _Api(preferences: const UserPreferences()), DateTime(2026, 10, 6, 12));

      expect(find.byKey(const Key('sun-card')), findsNothing);
    });
  });

  group('ScoreRing', () {
    testWidgets('shows the percentage and a spoken label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: ScoreRing(score: 0.84))),
      ));

      final handle = tester.ensureSemantics();
      expect(find.text('84%'), findsOneWidget);
      expect(find.bySemanticsLabel('84% match'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('clamps wild scores', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Column(children: [ScoreRing(score: 1.7), ScoreRing(score: -1)]),
        ),
      ));

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });
  });

  group('WeekChart', () {
    List<DayScore> days() => [
          for (var i = 0; i < 7; i++)
            DayScore(
              date: DateTime(2026, 10, 6 + i),
              score: [0.41, 0.55, 0.84, 0.62, 0.3, 0.48, 0.7][i],
              confidence: Confidence.high,
              spotName: null,
            ),
        ];

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: WeekChart(days: days(), bestDate: DateTime(2026, 10, 8)),
            ),
          ),
        ));

    testWidgets('draws a bar per day and marks the best one', (tester) async {
      await pump(tester);

      expect(find.text('84%'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.byKey(const Key('best-day-tile')), findsOneWidget);
    });

    testWidgets('higher scores draw taller bars', (tester) async {
      await pump(tester);

      double barHeight(String percentText) {
        final column =
            find.ancestor(of: find.text(percentText), matching: find.byType(Column)).first;
        final box = find.descendant(of: column, matching: find.byType(Container)).first;
        return tester.getSize(box).height;
      }

      expect(barHeight('84%'), greaterThan(barHeight('55%')));
      expect(barHeight('55%'), greaterThan(barHeight('30%')));
    });
  });

  group('SunArc', () {
    testWidgets('paints with and without a sun or highlight', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            SunArc(),
            SunArc(progress: 0.5),
            SunArc(highlight: (0.8, 0.96)),
            SunArc(progress: 1, highlight: (0.04, 0.2), dotColor: Colors.grey),
          ]),
        ),
      ));

      expect(find.byType(SunArc), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });

  group('Saved calendar and cards', () {
    testWidgets('dots take the spectrum colour of each days best score', (tester) async {
      final api = _Api()
        ..saved = [
          _saved('a', DateTime(2026, 10, 8), SunEvent.sunset, 0.3),
          _saved('b', DateTime(2026, 10, 8), SunEvent.sunrise, 0.9),
          _saved('c', DateTime(2026, 10, 12), SunEvent.sunset, null),
        ];
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: SavedScreen(apiClient: api, today: DateTime(2026, 10, 6)),
      ));
      await tester.pumpAndSettle();

      Color dotIn(DateTime day) {
        final dot = find.descendant(
          of: find.byKey(calendarDayKey(day)),
          matching: find.byKey(const Key('saved-dot')),
        );
        final box = tester.widget<Container>(dot).decoration as BoxDecoration;
        return box.color!;
      }

      // Two saves on the 8th: the better score (0.9) wins.
      expect(dotIn(DateTime(2026, 10, 8)), AppColors.spectrumAt(0.9));
      // No score: the primary colour.
      expect(dotIn(DateTime(2026, 10, 12)), buildAppTheme().colorScheme.primary);
      // And each card carries a gradient disc.
      expect(find.byType(GradientIconDisc), findsNWidgets(3));
    });
  });
}
