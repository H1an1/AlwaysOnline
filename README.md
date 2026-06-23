# AlwaysOnline

<p align="center">
  <img src="docs/assets/app-icon.png" alt="AlwaysOnline app icon" width="160" height="160">
</p>

AlwaysOnline is a tiny native macOS menu bar app that keeps your cursor gently awake. When it is enabled, the app watches for recent keyboard and mouse activity. If your Mac has been idle for the selected amount of time, AlwaysOnline moves the cursor a tiny distance and returns it to where it started.

It is intentionally quiet: no Dock icon, no main window, and no noisy status text in the menu bar. The app lives in the menu bar, where you can turn it on or off and choose how long to wait before a wiggle is triggered.

## Download

Download the latest installer from the [Releases](https://github.com/H1an1/AlwaysOnline/releases) page.

For the current release, open the DMG, drag `AlwaysOnline.app` into `Applications`, then launch it from there.

## Features

- Native macOS menu bar app.
- No Dock icon and no always-open window.
- Automatically wiggles the cursor after keyboard and mouse inactivity.
- Configurable trigger timing: 30 seconds, 1 minute, or 5 minutes.
- Adjustable wiggle distance from 1 to 120 pixels.
- Two menu bar icon states: idle and enabled/wiggle-ready.
- First-run Accessibility permission prompt.
- Settings are saved locally with `UserDefaults`.

## Permissions

macOS requires Accessibility permission before any app can post mouse events. AlwaysOnline asks for this permission the first time it opens.

Version `0.1.8` and later use the stable bundle identifier `io.github.h1an1.AlwaysOnline`. If you are upgrading from an older local build and macOS shows two AlwaysOnline entries, remove the old entry and enable the new one once.

To enable it manually:

1. Open `System Settings`.
2. Go to `Privacy & Security` > `Accessibility`.
3. Enable `AlwaysOnline`.
4. Quit and reopen AlwaysOnline if macOS does not apply the permission immediately.

If permission is missing, the menu shows `No Accessibility Permission`.

## How It Works

AlwaysOnline checks system idle time on a timer. When the app is enabled and the idle duration reaches the selected trigger timing, it gently wiggles the cursor twice with a short horizontal movement, then returns to the original position. Use the `Wiggle Distance` slider in the menu to adjust how far the cursor moves.

Default behavior:

- Checks every 10 seconds.
- Triggers after 1 minute of inactivity.
- Moves 16 pixels horizontally by default.
- Repeats the wiggle twice.
- Uses a short cooldown so it does not repeat continuously.

## Build From Source

Requirements:

- macOS 13 or later.
- Swift Package Manager / Xcode command line tools.

Run tests:

```sh
swift test
```

Build the release app and distributable files:

```sh
./scripts/build_app.sh
```

The generated files are written to `dist/`:

- `dist/AlwaysOnline.app`
- `dist/AlwaysOnline.dmg`
- `dist/AlwaysOnline.zip`

Run the local app bundle:

```sh
open dist/AlwaysOnline.app
```

## Project Layout

- `Sources/AlwaysOnlineCore`: testable scheduling and wiggle decision logic.
- `Sources/AlwaysOnlineMac`: AppKit menu bar app and macOS integrations.
- `Resources`: app icon, menu bar icons, DMG background, and app metadata.
- `Tests`: unit tests for core behavior and menu presentation state.
- `scripts/build_app.sh`: release build, app bundle assembly, signing, ZIP, and DMG packaging.

## License

AlwaysOnline is released under the [MIT License](LICENSE).
