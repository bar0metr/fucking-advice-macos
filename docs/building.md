# Building and signing

Requirements: macOS 15 or later, full Xcode 16 or later, Go 1.24 or later, and an Apple Development certificate.

Use two bundle IDs and one macOS unprovisioned App Group:

- `com.yourname.FuckingAdvice`
- `com.yourname.FuckingAdvice.Widgets`
- `ABCDE12345.fucking-advice-macos`

Run:

```sh
make build BUNDLE_ID=com.yourname.FuckingAdvice
```

`make build-unsigned` is compile-only diagnostics. Its widget and App Group storage are not operational. It is never a substitute for the signed acceptance build.

For macOS, Apple supports Team ID-prefixed App Groups without portal registration or provisioning-profile authorization. Both components must carry the same entitlement and use signatures from that team. The build derives the Team ID from the Apple Development certificate and verifies both signatures.

`make package` creates a versioned DMG after runtime validation but does not notarize it. External distribution additionally requires a Developer ID Application certificate, hardened-runtime signing, `notarytool submit --wait`, and stapling. Never describe an artifact as notarized without a successful Apple notarization response.

The application is distributed under `GPL-3.0-only`. Release artifacts must retain the complete `LICENSE` file in the application bundle. Source distributions must keep the repository-root copy.
