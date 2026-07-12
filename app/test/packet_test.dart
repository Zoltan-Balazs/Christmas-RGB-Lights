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
}
