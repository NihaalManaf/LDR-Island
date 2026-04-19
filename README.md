# LDRIsland

Tiny native macOS notch island for long-distance time conversion.

## What v1 does

- shows partner's current local time at top center
- expands on hover
- converts `Mine → Hers` or `Hers → Mine`
- prefers built-in laptop display, falls back to main display
- stays on normal spaces, hides in fullscreen spaces by default
- falls back to same top-center island on Macs without a notch

## Before first run

Edit `LDRIsland/AppConfiguration.swift`:

- `partner.name`
- `partner.timeZoneIdentifier`
- optional `local.name`
- optional `showsDockIcon`

Use IANA timezone IDs, for example:

- `America/New_York`
- `Europe/London`
- `Asia/Kuala_Lumpur`
- `Asia/Tokyo`

## Run in Xcode

1. Install Xcode.
2. Open `LDRIsland.xcodeproj`.
3. Select `LDRIsland` scheme.
4. Press Run.

## Test in Xcode

- `LDRIslandTests` covers timezone conversion and day rollover.
- Run with `Product > Test`.

## Current behavior choices

- hover island to expand
- leave island to collapse
- built-in display first
- fullscreen spaces hidden by default
- no settings UI yet
- no sync, backend, or accounts

## Later

See `docs/future-ideas.md`.
