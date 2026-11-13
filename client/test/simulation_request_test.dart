import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/models/simulation.dart';

const _colors = ColorProbabilities(pink: 0.4, purple: 0.3, orange: 0.7, red: 0.2, golden: 0.8);

void main() {
  group('SimulationRequest', () {
    test('sends the place id and the day of the sky when it has them', () {
      final json = SimulationRequest(
        locationName: 'Brooklyn Bridge Park',
        locationType: LocationType.waterfront,
        event: SunEvent.sunset,
        placeId: 'osm:way/123',
        eventDate: DateTime(2026, 12, 3),
        cloudCoverSummary: 'light cloud cover',
        visibilityLikelihood: 0.9,
        colorProbabilities: _colors,
      ).toJson();

      expect(json['place_id'], 'osm:way/123');
      expect(json['event_date'], '2026-12-03');
    });

    test('leaves the place id out for a searched address or the current location', () {
      final json = SimulationRequest(
        locationName: 'Current location',
        event: SunEvent.sunrise,
        eventDate: DateTime(2026, 1, 9),
        cloudCoverSummary: 'overcast',
        visibilityLikelihood: 0.2,
        colorProbabilities: _colors,
      ).toJson();

      expect(json.containsKey('place_id'), isFalse);
      expect(json['event_date'], '2026-01-09'); // single digits are padded
    });

    test('still works without a date, as an older caller would send it', () {
      final json = const SimulationRequest(
        locationName: 'Somewhere',
        event: SunEvent.sunset,
        cloudCoverSummary: 'overcast',
        visibilityLikelihood: 0.2,
        colorProbabilities: _colors,
      ).toJson();

      expect(json.containsKey('event_date'), isFalse);
      expect(json.containsKey('place_id'), isFalse);
    });
  });
}
