# Architecture

The app is split along platform boundaries.

- The Go `advice-fetcher` owns the single HTTPS operation, bounded decoding, validation, and structured JSON protocol. It is a one-shot process.
- The SwiftUI/AppKit host owns the process lifecycle, exactly-once startup coordinator, disabled-by-default automatic refresh timer, status menu, settings, atomic cache updates, login registration, and desktop-level overlay window.
- The WidgetKit extension reads the shared App Group cache and profiles. It never performs networking or launches the helper.

The host loads cached data before starting the helper. Only a fully decoded response is atomically stored. Widget timelines are reloaded after committed advice or profile changes.

When enabled, the automatic refresh task sleeps for the configured 5–1,440 minute interval and calls the same guarded refresh path as the menu action. The task exists only inside the running host process. Saving settings cancels the old task and starts a new countdown. An in-flight request causes the scheduled call to coalesce instead of starting a second helper.

The overlay uses a borderless non-activating `NSPanel`, ignores mouse events, and sits one level above the desktop window. It joins Spaces but remains below ordinary application windows. Public AppKit APIs cannot guarantee identical behavior for every Stage Manager and full-screen transition; those cases require manual acceptance testing.

App Sandbox is enabled. The host has outgoing-network and App Group entitlements; the extension has only App Group access. The helper is embedded and signed as nested code before the enclosing app is signed.

The host bundle copies the repository's `LICENSE` into `Contents/Resources`. The About pane resolves that bundled file first and links to the repository copy only as a fallback.

Xcode compiles `Assets.xcassets/AppIcon.appiconset` into the host bundle. `docs/assets/app-icon.png` is the 1024-pixel README master used to derive every macOS icon size.
