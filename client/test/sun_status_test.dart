import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/utils/sun_times.dart';

// New York on 6 Oct 2026: sunrise 10:57:58Z, sunset 22:29:32Z (from astral).
const _lat = 40.7128;
const _lon = -74.0060;

void main() {
  group('sunStatusAt', () {
    test('midday: the sun is up, partway across, and sets next', () {
      final status =
          sunStatusAt(lat: _lat, lon: _lon, now: DateTime.utc(2026, 10, 6, 16, 43))!;

      expect(status.isDay, isTrue);
      expect(status.nextIsSunset, isTrue);
      expect(status.progress, closeTo(0.5, 0.03));
      expect(status.untilNext.inMinutes, closeTo(350, 3)); // about 5h50m to 22:29
    });

    test('afternoon: a few hours before sunset', () {
      final status = sunStatusAt(lat: _lat, lon: _lon, now: DateTime.utc(2026, 10, 6, 19, 0))!;

      expect(status.isDay, isTrue);
      expect(status.untilNext.inMinutes, closeTo(209, 3)); // 3h29m
      expect(status.progress, greaterThan(0.6));
    });

    test('after dark: night, sun on the sunset horizon, sunrise next', () {
      final status = sunStatusAt(lat: _lat, lon: _lon, now: DateTime.utc(2026, 10, 7, 2, 0))!;

      expect(status.isDay, isFalse);
      expect(status.progress, 1);
      expect(status.nextIsSunset, isFalse);
      expect(status.untilNext.inMinutes, closeTo(540, 4)); // about 9h to 11:00
    });

    test('before dawn: night, sun on the sunrise horizon', () {
      final status = sunStatusAt(lat: _lat, lon: _lon, now: DateTime.utc(2026, 10, 6, 8, 0))!;

      expect(status.isDay, isFalse);
      expect(status.progress, 0);
      expect(status.nextIsSunset, isFalse);
    });

    test('works for places whose local day straddles the UTC date line', () {
      // Tokyo, 06:00 local on 6 Oct = 21:00Z on 5 Oct: after the 20:40Z sunrise.
      final tokyo =
          sunStatusAt(lat: 35.6762, lon: 139.6503, now: DateTime.utc(2026, 10, 5, 21, 0))!;
      expect(tokyo.isDay, isTrue);
      expect(tokyo.nextIsSunset, isTrue);

      // Los Angeles, 20:00 local on 6 Oct = 03:00Z on 7 Oct: after the 01:29Z sunset.
      final la =
          sunStatusAt(lat: 34.0522, lon: -118.2437, now: DateTime.utc(2026, 10, 7, 3, 0))!;
      expect(la.isDay, isFalse);
      expect(la.nextIsSunset, isFalse);
    });

    test('accepts a local DateTime (it is converted to UTC)', () {
      final instant = DateTime.utc(2026, 10, 6, 19, 0);
      final fromUtc = sunStatusAt(lat: _lat, lon: _lon, now: instant)!;
      final fromLocal = sunStatusAt(lat: _lat, lon: _lon, now: instant.toLocal())!;

      expect(fromLocal.untilNext, fromUtc.untilNext);
    });

    test('polar regions have no status', () {
      expect(sunStatusAt(lat: 78.2, lon: 15.6, now: DateTime.utc(2026, 6, 21, 12)), isNull);
    });
  });
}
