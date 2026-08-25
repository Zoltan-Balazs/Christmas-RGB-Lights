import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'packet.dart';

/// Same GATT UUIDs used by the ts-node controller (src/main.ts).
final Guid primaryServiceUuid = Guid('00001000-0000-1000-8000-00805f9b34fb');
final Guid primaryCharacteristicUuid = Guid(
  '00001001-0000-1000-8000-00805f9b34fb',
);

enum LightConnectionState { disconnected, scanning, connecting, connected }

/// Talks to the Actuel RGB light strip over BLE.
///
/// Unlike the original Linux/BlueZ script, this cannot target a device by
/// its fixed MAC address: iOS's CoreBluetooth never exposes hardware
/// addresses to apps, only per-app-installation UUIDs. Instead we scan for
/// any peripheral advertising the strip's primary service UUID.
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

  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == LightConnectionState.scanning ||
        _state == LightConnectionState.connecting) {
      return;
    }

    _setState(LightConnectionState.scanning);
    try {
      await FlutterBluePlus.startScan(
        withServices: [primaryServiceUuid],
        timeout: timeout,
      );

      final result = await FlutterBluePlus.scanResults
          .expand((results) => results)
          .firstWhere((r) => r.advertisementData.serviceUuids.contains(
                primaryServiceUuid,
              ))
          .timeout(timeout);

      await FlutterBluePlus.stopScan();

      _setState(LightConnectionState.connecting);
      final device = result.device;
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
      await FlutterBluePlus.stopScan();
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
