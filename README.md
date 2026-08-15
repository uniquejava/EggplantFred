# EggplantFred

Native **macOS 14+** Alfred-style app launcher — menu bar only, SwiftUI + AppKit.

[简体中文](./README_zh.md)

Download prebuilt DMGs from **[Releases](https://github.com/uniquejava/EggplantFred/releases)**.

<p align="center">
  <img src="./docs/screenshot.png" alt="EggplantFred launcher searching for Fre" width="640">
</p>

## Features

- **Menu bar only** — no Dock clutter (Dock icon appears while Preferences is open)
- **Global hotkey** — default **⌥ double tap**; also ⌃ / ⇧ / ⌘ double tap or modifier+key combos
- **Fuzzy search** — match installed apps by name or `.app` filename; empty query shows no list
- **Compact UI** — search bar expands to up to 9 results; Alfred-inspired purple selection
- **Quick open** — Enter or **⌘1**…**⌘9**; Esc / click away dismisses
- **Preferences** — via menu bar or the hat icon on the search field

## Requirements

- macOS **14** or later
- [Accessibility](x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility) for the global hotkey  
  (System Settings → Privacy & Security). Without it, the hotkey does nothing.

## Install

1. Download the `.dmg` from [Releases](https://github.com/uniquejava/EggplantFred/releases) and drag into Applications
2. If Gatekeeper blocks it: `xattr -cr /Applications/EggplantFred.app`
3. Open the app → grant Accessibility when prompted

## Build from source

```bash
open EggplantFred.xcodeproj
# or
xcodebuild -scheme EggplantFred -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/EggplantFred.app
```

Release build, install to Applications, and DMG packaging: **[docs/commands.md](docs/commands.md)**.

## Docs

| Doc | Contents |
|-----|----------|
| [docs/commands.md](docs/commands.md) | Build, run, install, DMG, GitHub Release, icons, Accessibility |
| [docs/menu-bar-icon.md](docs/menu-bar-icon.md) | Menu bar `HatGlyph` design spec |
| [docs/app-icon.md](docs/app-icon.md) | Dock / Finder app icon |
