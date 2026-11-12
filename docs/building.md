# Building and signing

Requirements: macOS 15 or later, full Xcode 16 or later, Go 1.24 or later, and an Apple Development certificate.

Use two bundle IDs and one macOS unprovisioned App Group:

- `com.yourname.FuckingAdvice`
- `com.yourname.FuckingAdvice.Widgets`
- `ABCDE12345.fucking-advice-macos`

Run:

```sh
make build-arm64 BUNDLE_ID=com.yourname.FuckingAdvice
make build-universal BUNDLE_ID=com.yourname.FuckingAdvice
make build-all BUNDLE_ID=com.yourname.FuckingAdvice
```

The arm64 target builds native Apple Silicon host, helper, and widget binaries. The universal target builds `arm64` and `x86_64` slices for all three executables and rejects the bundle if any slice is absent. Each variant uses separate DerivedData and runtime-validation files.

`make build-unsigned` is compile-only diagnostics. Its widget and App Group storage are not operational. It is never a substitute for the signed acceptance build.

For macOS, Apple supports Team ID-prefixed App Groups without portal registration or provisioning-profile authorization. Both components must carry the same entitlement and use signatures from that team. The build derives the Team ID from the Apple Development certificate and verifies both signatures.

After building, launch and manually validate each exact application bundle. Confirm that the host writes a newly fetched advice value, the WidgetKit extension reads and renders that same value, and the widget is present in the macOS gallery. Then bind the result to the signed executable CDHashes:

```sh
make record-runtime-arm64 CONFIRM_RUNTIME_VALIDATION=YES
make record-runtime-universal CONFIRM_RUNTIME_VALIDATION=YES
make package-all
```

The record targets reject missing, incorrectly signed, or architecturally incomplete bundles. `make package-all` packages the existing tested applications without rebuilding or re-signing them. `make clean` removes the validation stamps, so every clean release build requires new runtime validation.

`make package-arm64` creates `Fucking_Advice_<version>_arm64.dmg`. `make package-universal` creates `Fucking_Advice_<version>_universal.dmg`. `make package-all` verifies and creates both after runtime validation. The images are not notarized. External distribution additionally requires a Developer ID Application certificate, hardened-runtime signing, `notarytool submit --wait`, and stapling. Never describe an artifact as notarized without a successful Apple notarization response.

The application is distributed under `GPL-3.0-only`. Release artifacts must retain the complete `LICENSE` file in the application bundle. Source distributions must keep the repository-root copy.

The host target compiles `Assets.xcassets` with `AppIcon` as its application icon set. Keep every size declared in `AppIcon.appiconset/Contents.json`; missing slots can produce a generic icon in Finder or Settings even when the 1024-pixel source exists.
