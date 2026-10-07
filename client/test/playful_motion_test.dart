import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/saved_date.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/theme/app_motion.dart';
import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/utils/day_phase.dart';
import 'package:vesper/utils/haptics.dart';
import 'package:vesper/widgets/save_date_button.dart';
import 'package:vesper/widgets/saved_dates_calendar.dart';
import 'package:vesper/widgets/sky_header.dart';
import 'package:vesper/widgets/sky_loader.dart';
import 'package:vesper/widgets/star_rating.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: home)),
    );

const _settled = Duration(seconds: 3);

/// Records the haptic taps the app asks the platform for.
class _Haptics {
  final List<String> taps = [];

  _Haptics(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'HapticFeedback.vibrate') taps.add(call.arguments as String);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

class _FakeApi extends ApiClient {
  Completer<SavedDate>? pending;
  Object? error;

  @override
  Future<SavedDate> createSavedDate(SavedDateRequest request) {
    if (pending != null) return pending!.future;
    if (error != null) return Future.error(error!);
    return Future.value(_saved(request));
  }
}

SavedDate _saved(SavedDateRequest r) => SavedDate(
      id: 'new',
      eventDate: r.eventDate,
      event: r.event,
      lat: r.lat,
      lon: r.lon,
      label: r.label,
      savedScore: r.savedScore,
      notificationEnabled: true,
    );

void main() {
  group('AppHaptics', () {
    testWidgets('tap is a light impact, select is a selection click', (tester) async {
      final haptics = _Haptics(tester);

      AppHaptics.tap();
      AppHaptics.select();
      await tester.pump();

      expect(haptics.taps, ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.selectionClick']);
    });

    testWidgets('a platform that refuses is silently ignored', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => throw PlatformException(code: 'unsupported'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      AppHaptics.tap();
      AppHaptics.select();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('StarRating', () {
    Widget stars(ValueChanged<int> onChanged, {int value = 0, bool reduce = false}) =>
        _app(StarRating(value: value, onChanged: onChanged), reduceMotion: reduce);

    double scaleOf(WidgetTester tester, int star) {
      return tester
          .widget<Transform>(find.byKey(Key('rate-scale-$star')))
          .transform
          .getMaxScaleOnAxis();
    }

    testWidgets('choosing a star reports it and gives a selection tick', (tester) async {
      final haptics = _Haptics(tester);
      int? chosen;
      await tester.pumpWidget(stars((s) => chosen = s));

      await tester.tap(find.byKey(const Key('rate-4')));
      await tester.pump();

      expect(chosen, 4);
      expect(haptics.taps, ['HapticFeedbackType.selectionClick']);
      await tester.pump(_settled);
    });

    testWidgets('the stars up to the one chosen pop in a wave', (tester) async {
      await tester.pumpWidget(stars((_) {}, value: 3));
      await tester.tap(find.byKey(const Key('rate-3')));
      await tester.pump(); // the animation clock starts on its first frame

      // Star 1 pops first; stars 4 and 5 are not part of the wave at all.
      await tester.pump(const Duration(milliseconds: 120));
      expect(scaleOf(tester, 1), greaterThan(1.05));
      expect(scaleOf(tester, 4), 1);
      expect(scaleOf(tester, 5), 1);

      // Later, star 3 is the one popping and star 1 has settled.
      await tester.pump(const Duration(milliseconds: 250));
      expect(scaleOf(tester, 3), greaterThan(1.05));
      expect(scaleOf(tester, 1), lessThan(1.1));

      await tester.pump(_settled);
      for (var star = 1; star <= 5; star++) {
        expect(scaleOf(tester, star), closeTo(1, 0.001), reason: 'star $star');
      }
    });

    testWidgets('filled stars warm along the spectrum', (tester) async {
      await tester.pumpWidget(stars((_) {}, value: 4));
      await tester.pump(_settled);

      Color colourOf(int star) => tester
          .widget<Icon>(find.descendant(of: find.byKey(Key('rate-$star')), matching: find.byType(Icon)))
          .color!;

      expect(colourOf(1), AppColors.spectrumAt(0.35));
      expect(colourOf(4), AppColors.spectrumAt(0.65));
      expect(colourOf(1), isNot(colourOf(4)));
      expect(
        find.descendant(of: find.byKey(const Key('rate-5')), matching: find.byIcon(Icons.star_border)),
        findsOneWidget,
      );
    });

    testWidgets('reduced motion: no wave, but the choice and the tap still happen',
        (tester) async {
      final haptics = _Haptics(tester);
      int? chosen;
      await tester.pumpWidget(stars((s) => chosen = s, reduce: true));

      await tester.tap(find.byKey(const Key('rate-2')));
      await tester.pump(const Duration(milliseconds: 150));

      expect(chosen, 2);
      expect(scaleOf(tester, 1), 1);
      expect(scaleOf(tester, 2), 1);
      expect(haptics.taps, hasLength(1));
      await tester.pumpAndSettle();
    });
  });

  group('SaveDateButton', () {
    Widget button(_FakeApi api, {bool reduce = false}) => _app(
          Padding(
            padding: const EdgeInsets.all(16),
            child: SaveDateButton(
              eventDate: DateTime(2026, 10, 8),
              event: SunEvent.sunset,
              lat: 40.7,
              lon: -73.99,
              label: 'Brooklyn Bridge Park',
              apiClient: api,
              getFcmToken: () async => 'token',
            ),
          ),
          reduceMotion: reduce,
        );

    double width(WidgetTester tester) => tester
        .getSize(find.descendant(
          of: find.byType(SaveDateButton),
          matching: find.byType(AnimatedContainer),
        ))
        .width;

    testWidgets('shrinks into a tick circle when the save works', (tester) async {
      final haptics = _Haptics(tester);
      await tester.pumpWidget(button(_FakeApi()));
      final full = width(tester);
      expect(full, greaterThan(200));
      expect(find.byKey(const Key('save-tick')), findsNothing);

      await tester.tap(find.text('Save this date'));
      await tester.pump(); // request resolves
      await tester.pump(const Duration(milliseconds: 150));
      final midway = width(tester);
      expect(midway, lessThan(full));
      expect(midway, greaterThan(52));

      await tester.pump(_settled);
      expect(width(tester), 52);
      expect(find.byKey(const Key('save-tick')), findsOneWidget);
      expect(find.text("Saved — we'll remind you the day before"), findsOneWidget);
      expect(haptics.taps, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('throws sparkles when saved, and they clear away', (tester) async {
      await tester.pumpWidget(button(_FakeApi()));
      expect(find.byKey(const Key('save-sparkles')), findsNothing);

      await tester.tap(find.text('Save this date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('save-sparkles')), findsOneWidget);

      await tester.pump(_settled);
      expect(find.byKey(const Key('save-sparkles')), findsNothing);
    });

    testWidgets('shows a spinner while saving and stays full width', (tester) async {
      final api = _FakeApi()..pending = Completer<SavedDate>();
      await tester.pumpWidget(button(api));
      final full = width(tester);

      await tester.tap(find.text('Save this date'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('save-spinner')), findsOneWidget);
      expect(width(tester), full);

      api.pending!.complete(_saved(SavedDateRequest(
        eventDate: DateTime(2026, 10, 8),
        event: SunEvent.sunset,
        lat: 40.7,
        lon: -73.99,
        label: 'x',
      )));
      await tester.pump(_settled);
      expect(find.byKey(const Key('save-tick')), findsOneWidget);
    });

    testWidgets('a failure keeps the button, shows the error, and gives no tap', (tester) async {
      final haptics = _Haptics(tester);
      final api = _FakeApi()..error = ApiException('You can save up to 100 dates.');
      await tester.pumpWidget(button(api));
      final full = width(tester);

      await tester.tap(find.text('Save this date'));
      await tester.pump(_settled);

      expect(find.text('You can save up to 100 dates.'), findsOneWidget);
      expect(find.text('Save this date'), findsOneWidget);
      expect(width(tester), full);
      expect(haptics.taps, isEmpty);
    });

    testWidgets('reduced motion: switches at once, no sparkles', (tester) async {
      final haptics = _Haptics(tester);
      await tester.pumpWidget(button(_FakeApi(), reduce: true));

      await tester.tap(find.text('Save this date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(width(tester), 52);
      expect(find.byKey(const Key('save-tick')), findsOneWidget);
      expect(find.byKey(const Key('save-sparkles')), findsNothing);
      expect(haptics.taps, hasLength(1)); // the tap is not motion
    });
  });

  group('SkyHeader', () {
    Widget header({bool reduce = false}) => MaterialApp(
          theme: buildAppTheme(),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: app!,
          ),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SkyHeader(phase: DayPhase.dusk, child: SizedBox.expand()),
            ),
          ),
        );

    Rect rect(WidgetTester tester, String key) => tester.getRect(find.byKey(Key(key)));

    setUp(() => AppMotion.ambientLoops = true);
    tearDown(() => AppMotion.ambientLoops = false);

    testWidgets('the sun bobs and the clouds drift', (tester) async {
      await tester.pumpWidget(header());
      final sunStart = rect(tester, 'header-sun');
      final bigCloudStart = rect(tester, 'header-cloud-0');

      await tester.pump(const Duration(milliseconds: 4500)); // top of the bob
      expect(rect(tester, 'header-sun').top, lessThan(sunStart.top - 5));
      expect(rect(tester, 'header-sun').left, sunStart.left); // only up and down
      expect(rect(tester, 'header-cloud-0').left, isNot(bigCloudStart.left));

      // Over one second, both clouds drift right and the big one is faster.
      final bigBefore = rect(tester, 'header-cloud-0').left;
      final smallBefore = rect(tester, 'header-cloud-1').left;
      await tester.pump(const Duration(seconds: 1));
      final bigSpeed = rect(tester, 'header-cloud-0').left - bigBefore;
      final smallSpeed = rect(tester, 'header-cloud-1').left - smallBefore;
      expect(smallSpeed, greaterThan(0));
      expect(bigSpeed, greaterThan(smallSpeed));

      await _unmount(tester);
    });

    testWidgets('it is a seamless loop: clouds never jump', (tester) async {
      await tester.pumpWidget(header());
      var previous = rect(tester, 'header-cloud-1').left;

      // Step through a full 90s drift cycle in 1s steps. Cloud 1 moves about
      // 5px per second; allow a loop wrap (it re-enters off-screen on the
      // left), but no other sudden jump.
      var wraps = 0;
      for (var second = 0; second < 92; second++) {
        await tester.pump(const Duration(seconds: 1));
        final now = rect(tester, 'header-cloud-1').left;
        if (now < previous) {
          wraps++;
        } else {
          expect(now - previous, lessThan(15), reason: 'jump at ${second}s');
        }
        previous = now;
      }
      expect(wraps, 1);

      await _unmount(tester);
    });

    testWidgets('clouds rest where the header has always put them when nothing moves',
        (tester) async {
      AppMotion.ambientLoops = false;
      await tester.pumpWidget(header());
      final width = tester.getSize(find.byType(SkyHeader)).width;

      expect(rect(tester, 'header-cloud-0').left, closeTo(width - 194, 0.5));
      expect(rect(tester, 'header-cloud-1').left, closeTo(width - 66, 0.5));

      final sun = rect(tester, 'header-sun');
      await tester.pump(const Duration(seconds: 5));
      expect(rect(tester, 'header-sun'), sun);
      await tester.pumpAndSettle(); // nothing is looping
    });

    testWidgets('reduced motion freezes the sky even when loops are allowed', (tester) async {
      await tester.pumpWidget(header(reduce: true));
      final sun = rect(tester, 'header-sun');
      final cloud = rect(tester, 'header-cloud-0');

      await tester.pump(const Duration(seconds: 8));

      expect(rect(tester, 'header-sun'), sun);
      expect(rect(tester, 'header-cloud-0'), cloud);
      await tester.pumpAndSettle();
    });

    testWidgets('it keeps the wordmark row on top of the moving sky', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: SkyHeader(phase: DayPhase.dawn, child: Center(child: Text('Vesper'))),
        ),
      ));

      expect(find.text('Vesper'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Vesper'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('other haptic moments', () {
    testWidgets('picking a calendar day gives a selection tick', (tester) async {
      final haptics = _Haptics(tester);
      DateTime? picked;
      await tester.pumpWidget(_app(SavedDatesCalendar(
        today: DateTime(2026, 10, 6),
        markedDates: {DateTime(2026, 10, 8)},
        selected: null,
        onSelected: (day) => picked = day,
      )));

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 10, 8))));
      await tester.pump(_settled);

      expect(picked, DateTime(2026, 10, 8));
      expect(haptics.taps, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('poking the loader sun gives a light tap', (tester) async {
      final haptics = _Haptics(tester);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: SkyLoader(message: 'Loading')),
      ));

      await tester.tap(find.byKey(const Key('sky-loader-sun')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(haptics.taps, ['HapticFeedbackType.lightImpact']);
      await tester.pump(const Duration(seconds: 1));
      await _unmount(tester);
    });

    testWidgets('reduced motion leaves the loader sun still and silent', (tester) async {
      final haptics = _Haptics(tester);
      await tester.pumpWidget(_app(const SkyLoader(message: 'Loading'), reduceMotion: true));

      await tester.tap(find.byKey(const Key('sky-loader-sun')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(haptics.taps, isEmpty);
      await _unmount(tester);
    });
  });
}
