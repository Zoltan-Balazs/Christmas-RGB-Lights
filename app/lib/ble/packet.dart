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

/// Uni-color effect modes (FunctionAdapter.functionGroup_0 in the vendor
/// Android app).
enum UniColorEffect { inWaves, sequential, chasingFlash, slowFade, twinkleFlash, sloGlo }

/// Multi-color effect modes (FunctionAdapter.functionGroup_1 in the vendor
/// Android app).
enum MultiColorEffect { fade, jump, strobe, slowFade, asyncFade, asyncJump, asyncSlowFade }

/// Fixed swatches the strip understands for [PacketType.uniColor]
/// (UnicolorAdapter in the vendor app). Index into this list is the byte
/// sent on the wire.
const List<int> uniColorSwatchesRgb = [
  0xFFFFFF, // W
  0xFF0000, // R
  0x00B050, // G
  0x0070CF, // B
  0xFFFF00,
  0x00CC99,
  0x990099,
];

/// One on/off slot of a two-slot daily [PacketType.timer] schedule.
class TimerSlot {
  final bool enabled;
  final int onHour;
  final int onMinute;
  final int offHour;
  final int offMinute;

  const TimerSlot({
    required this.enabled,
    required this.onHour,
    required this.onMinute,
    required this.offHour,
    required this.offMinute,
  });
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

/// NOTE: the vendor Android app halves each channel before sending
/// (`Color.red(color) / 2`, i.e. it transmits 0..127 per channel, not
/// 0..255 as this and the original ts-node controller do). Untested against
/// real hardware which convention the firmware actually expects — flagging
/// rather than silently changing this.
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

/// Syncs the strip's onboard clock, used to schedule [buildTimerPacket].
Uint8List buildSyncTimePacket(DateTime time) {
  return Uint8List.fromList([
    magicValue,
    PacketType.syncTime.index,
    time.second,
    time.minute,
    time.hour,
    time.day,
    time.month,
    time.year & 0xFF,
    (time.year >> 8) & 0xFF,
  ]);
}

/// Runs a single-color animated effect. [colorIndex] selects a swatch from
/// [uniColorSwatchesRgb].
Uint8List buildUniColorPacket({
  required UniColorEffect effect,
  required int colorIndex,
}) {
  return Uint8List.fromList([
    magicValue,
    PacketType.uniColor.index,
    effect.index,
    colorIndex,
  ]);
}

/// Runs a multi-color animated effect using the strip's built-in palette
/// for that effect (no color list is sent).
Uint8List buildMultiColorPacket(MultiColorEffect effect) {
  return Uint8List.fromList([magicValue, PacketType.multiColor.index, effect.index]);
}

/// Sets the animation speed for the current uni/multi-color effect.
/// [level] matches the vendor app's slider steps, 1 (slowest) to 5 (fastest).
Uint8List buildSpeedPacket(int level) {
  return Uint8List.fromList([magicValue, PacketType.speed.index, level]);
}

/// Sets the two daily on/off schedule slots.
Uint8List buildTimerPacket(TimerSlot slot1, TimerSlot slot2) {
  return Uint8List.fromList([
    magicValue,
    PacketType.timer.index,
    slot1.enabled ? 1 : 0,
    slot1.onHour,
    slot1.onMinute,
    slot1.offHour,
    slot1.offMinute,
    slot2.enabled ? 1 : 0,
    slot2.onHour,
    slot2.onMinute,
    slot2.offHour,
    slot2.offMinute,
  ]);
}
