# Widget and desktop limitations

- Users add and place widgets through macOS Edit Widgets. The app cannot do it programmatically.
- WidgetKit controls family dimensions, rendering modes, refresh scheduling, margins, and some color/material behavior.
- Full-color versus monochrome/vibrant desktop widgets is controlled by System Settings > Desktop & Dock > Widgets > Widget style.
- The widget retains its last shared cache when the host quits. The overlay requires the host process.
- The overlay uses public window levels and ignores mouse events. Mission Control, Stage Manager, full-screen Spaces, and multi-display changes require testing on each supported macOS version.
