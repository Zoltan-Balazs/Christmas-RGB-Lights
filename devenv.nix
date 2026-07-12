{ pkgs, ... }:

{
  # Flutter/Dart for editing, testing, and driving builds of ./app.
  # Note: `flutter build ios`/`ipa` itself still needs a real macOS + Xcode
  # host (see app/ios/README-sideload.md) -- Xcode cannot run on NixOS.
  # This shell covers everything on the NixOS side: local dev (Android/web/
  # desktop), plus (re-)signing and installing an already-built .ipa onto a
  # personal iOS device without a Mac.
  packages = with pkgs; [
    flutter

    # iOS sideload toolchain
    libimobiledevice # idevice_id, ideviceinfo, idevicepair, ...
    ideviceinstaller # install/uninstall .ipa over USB/network
    usbmuxd          # host <-> device USB multiplexer daemon
    ldid             # ad-hoc/fake code-signing (Mach-O signature tool)
    zsign            # re-sign an .ipa with a real cert + provisioning profile
  ];

  enterShell = ''
    echo "christmas-light devenv shell"
    echo "  cd app && flutter pub get      # Dart deps"
    echo "  cd app && flutter test         # run unit/widget tests"
    echo "  cd app && flutter build apk    # local Android build works here"
    echo ""
    echo "iOS: build the unsigned app on a Mac/CI runner (see"
    echo "  app/ios/README-sideload.md), then sign + install from here with"
    echo "  zsign and ideviceinstaller."
  '';
}
