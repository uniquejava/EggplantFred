# AGENTS.md — EggplantFred

## What this is

Native **macOS 14+** Alfred-style app launcher (MVP+).

- Menu bar only (`LSUIElement`), no Dock icon
- Global hotkey (default **⌥ double tap**; also supports ⌃/⇧/⌘ double tap or key combos) opens a borderless search panel
- Type a query → fuzzy-match installed apps → Enter / ⌘1–9 to launch
- Preferences (tray → Preferences...): Alfred-style General pane — launch at login, hotkey record, Accessibility
- Launcher starts as a single input row; result list appears only when the query has matches

Inspiration UI: Alfred General preferences + result list (icon + title + path + shortcut hints, purple selection).

## Stack

| Layer | Tech |
|-------|------|
| UI | SwiftUI + AppKit (`NSPanel`, `NSVisualEffectView`) |
| Hotkey | `CGEvent` tap (Accessibility required) |
| Apps | Scan `/Applications`, `/System/Applications`, `~/Applications` |
| Launch | `NSWorkspace.openApplication` |
| Login item | `SMAppService.mainApp` |

Bundle ID: `com.eggplantfred.EggplantFred`  
Xcode: `EggplantFred.xcodeproj` (scheme `EggplantFred`)

## Layout

```
EggplantFred/
  EggplantFredApp.swift          # @main, MenuBarExtra, AppState, Accessibility prompt
  Controllers/LauncherController.swift   # KeyablePanel show/hide, focus, key monitor
  Hotkey/HotkeyMonitor.swift     # Modifier double-tap + key combo via event tap
  Hotkey/HotkeyShortcut.swift    # Codable shortcut + HotkeySettings (UserDefaults)
  Index/AppEntry.swift           # App model + IconCache
  Index/AppIndex.swift           # Async scan (ApplicationScanner)
  Search/SearchEngine.swift      # Empty query → []; fuzzy / token / acronym match
  UI/SearchWindowView.swift      # Alfred-like panel chrome
  UI/SearchViewModel.swift       # Query, selection, ⌘N hints
  UI/ResultRowView.swift
  UI/SettingsView.swift          # Hotkey record, permissions, launch at login
  Services/AppLauncher.swift
  Services/LaunchAtLogin.swift
  Info.plist                     # LSUIElement = true
  EggplantFred.entitlements      # App Sandbox OFF (needed for taps / open apps)
```

## Commands

```bash
open EggplantFred.xcodeproj
# or
xcodebuild -scheme EggplantFred -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/EggplantFred.app
```

## Product behaviour to preserve

1. **Empty query → empty list** (do not show all apps until the user types).
2. **Fuzzy search**: token prefix (`St` → Studio / Storm / Store), substring, acronym, subsequence. Score both **display name** and **`.app` filename** (VS Code’s display name is `Code`, filename is `Visual Studio Code`).
3. **Hotkey**: default ⌥ double tap (~400ms); Preferences can record ⌃/⌥/⇧/⌘ double tap or ⌘/⌥/⌃/⇧ + key. Persisted in UserDefaults.
4. **Panel**: borderless, vibrancy, centered on mouse’s screen; compact input-only until matches, then expands downward; fade in/out, Esc / resign-key closes.
5. **Shortcuts**: selected row `⏎`; others `⌘1`…`⌘9`.
6. **Accessibility**: required for global tap; first launch alert + Settings “Grant…”.

## Known quirks / next polish

- VS Code appears as **Code.app** in the title (CFBundleDisplayName); path still shows full `Visual Studio Code.app`. Alfred-style title = prefer filename — not done yet if user asks.
- Event tap needs Accessibility; without it ⌥ double tap does nothing.
- Ad-hoc signing invalidated Accessibility after every rebuild (checkbox stayed on, `AXIsProcessTrusted()` was false). Project sets `DEVELOPMENT_TEAM` so Debug/Release use Apple Development signing — grant once and it should stick. If stuck: `tccutil reset Accessibility com.eggplantfred.EggplantFred` then re-enable.
- `build/` is gitignored; do not commit DerivedData.

## Git

- Global identity set to gmail profile: `uniquejava` / `uniquejava@gmail.com` (zsh alias `usegmail`)
- Initial commit on `main`: Alfred-style MVP+
- Commit only when the user asks

## Prefer

- Small focused Swift diffs; keep AppKit panel logic in `LauncherController`
- No App Sandbox unless there is a clear entitlement plan
- Match existing Alfred-like visuals (purple selection, path subtitle, shortcut column)
