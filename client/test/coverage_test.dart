import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/coverage.dart';
import 'package:vesper/models/geocode_result.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/widgets/location_picker.dart';

const _newYork = CoverageRegion(
  slug: 'new-york',
  name: 'New York',
  south: 40.49,
  west: -79.77,
  north: 45.02,
  east: -71.85,
);
const _texas = CoverageRegion(
  slug: 'texas',
  name: 'Texas',
  south: 25.84,
  west: -106.65,
  north: 36.5,
  east: -93.51,
);

const _brooklyn = PickedLocation(lat: 40.7, lon: -73.99, label: 'Brooklyn Bridge Park');
const _columbus = PickedLocation(lat: 39.96, lon: -83.0, label: 'Columbus, Ohio');

class _Api extends ApiClient {
  Coverage? coverage;
  List<PickedLocation> results = const [];

  @override
  Future<Coverage?> fetchCoverage() async => coverage;

  @override
  Future<List<PickedLocation>> geocode(String query) async => results;
}

Future<void> _pump(WidgetTester tester, _Api api, PickedLocation? value) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LocationPicker(value: value, onChanged: (_) {}, apiClient: api),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Coverage', () {
    test('reads the /coverage payload', () {
      final coverage = Coverage.fromJson({
        'regions': [
          {
            'slug': 'texas',
            'name': 'Texas',
            'south': 25.84,
            'west': -106.65,
            'north': 36.5,
            'east': -93.51,
          },
        ],
      });

      expect(coverage.regions.single.name, 'Texas');
      expect(coverage.covers(30.27, -97.74), isTrue); // Austin
      expect(coverage.covers(39.96, -83.0), isFalse); // Columbus
    });

    test('an empty list means unknown, never "outside"', () {
      expect(const Coverage([]).covers(40.7, -74.0), isNull);
    });

    test('summary lists a few names and counts many', () {
      expect(const Coverage([_newYork, _texas]).summary, 'New York, Texas');

      final many = Coverage([
        for (var i = 0; i < 9; i++)
          CoverageRegion(slug: 's$i', name: 'S$i', south: 0, west: 0, north: 1, east: 1),
      ]);
      expect(many.summary, '9 US states and regions');
    });
  });

  group('LocationPicker coverage note', () {
    testWidgets('shows where Vesper works under a covered place', (tester) async {
      final api = _Api()..coverage = const Coverage([_newYork, _texas]);

      await _pump(tester, api, _brooklyn);

      expect(
        find.text('Currently available in New York, Texas, with more on the way.'),
        findsOneWidget,
      );
      expect(find.textContaining("doesn't cover"), findsNothing);
    });

    testWidgets('shows the caption before any place is chosen', (tester) async {
      final api = _Api()..coverage = const Coverage([_newYork]);

      await _pump(tester, api, null);

      expect(find.textContaining('Currently available in New York'), findsOneWidget);
    });

    testWidgets('warns when the chosen place is outside coverage', (tester) async {
      final api = _Api()..coverage = const Coverage([_newYork, _texas]);

      await _pump(tester, api, _columbus);

      expect(
        find.text(
          "Vesper doesn't cover this area yet. "
          'It currently works in New York, Texas, with more on the way.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Currently available in'), findsNothing);
    });

    testWidgets('shows nothing when coverage is unknown or unreachable', (tester) async {
      await _pump(tester, _Api(), _columbus); // fetchCoverage returns null
      expect(find.textContaining('Currently available'), findsNothing);
      expect(find.textContaining("doesn't cover"), findsNothing);

      await _pump(tester, _Api()..coverage = const Coverage([]), _columbus);
      expect(find.textContaining('Currently available'), findsNothing);
      expect(find.textContaining("doesn't cover"), findsNothing);
    });

    testWidgets('marks search results that are outside coverage', (tester) async {
      final api = _Api()
        ..coverage = const Coverage([_newYork])
        ..results = const [_brooklyn, _columbus];
      await _pump(tester, api, null);

      await tester.enterText(find.byType(TextField), 'park');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Brooklyn Bridge Park'), findsOneWidget);
      expect(find.text('Columbus, Ohio'), findsOneWidget);
      expect(find.text('Outside our current coverage'), findsOneWidget);
    });
  });
}
