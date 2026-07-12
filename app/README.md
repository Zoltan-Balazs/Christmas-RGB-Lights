# Christmas Light (Flutter)

A mobile companion to the ts-node BLE controller in the repo root, for the
Actuel-branded RGB Christmas light strip. Scans for the strip over
Bluetooth LE, lets you pick a steady color with RGB sliders, and toggle
power -- same wire packet format as `src/main.ts` (magic byte `0x3c`,
packet type, payload bytes), reimplemented in `lib/ble/packet.dart`.

Runs on Android out of the box. For iOS, see
[`ios/README-sideload.md`](ios/README-sideload.md) -- building requires a
macOS/Xcode step, but signing and installing onto your personal device can
be done entirely from NixOS.

## Dev shell

From the repo root:

```shell
devenv shell
cd app
flutter pub get
flutter test
```

## Layout

- `lib/ble/packet.dart` -- packet encoding, mirrors `src/main.ts`
- `lib/ble/light_controller.dart` -- BLE scan/connect/write via `flutter_blue_plus`
- `lib/screens/home_screen.dart` -- color picker + power toggle UI
