import 'dart:async';

import 'package:vesper/theme/app_motion.dart';

/// Runs once for every test file in this folder.
///
/// Endless background motion (the home sky's drifting clouds and bobbing sun)
/// would keep `pumpAndSettle` from ever settling, so tests start with it off.
/// A test that wants to watch it sets `AppMotion.ambientLoops = true` itself.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppMotion.ambientLoops = false;
  await testMain();
}
