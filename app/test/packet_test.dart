import 'package:flutter_test/flutter_test.dart';

import 'package:christmas_light/ble/packet.dart';

void main() {
  test('buildSteadyColorPacket matches the ts-node wire format', () {
    final packet = buildSteadyColorPacket(red: 255, green: 128, blue: 0);
    expect(packet, [0x3c, PacketType.steadyColor.index, 255, 128, 0]);
  });

  test('buildOnOffPacket matches the ts-node wire format', () {
    expect(buildOnOffPacket(true), [0x3c, PacketType.turnOnOff.index, 1]);
    expect(buildOnOffPacket(false), [0x3c, PacketType.turnOnOff.index, 0]);
  });

  test('formatColorChannel rounds and clamps like formatColor() in main.ts', () {
    expect(formatColorChannel(1.0), 255);
    expect(formatColorChannel(0.0), 0);
    expect(formatColorChannel(0.5), 128);
  });

  test('buildSyncTimePacket matches the vendor app wire format', () {
    final packet = buildSyncTimePacket(DateTime(2026, 12, 24, 18, 30, 5));
    expect(packet, [
      0x3c,
      PacketType.syncTime.index,
      5, // second
      30, // minute
      18, // hour
      24, // day
      12, // month
      2026 & 0xFF,
      (2026 >> 8) & 0xFF,
    ]);
  });

  test('buildUniColorPacket matches the vendor app wire format', () {
    final packet = buildUniColorPacket(
      effect: UniColorEffect.twinkleFlash,
      colorIndex: 2,
    );
    expect(packet, [0x3c, PacketType.uniColor.index, 4, 2]);
  });

  test('buildMultiColorPacket matches the vendor app wire format', () {
    final packet = buildMultiColorPacket(MultiColorEffect.asyncJump);
    expect(packet, [0x3c, PacketType.multiColor.index, 5]);
  });

  test('buildSpeedPacket matches the vendor app wire format', () {
    expect(buildSpeedPacket(3), [0x3c, PacketType.speed.index, 3]);
  });

  test('buildTimerPacket matches the vendor app wire format', () {
    final packet = buildTimerPacket(
      const TimerSlot(
        enabled: true,
        onHour: 17,
        onMinute: 0,
        offHour: 23,
        offMinute: 30,
      ),
      const TimerSlot(
        enabled: false,
        onHour: 6,
        onMinute: 15,
        offHour: 8,
        offMinute: 0,
      ),
    );
    expect(packet, [
      0x3c,
      PacketType.timer.index,
      1, 17, 0, 23, 30,
      0, 6, 15, 8, 0,
    ]);
  });
}
