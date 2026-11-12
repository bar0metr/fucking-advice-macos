# Fucking Advice for macOS

Fucking Advice is a native menu-bar app for macOS 15 and newer. It fetches one random phrase when the host process starts, caches the result, and shows the same cached phrase in a desktop text overlay and WidgetKit widgets. A manual **Refresh Now** action starts one additional request.

The app preserves Unicode text and profanity returned by `https://fucking-great-advice.ru/api/random`. It contains no analytics, accounts, polling, background refresh, audio playback, or wallpaper modification.

## Components

| Component | Responsibility |
|---|---|
| SwiftUI/AppKit host | Menu bar, Settings, startup state, cache commits, overlay, login item |
| `advice-fetcher` in Go | HTTPS request, 8-second timeout, 64 KiB limit, JSON validation |
| WidgetKit extension | Small, Medium, and Large widgets that read the App Group cache |
| App Group files | One advice record plus widget and overlay settings |

The widget extension performs no network requests. The host launches the helper with `Process`, without a shell. Failed requests leave the last valid cache untouched.

## Requirements

- macOS 15.0 or newer
- Full Xcode 16 or newer, selected with `xcode-select`
- Go 1.24 or newer
- Apple Development signing certificate
- Apple Development signing identity from Xcode, including a free Personal Team

Apple requires matching signed App Group entitlements before the host and widget can share data. This macOS-only project uses an unprovisioned Team ID-prefixed group, `<TEAM_ID>.fucking-advice-macos`. macOS validates the signing-team prefix without App Group portal registration. An unsigned build can prove compilation and bundle layout. It cannot prove widget installation or shared storage.

## Apple signing setup

Use two bundle identifiers. Replace `com.yourname` with a reverse-DNS prefix owned by your team.

```text
Host bundle:   com.yourname.FuckingAdvice
Widget bundle: com.yourname.FuckingAdvice.Widgets
App Group:     ABCDE12345.fucking-advice-macos
```

Apply the same App Group entitlement to both targets. Do not register the Team ID-prefixed group in the portal. In Xcode, open **Settings → Accounts → Manage Certificates** and create an Apple Development certificate. The build derives the ten-character Team ID from that certificate.

## Build

```sh
make help
make build BUNDLE_ID=com.yourname.FuckingAdvice
```

Version `0.1.1` lives in the `VERSION` variable in `Makefile`; the Xcode build receives the same value as `MARKETING_VERSION`. Override it with `make build VERSION=0.1.2 ...`.

The signed app appears at `build/FuckingAdvice.app`. The symlink points into `build/DerivedData`, so repeated builds retain Xcode's incremental compilation cache. The build creates `build/Fucking_Advice_0.1.1.dmg` only after a runtime-validation stamp matches the exact host, helper, and widget binaries.

Use the compile-only target before signing setup:

```sh
make build-unsigned
```

The unsigned target creates `build/FuckingAdvice_UNSIGNED.app` and `build/Fucking_Advice_0.1.1_UNSIGNED.dmg` in separate DerivedData. It prints a warning. Do not install it as acceptance evidence for WidgetKit or App Group behavior.

## Commands

```text
make help             List targets
make build            Build and verify a signed app and widget extension
make build-unsigned   Build an unsigned diagnostic bundle
make run              Build and open the signed app
make test             Run Go and Swift core tests
make lint             Check Go formatting/vet, plists, and the Xcode project
make package          Build and verify the versioned DMG
make clean            Remove generated files under build/
```

The build compiles the Go helper with `-trimpath`, strips its symbol table, enables Swift whole-module optimization, removes dead code, reuses DerivedData, and builds independent Xcode targets in parallel. Set `ARCH=amd64` only for a separate Intel helper build. A universal release requires building both helper slices with `lipo` and building the Xcode targets for `arm64 x86_64`; the default targets the current Mac to keep development builds short.

## Use

Launch the app and open its quote-bubble menu-bar item. The menu shows a short phrase preview, refresh and copy actions, the desktop overlay toggle, Settings, and Quit.

Add a native widget through macOS:

1. Control-click the desktop and select **Edit Widgets**.
2. Search for **Fucking Advice**.
3. Drag a Small or Medium widget to the desktop.
4. Edit the widget to select an appearance profile.

macOS controls widget dimensions, placement, margins, and rendering mode. Change full-color versus monochrome behavior under **System Settings → Desktop & Dock → Widgets → Widget style**.

The desktop text overlay stays below ordinary app windows, ignores mouse events, and joins Spaces. Settings control source text, heading, size, opacity, glow, style, and backdrop panel. The first version stores normalized overlay geometry. Drag-and-resize edit mode remains a required manual acceptance item until its interactive editor is implemented.

## Fetch contract

- The host loads the last valid cache before networking.
- A process-local state gate starts one request per host launch.
- **Refresh Now** coalesces clicks while one request runs.
- The Go client rejects redirects, non-HTTPS production endpoints, non-2xx responses, malformed JSON, invalid IDs, empty text, and bodies larger than 64 KiB.
- The host commits a valid record with an ISO 8601 UTC timestamp, then reloads WidgetKit timelines.
- Errors appear in the host status. The cache remains unchanged.

## Storage

The host writes `advice.json` and `settings.json` through atomic file replacement in the configured App Group container. The host can read a local Application Support fallback for diagnostics, but it refuses to claim widget functionality when the App Group container is unavailable. The widget reads the App Group only.

## Tests

`make test` runs Go tests against local TLS `httptest` servers. Cases cover Unicode preservation, unknown fields, malformed and oversized data, bad status, invalid records, timeout, and the one-request redirect policy. Swift package tests cover model defaults and corrupt-settings fallback.

The following checks require a signed app and a logged-in macOS GUI session:

- widget discovery in the system gallery
- Small and Medium profile behavior
- one GET observed at process start
- overlay z-order and click-through behavior
- Spaces, Stage Manager, full-screen, sleep/wake, and multiple displays
- Launch at Login
- VoiceOver and accessibility settings

Record those results per macOS version. An Xcode build or SwiftUI preview does not establish runtime WidgetKit acceptance.

## Packaging and notarization

`make build` and `make package` create `build/Fucking_Advice_<version>.dmg`. The image contains the app and an Applications link. The target verifies nested code and App Group entitlements before packaging. It does not submit the image to Apple.

Distribution outside the development Mac requires a Developer ID Application certificate, hardened-runtime signing, a successful `notarytool submit --wait`, and stapling. Keep certificates, private keys, provisioning profiles, API keys, and notary credentials outside the repository.

## Troubleshooting

### Full Xcode is not active

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

### No Apple Development identity

Open Xcode **Settings → Accounts → Manage Certificates**, create an Apple Development certificate, then verify:

```sh
security find-identity -v -p codesigning
```

### App Group unavailable

Confirm that both targets use `<TEAM_ID>.fucking-advice-macos`, carry the same entitlement, and have signatures from the same Team ID. Do not use the `group.` prefix with a Personal Team because that form requires provisioning-profile authorization.

### Widget missing from the gallery

Check that `FuckingAdviceWidgets.appex` exists under `FuckingAdvice.app/Contents/PlugIns`, both targets use the same team, the extension bundle ID belongs to the host prefix, and both signed entitlements contain the same App Group. Delete the old app, install the rebuilt app under `/Applications`, launch it once, then reopen Edit Widgets.

### Fetch failure

Run the bundled protocol by itself:

```sh
build/advice-fetcher fetch --timeout=8s
```

Success writes one JSON line to stdout. Failure writes a structured error to stderr and leaves stdout empty.

## Repository layout

```text
cmd/advice-fetcher/       Go CLI
internal/adviceapi/       HTTPS client and validation
internal/fetchprotocol/   stdout/stderr JSON contract
macos/FuckingAdviceApp/   host app
macos/FuckingAdviceWidgets/ WidgetKit extension
macos/Shared/             shared Codable models and rendering
macos/Config/             plists, entitlements, build configuration
scripts/                  build, test, package, and bundle checks
macos/Tests/              Swift core tests
docs/                     architecture and platform limits
```

## Known gaps

- The overlay persists normalized geometry, but the interactive drag/resize editor and Apply/Cancel transaction remain unimplemented.
- The Settings UI lists installed font families. Explicit diagnostics for a font removed after configuration remain unimplemented; SwiftUI falls back during rendering.
- Real widget-gallery, App Group, login-item, multi-display, VoiceOver, and packaged runtime checks need signed GUI execution.

These gaps block the specification's Definition of Done. The repository contains a functional vertical slice and strict build gates, not a completed release.

## Author and project

Created by **Nikita Parfenovich aka bar0metr**. Project source and issue tracking live in the [GitHub repository](https://github.com/bar0metr/fucking-advice-macos). Contact: [bar0metr.crazy@yandex.com](mailto:bar0metr.crazy@yandex.com).

Copyright © 2026 Nikita Parfenovich.

## License

Fucking Advice is free software licensed under the [GNU General Public License v3.0 only](LICENSE), identified by the SPDX expression `GPL-3.0-only`. The license does not include the “or any later version” option. The signed application bundle includes the same license text under `Contents/Resources/LICENSE`.
