import 'package:flutter_test/flutter_test.dart';

import 'package:christmas_light/sun/solar.dart';

void main() {
  test('calculateSunTimes matches published sunrise/sunset within a few minutes', () {
    // Reference: api.sunrise-sunset.org for Budapest (47.4979, 19.0402) on
    // 2026-08-25 -- sunrise 03:51:44 UTC, sunset 17:40:10 UTC. The formulas
    // used here are a low-precision approximation (no nutation/aberration
    // correction), so allow a few minutes of slack.
    final times = calculateSunTimes(
      latitude: 47.4979,
      longitude: 19.0402,
      date: DateTime.utc(2026, 8, 25, 12),
    );

    final sunrise = times.sunrise!.toUtc();
    final sunset = times.sunset!.toUtc();
    final expectedSunrise = DateTime.utc(2026, 8, 25, 3, 51, 44);
    final expectedSunset = DateTime.utc(2026, 8, 25, 17, 40, 10);

    expect(
      sunrise.difference(expectedSunrise).inSeconds.abs(),
      lessThan(5 * 60),
    );
    expect(
      sunset.difference(expectedSunset).inSeconds.abs(),
      lessThan(5 * 60),
    );
  });

  test('calculateSunTimes returns null sunrise/sunset during polar night', () {
    // Longyearbyen, Svalbard in January: the sun does not rise.
    final times = calculateSunTimes(
      latitude: 78.2232,
      longitude: 15.6267,
      date: DateTime.utc(2026, 1, 5, 12),
    );

    expect(times.sunrise, isNull);
    expect(times.sunset, isNull);
  });
}
