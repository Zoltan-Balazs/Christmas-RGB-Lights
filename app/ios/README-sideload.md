# Building and sideloading on iOS from NixOS

Xcode is required to compile the Flutter iOS target (`flutter build ios`
shells out to `xcodebuild`, which needs Apple's proprietary SDK/toolchain),
and Xcode only runs on macOS -- there's no NixOS-native way around that one
step. Everything else -- signing the build and installing it on your phone
-- runs fine on NixOS. The split:

1. **Build the unsigned .ipa** (needs a real macOS host, once per release)
2. **Sign and install it**, either:
   - **Route A** -- your own certificate, from NixOS, via `zsign` +
     `ideviceinstaller` (1-year validity, needs a $99/yr Apple Developer
     account)
   - **Route B** -- [SideStore](https://sidestore.io) on your phone, using
     a free Apple ID (no dev account needed, but re-signs every 7 days,
     automatically, in the background)

Run `devenv shell` at the repo root first -- it provides `flutter`, `zsign`,
`ldid`, `libimobiledevice`, `ideviceinstaller`, and `usbmuxd`.

## 1. Build the unsigned .ipa

Easiest path: push to `main` (or run manually) and let
`.github/workflows/ios-unsigned-build.yml` build it on a free GitHub Actions
macOS runner. It runs `flutter build ios --release --no-codesign`, wraps
`Runner.app` in the `Payload/` folder structure IPAs require, and uploads
`ChristmasLight-unsigned.ipa` as a workflow artifact -- ready to sign, no
repackaging needed.

(If you have occasional access to any Mac, `cd app && flutter build ios
--release --no-codesign` does the build; see the workflow's "Package
unsigned .ipa" step for the `Payload/` wrapping if you want to do it by
hand.)

## Route B: SideStore (free Apple ID)

Assuming SideStore is already installed and paired on your phone (that's a
separate one-time setup, ask if you need it):

- Get `ChristmasLight-unsigned.ipa` onto the device -- AirDrop, Files/iCloud
  Drive, or SideStore's "Import from URL" (host it briefly with e.g.
  `python3 -m http.server` on your LAN, or as a GitHub Release asset).
- In SideStore: **My Apps -> + -> pick the .ipa** (or paste the URL).
- SideStore signs it with your paired Apple ID and installs it, and
  refreshes the 7-day free-provisioning signature automatically from then
  on -- no need to repeat anything below.

## Route A: your own certificate

### 1. Get a certificate + provisioning profile

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

### 2. Pair your device and sign the app

```shell
devenv shell
idevice_id -l                       # confirm the device is visible
idevicepair pair                    # trust the computer on-device when prompted

zsign \
  -k ios_dev.p12 -p '<p12 password>' \
  -m profile.mobileprovision \
  -o ChristmasLight-signed.ipa \
  ChristmasLight-unsigned.ipa
```

### 3. Install

```shell
ideviceinstaller -i ChristmasLight-signed.ipa
```

The app should now be on the home screen. Development certs/profiles are
valid for a year (vs. 7 days for free-account signing), so you only need
to repeat steps 2-3 when the app changes or the profile expires -- signing
and installing alone take a few seconds.

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
