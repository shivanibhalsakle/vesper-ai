import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/widgets/sky_detail_view.dart';
import 'package:vesper/widgets/spectrum_slider.dart';

void main() {
  group('AppColors.spectrumAt', () {
    test('starts at dawn and ends at dusk', () {
      expect(AppColors.spectrumAt(0), AppColors.spectrum.first);
      expect(AppColors.spectrumAt(1), AppColors.spectrum.last);
    });

    test('hits each stop exactly', () {
      for (var i = 0; i < AppColors.spectrum.length; i++) {
        expect(AppColors.spectrumAt(AppColors.spectrumStops[i]), AppColors.spectrum[i]);
      }
    });

    test('blends between stops', () {
      final mid = AppColors.spectrumAt(0.1); // halfway between blush and first light
      expect(mid, Color.lerp(AppColors.spectrum[0], AppColors.spectrum[1], 0.5));
    });

    test('clamps out-of-range values', () {
      expect(AppColors.spectrumAt(-3), AppColors.spectrum.first);
      expect(AppColors.spectrumAt(7), AppColors.spectrum.last);
    });

    test('stops and colours line up', () {
      expect(AppColors.spectrum.length, AppColors.spectrumStops.length);
      expect(AppColors.spectrumStops.first, 0);
      expect(AppColors.spectrumStops.last, 1);
    });
  });

  group('SpectrumSlider', () {
    testWidgets('renders and reports changes as the thumb is dragged', (tester) async {
      var value = 0.2;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(16),
              child: SpectrumSlider(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      ));

      expect(find.byType(Slider), findsOneWidget);
      // The slider is the thick, spectrum-painted one.
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, 10);

      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(value, 1.0);
    });

    testWidgets('uses a thicker track than the default slider', (tester) async {
      late SliderThemeData used;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SpectrumSlider(value: 0.5, onChanged: (_) {}),
        ),
      ));
      used = SliderTheme.of(tester.element(find.byType(Slider)));

      expect(used.trackHeight, 14);
      expect(buildAppTheme().sliderTheme.trackHeight, lessThan(14));
    });
  });

  group('LevelBar', () {
    Future<void> pump(WidgetTester tester, {double level = 0.6, double? wanted}) {
      return tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LevelBar(label: 'Golden', level: level, wanted: wanted),
          ),
        ),
      ));
    }

    testWidgets('shows a sun where the user wants it', (tester) async {
      await pump(tester, wanted: 0.9);

      expect(find.byKey(const Key('preference-marker')), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('no sun without a preference', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('preference-marker')), findsNothing);

      await pump(tester, wanted: 0);
      expect(find.byKey(const Key('preference-marker')), findsNothing);
    });

    testWidgets('the sun stays inside the bar at both extremes', (tester) async {
      for (final wanted in [0.01, 1.0]) {
        await pump(tester, wanted: wanted);
        final bar = tester.getRect(find.byType(LevelBar));
        final sun = tester.getRect(find.byKey(const Key('preference-marker')));

        expect(sun.left, greaterThanOrEqualTo(bar.left - 2.5), reason: 'wanted=$wanted');
        expect(sun.right, lessThanOrEqualTo(bar.right + 2.5), reason: 'wanted=$wanted');
      }
    });
  });
}
