import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/best_date.dart';
import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/models/sky_forecast.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/home_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/theme/app_motion.dart';
import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/widgets/animated_reveal.dart';
import 'package:vesper/widgets/saved_dates_calendar.dart';
import 'package:vesper/widgets/score_ring.dart';
import 'package:vesper/widgets/sky_detail_view.dart';
import 'package:vesper/widgets/sun_arc.dart';
import 'package:vesper/widgets/week_chart.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: home)),
    );

/// Everything on a screen with animations has settled.
const _settled = Duration(seconds: 3);

void main() {
  group('AnimatedReveal', () {
    Widget probe(List<double> seen, {Duration? delay, bool reduce = false}) => _app(
          AnimatedReveal(
            delay: delay ?? const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 400),
            curve: Curves.linear,
            builder: (context, t) {
              seen.add(t);
              return Text('t=${t.toStringAsFixed(2)}');
            },
          ),
          reduceMotion: reduce,
        );

    testWidgets('holds at 0 through the delay, then runs to 1', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(probe(seen));
      expect(seen.last, 0);

      await tester.pump(const Duration(milliseconds: 150));
      expect(seen.last, 0); // still waiting

      await tester.pump(const Duration(milliseconds: 250)); // 400ms in: halfway through
      expect(seen.last, inExclusiveRange(0.3, 0.7));

      await tester.pump(const Duration(milliseconds: 400));
      expect(seen.last, 1);
    });

    testWidgets('plays once: a rebuild does not restart it', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(probe(seen));
      await tester.pump(_settled);
      seen.clear();

      await tester.pumpWidget(probe(seen));
      await tester.pump(const Duration(milliseconds: 50));

      expect(seen.every((t) => t == 1), isTrue);
    });

    testWidgets('reduced motion: 1 from the first frame and nothing running', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(probe(seen, reduce: true));

      expect(seen.first, 1);
      await tester.pumpAndSettle(); // nothing is animating
    });
  });

  group('ScoreRing', () {
    testWidgets('counts up from 0 to the score', (tester) async {
      await tester.pumpWidget(_app(const ScoreRing(score: 0.84)));
      expect(find.text('0%'), findsOneWidget);

      await tester.pump(AppMotion.dataDelay + const Duration(milliseconds: 400));
      final midway = find.byWidgetPredicate((w) {
        if (w is! Text) return false;
        final value = int.tryParse((w.data ?? '').replaceAll('%', ''));
        return value != null && value > 5 && value < 84;
      });
      expect(midway, findsOneWidget);

      await tester.pump(_settled);
      expect(find.text('84%'), findsOneWidget);
    });

    testWidgets('screen readers hear the final score immediately', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const ScoreRing(score: 0.84)));

      expect(find.bySemanticsLabel('84% match'), findsOneWidget);

      await tester.pump(_settled);
      handle.dispose();
    });

    testWidgets('reduced motion: the final number straight away', (tester) async {
      await tester.pumpWidget(_app(const ScoreRing(score: 0.84), reduceMotion: true));

      expect(find.text('84%'), findsOneWidget);
    });
  });

  group('LevelBar', () {
    Widget bars({bool reduce = false}) => _app(
          const Column(children: [
            LevelBar(index: 0, label: 'First', level: 0.5, wanted: 0.8),
            LevelBar(index: 4, label: 'Fifth', level: 0.5, wanted: 0.8),
          ]),
          reduceMotion: reduce,
        );

    double fillWidth(WidgetTester tester, String label) {
      final bar = find.ancestor(of: find.text(label), matching: find.byType(LevelBar));
      return tester.getSize(find.descendant(of: bar, matching: find.byType(ClipRRect))).width;
    }

    double sunWidth(WidgetTester tester, String label) {
      final bar = find.ancestor(of: find.text(label), matching: find.byType(LevelBar));
      final sun = find.descendant(of: bar, matching: find.byKey(const Key('preference-marker')));
      return tester.getRect(sun).width;
    }

    testWidgets('the fill sweeps in, and the percentage is there from the start', (tester) async {
      await tester.pumpWidget(bars());
      expect(fillWidth(tester, 'First'), 0);
      expect(find.text('50%'), findsNWidgets(2)); // labels never wait

      await tester.pump(AppMotion.dataDelay + const Duration(milliseconds: 300));
      final partway = fillWidth(tester, 'First');
      expect(partway, greaterThan(0));

      await tester.pump(_settled);
      final full = fillWidth(tester, 'First');
      expect(full, greaterThan(partway));
      expect(fillWidth(tester, 'Fifth'), full);
    });

    testWidgets('later bars start later', (tester) async {
      await tester.pumpWidget(bars());

      // 250ms in: the first bar is sweeping; the fifth (delayed 4 x 70ms more)
      // has not started.
      await tester.pump(const Duration(milliseconds: 250));
      expect(fillWidth(tester, 'First'), greaterThan(0));
      expect(fillWidth(tester, 'Fifth'), 0);

      await tester.pump(_settled);
    });

    testWidgets('the sun pops in near the end of the sweep', (tester) async {
      await tester.pumpWidget(bars());
      // The sweep eases out, so by 80ms it is about 40% across: not yet far
      // enough for the sun (which waits until the bar is ~65% drawn).
      await tester.pump(AppMotion.dataDelay + const Duration(milliseconds: 80));
      expect(sunWidth(tester, 'First'), 0);

      await tester.pump(_settled);
      expect(sunWidth(tester, 'First'), 24);
    });

    testWidgets('reduced motion: full bar and sun at once', (tester) async {
      await tester.pumpWidget(bars(reduce: true));

      expect(fillWidth(tester, 'First'), greaterThan(0));
      expect(sunWidth(tester, 'First'), 24);
      await tester.pumpAndSettle();
    });
  });

  group('SunArc', () {
    testWidgets('travels to its position, taking real time', (tester) async {
      await tester.pumpWidget(_app(const SunArc(progress: 0.6, highlight: (0.8, 0.96))));

      final frames = await tester.pumpAndSettle();

      // Several 100ms steps: it really animates (reduced motion takes one).
      expect(frames, greaterThan(5));
    });

    testWidgets('glides to a new position when it changes', (tester) async {
      await tester.pumpWidget(_app(const SunArc(progress: 0.2)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_app(const SunArc(progress: 0.5)));
      final frames = await tester.pumpAndSettle();

      expect(frames, greaterThan(5));
    });

    testWidgets('reduced motion: already in place', (tester) async {
      await tester.pumpWidget(
        _app(const SunArc(progress: 0.6, highlight: (0.8, 0.96)), reduceMotion: true),
      );

      final frames = await tester.pumpAndSettle();

      expect(frames, 1);
    });
  });

  group('WeekChart', () {
    final days = [
      for (var i = 0; i < 7; i++)
        DayScore(
          date: DateTime(2026, 10, 6 + i),
          score: [0.41, 0.55, 0.84, 0.62, 0.3, 0.48, 0.7][i],
          confidence: Confidence.high,
          spotName: null,
        ),
    ];

    Widget chart({bool reduce = false}) =>
        _app(WeekChart(days: days, bestDate: DateTime(2026, 10, 8)), reduceMotion: reduce);

    double bar(WidgetTester tester, int day) =>
        tester.getSize(find.byKey(Key('week-bar-$day'))).height;

    testWidgets('bars grow up from the baseline, staggered', (tester) async {
      await tester.pumpWidget(chart());
      expect(bar(tester, 6), 14); // everything starts at the minimum

      await tester.pump(const Duration(milliseconds: 420));
      expect(bar(tester, 6), greaterThan(14)); // the first has begun
      expect(bar(tester, 12), 14); // the last is still waiting (6 x 70ms later)

      await tester.pump(_settled);
      // Tallest is the best day (0.84), shortest is the 10th (0.30).
      expect(bar(tester, 8), greaterThan(bar(tester, 7)));
      expect(bar(tester, 7), greaterThan(bar(tester, 10)));
    });

    testWidgets('the chart never changes size while it animates', (tester) async {
      await tester.pumpWidget(chart());
      final before = tester.getSize(find.byType(WeekChart));

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getSize(find.byType(WeekChart)), before);

      await tester.pump(_settled);
      expect(tester.getSize(find.byType(WeekChart)), before);
    });

    testWidgets('each percentage rides on top of its bar', (tester) async {
      await tester.pumpWidget(chart());
      await tester.pump(_settled);

      final label = tester.getRect(find.text('84%'));
      final barRect = tester.getRect(find.byKey(const Key('week-bar-8')));

      expect(label.bottom, lessThanOrEqualTo(barRect.top + 1));
      expect(barRect.top - label.bottom, lessThan(12));
    });

    testWidgets('reduced motion: full-height bars at once', (tester) async {
      await tester.pumpWidget(chart(reduce: true));

      expect(bar(tester, 8), greaterThan(bar(tester, 10)));
      await tester.pumpAndSettle();
    });
  });

  group('calendar', () {
    Widget calendar({DateTime? selected, bool reduce = false}) => _app(
          SavedDatesCalendar(
            today: DateTime(2026, 10, 6),
            markedDates: {DateTime(2026, 10, 8)},
            selected: selected,
            onSelected: (_) {},
          ),
          reduceMotion: reduce,
        );

    testWidgets('saved dots pop in', (tester) async {
      await tester.pumpWidget(calendar());
      expect(tester.getRect(find.byKey(const Key('saved-dot'))).width, 0);

      await tester.pump(_settled);
      expect(tester.getRect(find.byKey(const Key('saved-dot'))).width, 5);
    });

    testWidgets('a ripple goes out from the selected day, and fades', (tester) async {
      await tester.pumpWidget(calendar());
      await tester.pump(_settled);
      expect(find.byKey(const Key('selection-ripple')), findsNothing);

      await tester.pumpWidget(calendar(selected: DateTime(2026, 10, 8)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('selection-ripple')), findsOneWidget);
      double opacity() =>
          tester.widget<Opacity>(find.descendant(of: find.byKey(const Key('selection-ripple')), matching: find.byType(Opacity))).opacity;
      final early = opacity();

      await tester.pump(const Duration(milliseconds: 400));
      expect(opacity(), lessThan(early));

      await tester.pump(_settled);
      expect(opacity(), 0);
    });

    testWidgets('clearing the selection removes the ripple', (tester) async {
      await tester.pumpWidget(calendar(selected: DateTime(2026, 10, 8)));
      await tester.pump(_settled);

      await tester.pumpWidget(calendar());
      await tester.pump(_settled);

      expect(find.byKey(const Key('selection-ripple')), findsNothing);
    });

    testWidgets('reduced motion: dots in place, no ripple', (tester) async {
      await tester.pumpWidget(calendar(selected: DateTime(2026, 10, 8), reduce: true));

      expect(tester.getRect(find.byKey(const Key('saved-dot'))).width, 5);
      expect(find.byKey(const Key('selection-ripple')), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('Home countdown ticks', () {
    const home = PickedLocation(lat: 40.7128, lon: -74.0060, label: 'Brooklyn Bridge Park');

    testWidgets('the sunset countdown moves with the clock, and the sky changes mood',
        (tester) async {
      // New York, sunset about 22:29Z.
      var now = DateTime.utc(2026, 10, 6, 19, 0);
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(apiClient: _HomeApi(home), clock: () => now),
      ));
      await tester.pumpAndSettle();

      final countdown = RegExp(r'^(\d+)h (\d+)m until sunset$');
      int minutesLeft() {
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .firstWhere(countdown.hasMatch);
        final m = countdown.firstMatch(text)!;
        return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      }

      final before = minutesLeft();

      now = now.add(const Duration(minutes: 45));
      await tester.pump(const Duration(seconds: 31)); // the next tick
      await tester.pump(const Duration(milliseconds: 50));

      expect(minutesLeft(), closeTo(before - 45, 1));

      // Stop the ticker before the test ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the greeting changes when the day moves on', (tester) async {
      var now = DateTime(2026, 10, 6, 16, 59);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(apiClient: _HomeApi(null), clock: () => now),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Good afternoon'), findsOneWidget);

      now = DateTime(2026, 10, 6, 17, 1);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Good evening'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a fixed now never ticks', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(apiClient: _HomeApi(null), now: DateTime(2026, 10, 6, 9)),
      ));
      await tester.pumpAndSettle();

      // Minutes pass and nothing is scheduled (a pending timer would fail
      // the test at the end).
      await tester.pump(const Duration(minutes: 5));
      expect(find.text('Good morning'), findsOneWidget);
    });

    testWidgets('leaving the screen stops the ticker', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(apiClient: _HomeApi(null), clock: () => DateTime(2026, 10, 6, 9)),
      ));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 3));

      expect(tester.takeException(), isNull);
    });
  });
}

class _HomeApi extends ApiClient {
  final PickedLocation? home;

  _HomeApi(this.home);

  @override
  Future<UserPreferences?> fetchPreferences() async =>
      home == null ? null : UserPreferences(home: home);
}
