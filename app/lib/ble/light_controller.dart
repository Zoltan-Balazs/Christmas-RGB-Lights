import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'packet.dart';

/// Same GATT UUIDs used by the ts-node controller (src/main.ts).
final Guid primaryServiceUuid = Guid('00001000-0000-1000-8000-00805f9b34fb');
final Guid primaryCharacteristicUuid = Guid(
  '00001001-0000-1000-8000-00805f9b34fb',
);

/// Advertised local name of the light strip, per the vendor Android app
/// (MainActivity's scan listener matches on this exact device name rather
/// than a service UUID: the strip doesn't put its GATT service UUID in the
/// advertisement packet, only exposes it once connected).
const String lightDeviceName = 'Light';

enum LightConnectionState { disconnected, scanning, connecting, connected }

/// Talks to the Actuel RGB light strip over BLE.
///
/// Unlike the original Linux/BlueZ script, this cannot target a device by
/// its fixed MAC address: iOS's CoreBluetooth never exposes hardware
/// addresses to apps, only per-app-installation UUIDs. Instead we scan for
/// any peripheral advertising [lightDeviceName].
class LightController {
  final _stateController = StreamController<LightConnectionState>.broadcast();
  Stream<LightConnectionState> get stateStream => _stateController.stream;
  LightConnectionState _state = LightConnectionState.disconnected;
  LightConnectionState get state => _state;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  void _setState(LightConnectionState state) {
    _state = state;
    _stateController.add(state);
  }

  /// Scans for a peripheral advertising [lightDeviceName] and connects to
  /// it. If none shows up within [timeout], throws [LightNotFoundException]
  /// carrying every device the scan actually saw -- useful as a fallback UI
  /// (see HomeScreen) in case a particular unit advertises a different name
  /// than expected.
  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == LightConnectionState.scanning ||
        _state == LightConnectionState.connecting) {
      return;
    }

    _setState(LightConnectionState.scanning);
    try {
      await FlutterBluePlus.startScan(timeout: timeout);

      final result = await FlutterBluePlus.scanResults
          .expand((results) => results)
          .firstWhere(
            (r) =>
                r.advertisementData.advName == lightDeviceName ||
                r.device.platformName == lightDeviceName,
          )
          .timeout(timeout);

      await FlutterBluePlus.stopScan();
      await connectToDevice(result.device, timeout: timeout);
    } catch (e) {
      await FlutterBluePlus.stopScan();
      _setState(LightConnectionState.disconnected);
      if (e is TimeoutException) {
        throw LightNotFoundException(FlutterBluePlus.lastScanResults);
      }
      rethrow;
    }
  }

  /// Connects directly to an already-discovered device, skipping the
  /// name-matching scan. Used for the manual picker fallback.
  Future<void> connectToDevice(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _setState(LightConnectionState.connecting);
    try {
      _device = device;

      _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected) {
          _characteristic = null;
          _setState(LightConnectionState.disconnected);
        }
      });

      await device.connect(timeout: timeout);
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid == primaryServiceUuid,
        orElse: () => throw StateError('Primary service not found on device'),
      );
      _characteristic = service.characteristics.firstWhere(
        (c) => c.uuid == primaryCharacteristicUuid,
        orElse: () =>
            throw StateError('Primary characteristic not found on device'),
      );

      _setState(LightConnectionState.connected);
    } catch (_) {
      _setState(LightConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _characteristic = null;
    _setState(LightConnectionState.disconnected);
  }

  Future<void> _write(Uint8List packet) async {
    final characteristic = _characteristic;
    if (characteristic == null) {
      throw StateError('Not connected to a light strip');
    }
    await characteristic.write(packet, withoutResponse: false);
  }

  Future<void> sendSteadyColor({
    required int red,
    required int green,
    required int blue,
  }) => _write(buildSteadyColorPacket(red: red, green: green, blue: blue));

  Future<void> sendPower(bool on) => _write(buildOnOffPacket(on));

  /// Syncs the strip's onboard clock to [time] (defaults to now), needed
  /// for the timer schedule to fire at the right times.
  Future<void> sendSyncTime([DateTime? time]) =>
      _write(buildSyncTimePacket(time ?? DateTime.now()));

  Future<void> sendUniColorEffect({
    required UniColorEffect effect,
    required int colorIndex,
  }) => _write(buildUniColorPacket(effect: effect, colorIndex: colorIndex));

  Future<void> sendMultiColorEffect(MultiColorEffect effect) =>
      _write(buildMultiColorPacket(effect));

  Future<void> sendSpeed(int level) => _write(buildSpeedPacket(level));

  Future<void> sendTimer(TimerSlot slot1, TimerSlot slot2) =>
      _write(buildTimerPacket(slot1, slot2));

  void dispose() {
    _connectionSub?.cancel();
    _stateController.close();
  }
}

/// Thrown by [LightController.connect] when no device advertising
/// [lightDeviceName] was found before the scan timed out.
class LightNotFoundException implements Exception {
  final List<ScanResult> nearbyDevices;
  LightNotFoundException(this.nearbyDevices);

  @override
  String toString() =>
      'No device advertising "$lightDeviceName" found nearby';
}
