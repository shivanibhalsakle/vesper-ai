import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/screens/home_screen.dart';

void main() {
  testWidgets('Home shows the three options and the top-bar menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Pick me a pretty sky'), findsOneWidget);
    expect(find.text('How will the sky look today?'), findsOneWidget);
    expect(find.text('Find viewing spots near me'), findsOneWidget);

    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Saved'), findsOneWidget);
  });

  testWidgets('Tapping an option opens its screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('How will the sky look today?'));
    await tester.pumpAndSettle();

    expect(find.text("Today's sky"), findsOneWidget);
    expect(find.text('Where are you looking?'), findsOneWidget);
  });

  testWidgets('Profile menu opens the profile screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();

    // No backend in this test, so it lands on the load-error state - what
    // matters here is that the menu leads to the real profile screen.
    expect(find.text('Profile'), findsOneWidget);
    expect(find.textContaining('Could not load your profile'), findsOneWidget);
  });
}
