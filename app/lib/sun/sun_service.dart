import 'package:geolocator/geolocator.dart';

import 'solar.dart';

/// Fetches the device's current location and computes today's sunrise and
/// sunset from it. The light strip's own timer only understands fixed
/// clock times (see LightController.sendTimer) -- it has no concept of
/// "sunset" -- so this is how the app turns "on at sunset" into a concrete
/// time to send.
class SunTimesService {
  Future<SunTimes> getTodaysSunTimes() async {
    final position = await _currentPosition();
    return calculateSunTimes(
      latitude: position.latitude,
      longitude: position.longitude,
      date: DateTime.now(),
    );
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are turned off');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }
}
