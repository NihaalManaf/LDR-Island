<h1 align="center">LDR Island</h1>

<p align="center">A tiny native macOS notch companion for long-distance relationships.</p>

LDR Island lives at the top of your screen, shows your partner's current time in the compact island, and opens into a smooth **LDR notch extension** with a draggable time converter, reunion countdown, and relationship-aware settings.

## Features

- **Native macOS notch island** UI built with AppKit
- **Compact default state** showing your partner's time + time zone
- **Smooth hover expansion** into the LDR notch extension
- **Draggable time scrubber** to explore better call times live
- **Explicit day shift messaging**
  - same day
  - next day
  - previous day
- **Persistent settings window** with tabs for:
  - relationship role
  - local time zone
  - partner time zone
  - top-right avatar style
  - reunion countdown visibility + date
- **Reunion countdown** shown only in the expanded extension when enabled
- **Works on notch and non-notch Macs**
- **Fast hover interactions** with extra collapse stability logic

## Why this exists

Most timezone tools feel like utilities.

LDR Island is meant to feel more personal: always there, lightweight, a little romantic, and fast enough to check without breaking your flow.

## How it works

### Compact island
The default state sits around the MacBook notch and shows:
- your partner's current time
- their time zone
- their avatar

### LDR notch extension
Hover the island to expand it.

The extension shows:
- your time
- your partner's time
- a pink draggable timeline
- day relationship text
- optional reunion countdown
- settings access

## Settings

Click the gear in the expanded extension to open the settings window.

Tabs include:

### People
- choose whether you are the **boyfriend** or **girlfriend**
- choose the **top-right avatar**

If you select that you are the boyfriend, the app defaults the partner avatar to female.
If you select that you are the girlfriend, the app defaults the partner avatar to male.

### Time Zones
- set **your** time zone
- set **your partner's** time zone

### Reunion
- choose whether the reunion countdown should be shown
- set the reunion date

The countdown appears **only inside the expanded notch extension**, never in the compact island.

## Tech

- **Language:** Swift
- **UI:** AppKit
- **Platform:** macOS
- **Project:** `LDRIsland.xcodeproj`

Core files:
- `LDRIsland/IslandViewController.swift`
- `LDRIsland/IslandWindowController.swift`
- `LDRIsland/ScreenLocator.swift`
- `LDRIsland/TimeConversionService.swift`
- `LDRIsland/AppConfiguration.swift`

## Run locally

### Requirements
- macOS
- Xcode

### Open in Xcode
1. Open `LDRIsland.xcodeproj`
2. Select the `LDRIsland` scheme
3. Press **Run**

### Build from terminal
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme LDRIsland \
  -project LDRIsland.xcodeproj \
  -destination 'platform=macOS'
```

## Configuration

Settings are persisted with `UserDefaults`, so you no longer need to hardcode the main relationship options for normal use.

## Current UX highlights

- slower, smoother open animation
- cleaner close animation without end-of-collapse flare
- hover close remains responsive without collapsing incorrectly when the pointer is already inside the expanded window
- draggable time conversion replaces the older form-based converter

## Roadmap ideas

Possible next improvements:
- more polished settings window styling
- richer avatar options
- better visual treatment for ideal call windows
- keyboard shortcut for opening settings (`Cmd+,`)
- onboarding flow for first launch

## Inspiration

This project explored ideas from dynamic island / notch UI patterns, but the implementation is tailored to this app's own layout, geometry, and behavior.

## License

Personal project. Add a license if you plan to distribute or accept contributions publicly.
