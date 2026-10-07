import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/best_date_screen.dart';
import 'package:vesper/screens/home_screen.dart';
import 'package:vesper/screens/nearby_spots_screen.dart';
import 'package:vesper/screens/today_sky_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/theme/app_motion.dart';
import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/theme/flows.dart';
import 'package:vesper/widgets/flow_header.dart';
import 'package:vesper/widgets/gradient_icon_disc.dart';
import 'package:vesper/widgets/rise_in.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: home,
    );

/// The page fade of the screen on top (the app's first screen has one too).
Finder get _topPageFade => find.byKey(const Key('vesper-page-fade')).last;

/// The opacity of the nearest fade around [finder] (RiseIn's own fade).
double _riseOpacity(WidgetTester tester, Finder riseIn) {
  final fade = find.descendant(of: riseIn, matching: find.byType(FadeTransition)).first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

class _QuietApi extends ApiClient {
  @override
  Future<UserPreferences?> fetchPreferences() async => null;
}

void main() {
  group('AppMotion', () {
    test('timings are short and consistent with what was promised', () {
      expect(AppMotion.pageEnter.inMilliseconds, lessThanOrEqualTo(350));
      expect(AppMotion.pageExit, lessThan(AppMotion.pageEnter));
      // A screen's whole entrance, stagger included, is about 0.4 seconds.
      expect(AppMotion.riseWorstCase.inMilliseconds, lessThanOrEqualTo(450));
      expect(AppMotion.riseMaxSteps, lessThanOrEqualTo(6));
    });
  });

  group('page transitions', () {
    Widget host({bool reduce = false}) => _app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Second page'))),
                  ),
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
          reduceMotion: reduce,
        );

    testWidgets('a new screen fades and rises in, then settles', (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.text('Go'));
      await tester.pump(); // route is built
      await tester.pump(const Duration(milliseconds: 100));

      final fade = tester.widget<FadeTransition>(_topPageFade);
      expect(fade.opacity.value, inExclusiveRange(0.0, 1.0));
      expect(find.text('Second page'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(
        tester.widget<FadeTransition>(_topPageFade).opacity.value,
        1.0,
      );
    });

    testWidgets('going back fades the screen out, and is quicker than going in', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<FadeTransition>(_topPageFade).opacity.value,
        inExclusiveRange(0.0, 1.0),
      );

      await tester.pump(AppMotion.pageExit);
      await tester.pumpAndSettle();
      expect(find.text('Second page'), findsNothing);
    });

    testWidgets('reduced motion: no fade or slide wrapper at all', (tester) async {
      await tester.pumpWidget(host(reduce: true));

      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Second page'), findsOneWidget);
      expect(find.byKey(const Key('vesper-page-fade')), findsNothing);
    });

    testWidgets('every platform uses the Vesper transition', (tester) async {
      final builders = buildAppTheme().pageTransitionsTheme.builders;

      for (final platform in TargetPlatform.values) {
        expect(builders[platform], isA<VesperPageTransitionsBuilder>(), reason: '$platform');
      }
    });
  });

  group('RiseIn', () {
    Widget stack({bool reduce = false}) => _app(
          Scaffold(
            body: Column(
              children: [
                for (final i in [0, 3, 50])
                  RiseIn(index: i, key: ValueKey('rise-$i'), child: Text('Item $i')),
              ],
            ),
          ),
          reduceMotion: reduce,
        );

    Finder rise(int i) => find.byKey(ValueKey('rise-$i'));

    testWidgets('starts invisible, ends visible', (tester) async {
      await tester.pumpWidget(stack());
      expect(_riseOpacity(tester, rise(0)), 0.0);

      await tester.pump(AppMotion.riseWorstCase + const Duration(milliseconds: 20));
      expect(_riseOpacity(tester, rise(0)), 1.0);
      expect(_riseOpacity(tester, rise(3)), 1.0);
    });

    testWidgets('items arrive one after another', (tester) async {
      await tester.pumpWidget(stack());
      await tester.pump(const Duration(milliseconds: 100));

      // Item 0 is well under way; item 3 (delayed 105ms) has barely begun.
      expect(_riseOpacity(tester, rise(0)), greaterThan(0.3));
      expect(_riseOpacity(tester, rise(3)), lessThan(_riseOpacity(tester, rise(0))));
      expect(_riseOpacity(tester, rise(3)), lessThan(0.05));

      await tester.pump(AppMotion.riseWorstCase);
    });

    testWidgets('the delay stops growing, so late items still finish promptly', (tester) async {
      await tester.pumpWidget(stack());

      await tester.pump(AppMotion.riseWorstCase + const Duration(milliseconds: 20));

      // Index 50 is capped to the same delay as index 5.
      expect(_riseOpacity(tester, rise(50)), 1.0);
    });

    testWidgets('the child is tappable from the very first frame', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(
        Scaffold(
          body: RiseIn(
            child: TextButton(onPressed: () => taps++, child: const Text('Tap me')),
          ),
        ),
      ));
      expect(_riseOpacity(tester, find.byType(RiseIn)), 0.0);

      await tester.tap(find.text('Tap me'));

      expect(taps, 1);
      await tester.pump(AppMotion.riseWorstCase);
    });

    testWidgets('it plays once and does not replay when the parent rebuilds', (tester) async {
      var counter = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(_app(
        Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            return RiseIn(child: Text('Rebuilt $counter times'));
          }),
        ),
      ));
      await tester.pump(AppMotion.riseWorstCase + const Duration(milliseconds: 20));

      rebuild(() => counter++);
      await tester.pump();

      expect(find.text('Rebuilt 1 times'), findsOneWidget);
      expect(_riseOpacity(tester, find.byType(RiseIn)), 1.0);
    });

    testWidgets('reduced motion: fully visible at once, nothing running', (tester) async {
      await tester.pumpWidget(stack(reduce: true));

      expect(_riseOpacity(tester, rise(50)), 1.0);
      // Nothing is animating, so the tree settles immediately.
      await tester.pumpAndSettle();
    });
  });

  group('hero discs', () {
    GradientIconDisc disc({Object? tag}) => GradientIconDisc(
          icon: Icons.sunny,
          from: Colors.orange,
          to: Colors.red,
          heroTag: tag,
        );

    testWidgets('a tagged disc is a hero; an untagged one is not', (tester) async {
      await tester.pumpWidget(_app(Scaffold(body: disc(tag: 'a'))));
      expect(find.byType(Hero), findsOneWidget);

      await tester.pumpWidget(_app(Scaffold(body: disc())));
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('reduced motion: no hero flight', (tester) async {
      await tester.pumpWidget(_app(Scaffold(body: disc(tag: 'a')), reduceMotion: true));

      expect(find.byType(Hero), findsNothing);
      expect(find.byType(GradientIconDisc), findsOneWidget);
    });

    test('each flow has its own hero tag', () {
      final tags = {Flows.bestDate.heroTag, Flows.todaySky.heroTag, Flows.spots.heroTag};
      expect(tags, hasLength(3));
    });
  });

  group('flow screens', () {
    testWidgets('home has a hero disc per card', (tester) async {
      await tester.pumpWidget(_app(HomeScreen(apiClient: _QuietApi())));
      await tester.pumpAndSettle();

      expect(find.byType(Hero), findsNWidgets(3));
    });

    testWidgets('each flow opens with the matching header disc', (tester) async {
      final screens = <FlowStyle, Widget>{
        Flows.bestDate: BestDateScreen(apiClient: _QuietApi()),
        Flows.todaySky: TodaySkyScreen(apiClient: _QuietApi()),
        Flows.spots: NearbySpotsScreen(apiClient: _QuietApi()),
      };

      for (final entry in screens.entries) {
        await tester.pumpWidget(_app(entry.value));
        await tester.pumpAndSettle();

        expect(find.byType(FlowHeader), findsOneWidget, reason: entry.key.id);
        expect(find.text(entry.key.subtitle), findsOneWidget, reason: entry.key.id);
        final hero = tester.widget<Hero>(find.byType(Hero));
        expect(hero.tag, entry.key.heroTag, reason: entry.key.id);
      }
    });

    testWidgets('tapping a home card opens its screen through the transition', (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(HomeScreen(apiClient: _QuietApi())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find viewing spots near me'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150)); // mid-flight
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(find.byType(NearbySpotsScreen), findsOneWidget);
      expect(find.byType(FlowHeader), findsOneWidget);
    });
  });
}
