import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/main.dart';
import 'package:vesper/models/session_request.dart';

void main() {
  testWidgets('Session setup screen shows core inputs', (WidgetTester tester) async {
    await tester.pumpWidget(const VesperApp());

    expect(find.text('Vesper'), findsOneWidget);
    expect(find.text('Where and when?'), findsOneWidget);
    expect(find.text('Sunrise'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);
    expect(find.text('Next: sky preferences'), findsOneWidget);
  });

  testWidgets('Selecting sunrise switches the segmented control', (WidgetTester tester) async {
    await tester.pumpWidget(const VesperApp());

    await tester.tap(find.text('Sunrise'));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<SunEvent>>(
      find.byType(SegmentedButton<SunEvent>),
    );
    expect(segmentedButton.selected.first, SunEvent.sunrise);
  });
}
