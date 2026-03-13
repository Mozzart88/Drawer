# Drawer

<!--toc:start-->
- [Drawer](#drawer)
  - [Features](#features)
  - [Requirements](#requirements)
  - [Build & Installation](#build-installation)
  - [Hotkeys](#hotkeys)
  - [Disclaimer](#disclaimer)
  - [License](#license)
<!--toc:end-->

Draw on your screen, cast keystrokes, and record — all with global hotkeys.

<!-- ![Drawer screenshot placeholder](screenshot.png) -->

## Features

- Draw on screen with adjustable stroke color, width, and opacity
- Smooth Bezier curve rendering
- Undo / redo strokes
- Floating stroke HUD for quick property adjustments
- Color wheel panel
- Screen recording (full screen or specific window)
- Virtual chromakey (alpha-channel transparent background recording)
- Key cast overlay — displays pressed keys during recording
- Wacom / tablet stylus support with proximity auto-enable
- Touch Bar controls
- Presentation mode (hides UI widgets and notifications while recording)
- Global hotkeys (no need to focus the app)

## Requirements

- macOS 13 Ventura or later
- Xcode command-line tools / Swift toolchain (for building from source)
- Screen Recording and Microphone permissions (prompted on first launch)

## Build & Installation

```bash
make build    # compile and package Drawer.app
make install  # build and copy to /Applications
make run      # build and launch directly
make clean    # remove build artifacts
```

## Hotkeys

| Key | Action |
|-----|--------|
| F5  | Toggle virtual chromakey (green screen) |
| F7  | Start / stop recording |
| F8  | Open color wheel |
| F9  | Toggle drawing mode |
| F10 | Clear all strokes |
| ⌘ + C | Undo last stroke |
| ⌘ + ⇧ + C | Revert last Undo |

## Disclaimer

Drawer is a personal project built for my own use and shared as-is.
Feel free to use or fork it, but don't expect support, maintenance, or updates.

## License

MIT
