import 'package:flutter/material.dart';

/// The app's motion language in one place, so every animation shares the
/// same timing and so "reduce motion" is honoured everywhere the same way.
///
/// Rules this follows: motion never delays navigation or data loading (it
/// runs alongside them); a screen's entrance finishes in about 0.4 s; and
/// when the phone asks for reduced motion, content simply appears.
class AppMotion {
  const AppMotion._();

  /// A new screen sliding in, and going back out.
  static const pageEnter = Duration(milliseconds: 320);
  static const pageExit = Duration(milliseconds: 260);

  /// Content rising into place on a screen: each item takes [riseDuration],
  /// starting [riseStagger] after the one before, and the delay stops
  /// growing after [riseMaxSteps] items so a long list doesn't crawl.
  static const riseDuration = Duration(milliseconds: 250);
  static const riseStagger = Duration(milliseconds: 35);
  static const riseMaxSteps = 5;
  static const riseDistance = 16.0;

  /// Longest an item's entrance can take, delay included.
  static Duration get riseWorstCase => riseDuration + riseStagger * riseMaxSteps;

  /// Data coming alive: rings filling, arcs travelling, bars sweeping in.
  /// These play on first appearance while the numbers are already readable
  /// (labels never wait), after a short [dataDelay] so they start once their
  /// screen has mostly risen into place.
  static const dataDuration = Duration(milliseconds: 900);
  static const dataDelay = Duration(milliseconds: 150);
  static const barDuration = Duration(milliseconds: 600);
  static const barStagger = Duration(milliseconds: 70);

  static const curve = Curves.easeOutCubic;

  /// Whether endless background motion (drifting clouds, a bobbing sun) is
  /// allowed. Always on in the app; the test setup turns it off because a
  /// never-ending animation stops `pumpAndSettle` from ever settling, and a
  /// test that wants to see it switches it back on.
  static bool ambientLoops = true;

  /// Whether the user asked the system for less motion.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}

/// Screens fade in while rising a few pixels, and fade back out on the way
/// back. Calm enough to never get in the way, but the app never just
/// "pops" between screens.
class VesperPageTransitionsBuilder extends PageTransitionsBuilder {
  const VesperPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.pageEnter;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageExit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;

    return FadeTransition(
      key: const Key('vesper-page-fade'),
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(0, 0.025), end: Offset.zero)
              .chain(CurveTween(curve: AppMotion.curve)),
        ),
        child: child,
      ),
    );
  }
}
