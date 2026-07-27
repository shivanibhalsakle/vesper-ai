import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/session_request.dart';
import 'package:vesper/screens/session_setup_screen.dart';

// These tests mount SessionSetupScreen directly in a minimal MaterialApp,
// not the full VesperApp — VesperApp's home is now gated by Firebase auth
// state (AuthService touches FirebaseAuth.instance), which requires
// Firebase.initializeApp() to have run. That only happens in main(), which
// these widget tests don't go through. Testing the screen in isolation
// avoids that dependency entirely, which is also just better test design:
// these tests care about SessionSetupScreen's behavior, not app-level
// auth routing.

void main() {
  testWidgets('Session setup screen shows core inputs', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SessionSetupScreen()));

    expect(find.text('Vesper'), findsOneWidget);
    expect(find.text('Where and when?'), findsOneWidget);
    expect(find.text('Sunrise'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);
    expect(find.text('Next: sky preferences'), findsOneWidget);
  });

  testWidgets('Selecting sunrise switches the segmented control', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SessionSetupScreen()));

    await tester.tap(find.text('Sunrise'));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<SunEvent>>(
      find.byType(SegmentedButton<SunEvent>),
    );
    expect(segmentedButton.selected.first, SunEvent.sunrise);
  });
}
