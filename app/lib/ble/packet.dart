import 'dart:typed_data';

/// Mirrors the packet format in the original ts-node controller
/// (src/main.ts in the repo root): a magic byte, a packet type byte,
/// and type-specific payload bytes.
const int magicValue = 0x3c;

enum PacketType {
  syncTime,
  turnOnOff,
  steadyColor,
  uniColor,
  multiColor,
  speed,
  timer,
}

int clampByte(int value) => value.clamp(0, 255);

/// Converts a 0.0..1.0 channel value into a 0..255 byte, same rounding as
/// the original `formatColor()` helper.
int formatColorChannel(double value) => clampByte((value * 255).round());

Uint8List buildOnOffPacket(bool on) {
  return Uint8List.fromList([
    magicValue,
    PacketType.turnOnOff.index,
    on ? 1 : 0,
  ]);
}

Uint8List buildSteadyColorPacket({
  required int red,
  required int green,
  required int blue,
}) {
  return Uint8List.fromList([
    magicValue,
    PacketType.steadyColor.index,
    clampByte(red),
    clampByte(green),
    clampByte(blue),
  ]);
}
