import 'dart:math';

/// Computes local sunrise/sunset from position and date.
///
/// Pure astronomical calculation (no network/location dependency itself --
/// see sun_service.dart for wiring up the device's actual position). Uses
/// the standard low-precision solar position formulas (NOAA / "Astronomy
/// Answers" solar calculations, accurate to roughly a minute), with the
/// usual -0.833 degree horizon correction for atmospheric refraction and
/// the sun's apparent radius.
class SunTimes {
  final DateTime? sunrise;
  final DateTime? sunset;

  const SunTimes({required this.sunrise, required this.sunset});
}

const double _rad = pi / 180;
const double _dayMs = 1000 * 60 * 60 * 24;
const int _j1970 = 2440588;
const double _j2000 = 2451545;
const double _obliquity = 23.4397 * _rad;
const double _perihelion = 102.9372 * _rad;
const double _horizonAngle = -0.833 * _rad;

double _toJulian(DateTime date) =>
    date.toUtc().millisecondsSinceEpoch / _dayMs - 0.5 + _j1970;

DateTime _fromJulian(double j) => DateTime.fromMillisecondsSinceEpoch(
      ((j + 0.5 - _j1970) * _dayMs).round(),
      isUtc: true,
    ).toLocal();

double _toDays(DateTime date) => _toJulian(date) - _j2000;

double _solarMeanAnomaly(double d) => _rad * (357.5291 + 0.98560028 * d);

double _eclipticLongitude(double m) {
  final c = _rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m));
  return m + c + _perihelion + pi;
}

double _declination(double l) =>
    asin(sin(l) * sin(_obliquity));

double _julianCycle(double d, double lw) =>
    (d - 0.0009 - lw / (2 * pi)).roundToDouble();

double _approxTransit(double ht, double lw, double n) =>
    0.0009 + (ht + lw) / (2 * pi) + n;

double _solarTransitJ(double ds, double m, double l) =>
    _j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);

double? _hourAngle(double h, double phi, double d) {
  final cosH = (sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d));
  if (cosH < -1 || cosH > 1) return null; // sun never reaches this angle today
  return acos(cosH);
}

double? _setJulian(double h, double lw, double phi, double dec, double n, double m, double l) {
  final w = _hourAngle(h, phi, dec);
  if (w == null) return null;
  final a = _approxTransit(w, lw, n);
  return _solarTransitJ(a, m, l);
}

/// [latitude]/[longitude] in degrees (longitude east-positive). [date] is
/// used only for its calendar date; sunrise/sunset are computed for that
/// local day. Either field is null if the sun doesn't rise/set that day
/// (polar day/night).
SunTimes calculateSunTimes({
  required double latitude,
  required double longitude,
  required DateTime date,
}) {
  final lw = _rad * -longitude;
  final phi = _rad * latitude;
  final d = _toDays(date);

  final n = _julianCycle(d, lw);
  final ds = _approxTransit(0, lw, n);
  final m = _solarMeanAnomaly(ds);
  final l = _eclipticLongitude(m);
  final dec = _declination(l);

  final jSet = _setJulian(_horizonAngle, lw, phi, dec, n, m, l);
  final jTransit = _solarTransitJ(ds, m, l);
  final jRise = jSet == null ? null : jTransit - (jSet - jTransit);

  return SunTimes(
    sunrise: jRise == null ? null : _fromJulian(jRise),
    sunset: jSet == null ? null : _fromJulian(jSet),
  );
}
