import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/utils/sun_times.dart';

// Reference values come from the backend's astronomy library (astral), asked
// for the local calendar day in each city's own timezone, in UTC.
class _Case {
  final String name;
  final double lat;
  final double lon;
  final DateTime date;
  final String sunrise;
  final String sunset;

  const _Case(this.name, this.lat, this.lon, this.date, this.sunrise, this.sunset);
}

final _cases = [
  _Case('New York, autumn', 40.7128, -74.0060, DateTime(2026, 10, 6),
      '2026-10-06T10:57:58Z', '2026-10-06T22:29:32Z'),
  _Case('Los Angeles (sunset falls on the next UTC day)', 34.0522, -118.2437,
      DateTime(2026, 10, 6), '2026-10-06T13:51:30Z', '2026-10-07T01:29:58Z'),
  _Case('Tokyo (sunrise falls on the previous UTC day)', 35.6762, 139.6503,
      DateTime(2026, 10, 6), '2026-10-05T20:40:09Z', '2026-10-06T08:18:33Z'),
  _Case('London, midsummer', 51.5074, -0.1278, DateTime(2026, 6, 21),
      '2026-06-21T03:43:27Z', '2026-06-21T20:21:12Z'),
  _Case('Sydney, southern summer', -33.8688, 151.2093, DateTime(2026, 12, 21),
      '2026-12-20T18:40:53Z', '2026-12-21T09:05:11Z'),
  _Case('Washington DC, midwinter', 38.9072, -77.0369, DateTime(2026, 1, 15),
      '2026-01-15T12:25:26Z', '2026-01-15T22:10:06Z'),
];

void main() {
  group('sunTimesFor matches the backend to within two minutes', () {
    for (final c in _cases) {
      test(c.name, () {
        final times = sunTimesFor(lat: c.lat, lon: c.lon, date: c.date)!;

        final riseError = times.sunrise.difference(DateTime.parse(c.sunrise)).inSeconds.abs();
        final setError = times.sunset.difference(DateTime.parse(c.sunset)).inSeconds.abs();

        expect(riseError, lessThanOrEqualTo(120), reason: 'sunrise off by ${riseError}s');
        expect(setError, lessThanOrEqualTo(120), reason: 'sunset off by ${setError}s');
        expect(times.sunrise.isUtc, isTrue);
      });
    }
  });

  test('the sun sets after it rises, and days are longer in summer', () {
    final summer = sunTimesFor(lat: 51.5, lon: -0.13, date: DateTime(2026, 6, 21))!;
    final winter = sunTimesFor(lat: 51.5, lon: -0.13, date: DateTime(2026, 12, 21))!;

    expect(summer.sunset.isAfter(summer.sunrise), isTrue);
    expect(
      summer.sunset.difference(summer.sunrise),
      greaterThan(winter.sunset.difference(winter.sunrise)),
    );
  });

  test('polar day and polar night have no sunrise or sunset', () {
    expect(sunTimesFor(lat: 78.2, lon: 15.6, date: DateTime(2026, 6, 21)), isNull); // Svalbard
    expect(sunTimesFor(lat: 78.2, lon: 15.6, date: DateTime(2026, 12, 21)), isNull);
  });

  group('progressAt', () {
    final times = SunTimes(
      sunrise: DateTime.utc(2026, 10, 6, 10),
      sunset: DateTime.utc(2026, 10, 6, 22),
    );

    test('runs from sunrise to sunset', () {
      expect(times.progressAt(DateTime.utc(2026, 10, 6, 10)), 0);
      expect(times.progressAt(DateTime.utc(2026, 10, 6, 16)), 0.5);
      expect(times.progressAt(DateTime.utc(2026, 10, 6, 22)), 1);
    });

    test('is clamped at night', () {
      expect(times.progressAt(DateTime.utc(2026, 10, 6, 5)), 0);
      expect(times.progressAt(DateTime.utc(2026, 10, 7, 2)), 1);
    });
  });
}
