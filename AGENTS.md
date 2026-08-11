# AGENTS.md — EggplantFred

## What this is

Native **macOS 14+** Alfred-style app launcher (MVP+).

- Menu bar only (`LSUIElement`); Dock icon only while Preferences is open
- Global hotkey (default **⌥ double tap**; also **⌃/⇧/⌘ double tap** or modifier+key combos)
- Type a query → fuzzy-match installed apps → Enter / ⌘1–9 to launch
- Tray → **Preferences...** via `SettingsLink` (Alfred-style General pane)
- Launcher starts as a **single input row**; result list appears only when there are matches

Inspiration: Alfred General preferences + result list (purple selection, path subtitle, shortcut column).

## Stack

| Layer | Tech |
|-------|------|
| UI | SwiftUI + AppKit (`NSPanel`, `NSVisualEffectView`, AppKit hotkey field) |
| Hotkey | `CGEvent` tap (Accessibility required) |
| Apps | Scan `/Applications`, `/System/Applications`, `~/Applications` |
| Launch | `NSWorkspace.openApplication` |
| Login item | `SMAppService.mainApp` |

Bundle ID: `com.eggplantfred.EggplantFred`  
Team: `DEVELOPMENT_TEAM = M5J7K9HVYB` (Apple Development — keeps Accessibility across rebuilds)  
Xcode: `EggplantFred.xcodeproj` (scheme `EggplantFred`)

## Layout

```
EggplantFred/
  EggplantFredApp.swift          # @main, MenuBarExtra + SettingsLink, AppState, Accessibility
  Controllers/LauncherController.swift   # KeyablePanel show/hide, resize compact↔expanded
  Hotkey/HotkeyMonitor.swift     # Modifier double-tap + key combo via event tap
  Hotkey/HotkeyShortcut.swift    # doubleTap(modifier:) | keyCombo; HotkeySettings (UserDefaults)
  Index/AppEntry.swift           # App model + IconCache
  Index/AppIndex.swift           # Async scan (ApplicationScanner)
  Search/SearchEngine.swift      # Empty query → []; fuzzy / token / acronym match
  UI/SearchWindowView.swift      # Compact bar; expands when results non-empty
  UI/SearchViewModel.swift       # Query, selection, ⌘N hints
  UI/ResultRowView.swift
  UI/StatusMenuHatIcon.swift     # Menu-bar + launcher hat; HatTemplateImage
  UI/SettingsView.swift          # Alfred prefs + HotkeyRecorderView (NSView first-responder)
  Assets.xcassets/
    AppIcon.appiconset/          # Dock / Finder / DMG app icon (PNG sizes)
    HatGlyph.imageset/           # Menu-bar template: HatGlyph.pdf (+ .svg source)
  Services/AppLauncher.swift
  Services/LaunchAtLogin.swift
  Info.plist                     # LSUIElement = true
  EggplantFred.entitlements      # App Sandbox OFF (needed for taps / open apps)
  scripts/generate_app_icons.py  # Rasterize AppIcon master → appiconset sizes
.github/workflows/
  ci.yml                         # PR/main Release build (ad-hoc)
  release.yml                    # Tag v* → DMG → GitHub Release
docs/
  README.md                      # Docs index (root README.md is the project readme)
  commands.md                    # All CLI recipes (+ GitHub Release)
  menu-bar-icon.md               # HatGlyph design spec
  app-icon.md                    # Dock/Finder rounded-corner icon spec
```

## Menu bar icon (HatGlyph) — design spec

→ **[`docs/menu-bar-icon.md`](docs/menu-bar-icon.md)** (sizes, template, PDF/SVG).

## Commands

→ **[`docs/commands.md`](docs/commands.md)** (Debug/Release, `/Applications`, DMG, GitHub Release, clean, codesign, Accessibility, icons, logs, defaults).  
CI/CD: `.github/workflows/` — push/PR builds; `git tag vX.Y.Z && git push --tags` publishes a DMG Release.  
Project readme: [`README.md`](README.md). Docs index: [`docs/README.md`](docs/README.md).

## Product behaviour to preserve

1. **Empty query → empty list** (do not show all apps until the user types).
2. **Fuzzy search**: token prefix (`St` → Studio / Storm / Store), substring, acronym, subsequence. Score both **display name** and **`.app` filename** (VS Code display name `Code`, filename `Visual Studio Code`).
3. **Hotkey**: default ⌥ double tap (~400ms). Preferences records ⌃/⌥/⇧/⌘ double tap or ⌘/⌥/⌃/⇧ + key. Persisted in UserDefaults (`HotkeyShortcut` Codable; legacy `doubleOption` migrates to `doubleTap(.option)`).
4. **Hotkey recorder UX**:
   - Alfred glyph row: always show `⌃ ⌥ ⇧ ⌘`; purple = active combo + key / `double tap` (no duplicate text).
   - Stay focused after each capture so the next gesture can be recorded without re-clicking.
   - Apply immediately via `applyHotkey` / `updateShortcut`.
   - **Do not pause** the global monitor while Preferences is focused — re-triggering the *current* binding (e.g. ⌘ double tap) must open the launcher; a *different* modifier double-tap rebinds.
   - Esc or click away ends recording; `?` resets to ⌥ double tap.
5. **Preferences**: open with `SettingsLink` (not `showSettingsWindow:`). While open, activation policy `.regular`; on disappear back to `.accessory`.
6. **Panel**: borderless, vibrancy, centered on mouse’s screen; compact (~64pt) until matches, then expands downward (~480pt); fade in/out; Esc / resign-key closes.
7. **Shortcuts**: selected row `⏎`; others `⌘1`…`⌘9`.
8. **Accessibility**: required for event tap; first-launch alert + Preferences “Request Permissions...”. Poll / `applicationDidBecomeActive` restarts the tap after grant.

## Known quirks / next polish

- VS Code title may show **Code.app** (CFBundleDisplayName); path still shows `Visual Studio Code.app`. Prefer filename for Alfred-style title if asked.
- Without Accessibility, global hotkeys do nothing. If checkbox stays on but `AXIsProcessTrusted()` is false: `tccutil reset Accessibility com.eggplantfred.EggplantFred` then re-enable.
- Avoid ad-hoc (“Sign to Run Locally”) for day-to-day runs — use the Development Team signing above.
- `build/` is gitignored; do not commit DerivedData. Prefer one running instance (Xcode vs `build/` path).

## Git

- Identity: `uniquejava` / `uniquejava@gmail.com` (zsh alias `usegmail`)
- Commit only when the user asks

## Prefer

- Small focused Swift diffs; keep AppKit panel logic in `LauncherController`
- No App Sandbox unless there is a clear entitlement plan
- Match existing Alfred-like visuals (purple selection, path subtitle, shortcut column, prefs glyph field)
