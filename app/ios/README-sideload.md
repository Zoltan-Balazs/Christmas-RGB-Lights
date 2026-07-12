# Building and sideloading on iOS from NixOS

Xcode is required to compile the Flutter iOS target (`flutter build ios`
shells out to `xcodebuild`, which needs Apple's proprietary SDK/toolchain),
and Xcode only runs on macOS -- there's no NixOS-native way around that one
step. Everything else -- signing the build and installing it on your phone
-- runs fine on NixOS. The split:

1. **Build the unsigned app** (needs a real macOS host, once per release)
2. **Sign it with your own certificate** (NixOS, via `zsign`)
3. **Install it on your device** (NixOS, via `ideviceinstaller`, over USB)

Run `devenv shell` at the repo root first -- it provides `flutter`, `zsign`,
`ldid`, `libimobiledevice`, `ideviceinstaller`, and `usbmuxd`.

## 1. Build the unsigned .app

Easiest path: push to `main` (or run manually) and let
`.github/workflows/ios-unsigned-build.yml` build it on a free GitHub Actions
macOS runner. It runs `flutter build ios --release --no-codesign` and
uploads `Runner-unsigned.app.zip` as a workflow artifact. Download and
unzip it.

(If you have occasional access to any Mac, `cd app && flutter build ios
--release --no-codesign` does the same thing locally.)

## 2. Get a certificate + provisioning profile

You need an Apple Developer account (apple.com/developer, $99/yr) -- the
free/personal-team route requires Xcode to mint and silently renew 7-day
profiles, which defeats the point of doing this from NixOS. Everything
below uses only `openssl` and the developer.apple.com web portal, no Mac
needed:

```shell
# Generate a key + CSR
openssl genrsa -out ios_dev.key 2048
openssl req -new -key ios_dev.key -out ios_dev.csr -subj "/CN=Your Name/emailAddress=you@example.com"
```

- Developer portal -> Certificates -> upload `ios_dev.csr` -> download the
  resulting `.cer`, convert it together with your key into a `.p12`:
  ```shell
  openssl x509 -in ios_development.cer -inform DER -out ios_development.pem -outform PEM
  openssl pkcs12 -export -inkey ios_dev.key -in ios_development.pem -out ios_dev.p12 -name "iOS Development"
  ```
- Register your phone's UDID (Devices -> +): get it with
  `ideviceinfo -k UniqueDeviceID` (device must be plugged in and paired,
  see step 3).
- Register an App ID matching the app's bundle identifier:
  `com.actuel.christmasLight` (from `app/ios/Runner.xcodeproj`; change it
  in Xcode's `PRODUCT_BUNDLE_IDENTIFIER` build setting first if you want
  something else -- it must be unique per Apple's rules).
- Create a Development provisioning profile for that App ID + certificate
  + device, download it as `profile.mobileprovision`.

## 3. Pair your device and sign the app

```shell
devenv shell
idevice_id -l                       # confirm the device is visible
idevicepair pair                    # trust the computer on-device when prompted

zsign \
  -k ios_dev.p12 -p '<p12 password>' \
  -m profile.mobileprovision \
  -o ChristmasLight-signed.ipa \
  Runner.app
```

## 4. Install

```shell
ideviceinstaller -i ChristmasLight-signed.ipa
```

The app should now be on the home screen. Development certs/profiles are
valid for a year (vs. 7 days for free-account signing), so you only need
to repeat steps 2-4 when the app changes or the profile expires -- steps 3
and 4 alone take a few seconds.

## Notes

- No MAC-address pairing: unlike the Linux `node-ble` script in the repo
  root (which dials a hardcoded BLE MAC address), iOS's CoreBluetooth never
  exposes hardware addresses to apps. The Flutter app
  (`lib/ble/light_controller.dart`) instead scans for any peripheral
  advertising the strip's primary service UUID.
- `usbmuxd` needs to actually be running for any `idevice*`/`zsign`-adjacent
  USB commands to see your phone. `devenv shell` puts the binary on `PATH`
  but does not start a system service -- on NixOS proper, enable it globally
  with `services.usbmuxd.enable = true;` in your system configuration
  (recommended), or run `sudo usbmuxd -f` in the foreground for one-off use.
- Wireless (no-USB) install/re-sign flows exist (e.g. `pymobiledevice3`),
  but that package is currently marked broken in nixpkgs; USB is the
  reliable path for now.
