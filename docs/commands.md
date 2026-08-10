# EggplantFred — commands

All recipes assume repo root:

```bash
cd /path/to/EggplantFred
```

Bundle ID: `com.eggplantfred.EggplantFred`  
Scheme: `EggplantFred`  
DerivedData (local): `build/` (gitignored)

---

## Xcode

```bash
open EggplantFred.xcodeproj
```

```bash
# List schemes / destinations
xcodebuild -list -project EggplantFred.xcodeproj
```

---

## Debug build & run

```bash
killall EggplantFred 2>/dev/null || true

xcodebuild -scheme EggplantFred -configuration Debug \
  -derivedDataPath build build

open build/Build/Products/Debug/EggplantFred.app
```

---

## Release build

```bash
killall EggplantFred 2>/dev/null || true

xcodebuild -scheme EggplantFred -configuration Release \
  -derivedDataPath build build

# App:
#   build/Build/Products/Release/EggplantFred.app
```

Read version from the built app:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  build/Build/Products/Release/EggplantFred.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
  build/Build/Products/Release/EggplantFred.app/Contents/Info.plist
```

---

## Install to /Applications

```bash
killall EggplantFred 2>/dev/null || true

xcodebuild -scheme EggplantFred -configuration Release \
  -derivedDataPath build build

rm -rf /Applications/EggplantFred.app
cp -R build/Build/Products/Release/EggplantFred.app /Applications/
open /Applications/EggplantFred.app
```

Prefer the `/Applications` copy for day-to-day use so Accessibility TCC stays stable. Don’t run Debug `build/…` and `/Applications` at the same time.

---

## Release + DMG

Local distribute package (Apple Development signed — **not** notarized).  
Output: `build/EggplantFred-<version>.dmg`.

```bash
killall EggplantFred 2>/dev/null || true

xcodebuild -scheme EggplantFred -configuration Release \
  -derivedDataPath build build

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  build/Build/Products/Release/EggplantFred.app/Contents/Info.plist)
STAGE=build/dmg-stage
DMG="build/EggplantFred-${VERSION}.dmg"

rm -rf "$STAGE" build/EggplantFred-*.dmg
mkdir -p "$STAGE"
cp -R build/Build/Products/Release/EggplantFred.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname EggplantFred -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

open -R "$DMG"
```

Install from DMG: open → drag **EggplantFred** onto **Applications**.

Optional — strip quarantine after copying a DMG-built app (local / unsigned distribution friction):

```bash
xattr -cr /Applications/EggplantFred.app
# or for the DMG itself:
xattr -cr build/EggplantFred-*.dmg
```

---

## Clean

```bash
# Local derived data only
rm -rf build

# Or xcodebuild clean (still under -derivedDataPath build)
xcodebuild -scheme EggplantFred -configuration Debug \
  -derivedDataPath build clean
xcodebuild -scheme EggplantFred -configuration Release \
  -derivedDataPath build clean
```

```bash
# Quit app / refresh Dock icon cache if an old icon sticks
killall EggplantFred 2>/dev/null || true
killall Dock 2>/dev/null || true
```

---

## Codesign / verify

```bash
APP=build/Build/Products/Release/EggplantFred.app

codesign -dv --verbose=4 "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose "$APP" || true   # may fail without notarization
```

---

## Accessibility (hotkey event tap)

Required for global hotkeys (`CGEvent` tap).

```bash
# Open System Settings → Privacy → Accessibility
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

# If the checkbox is on but AXIsProcessTrusted() is still false
# (stale TCC after ad-hoc / path change):
tccutil reset Accessibility com.eggplantfred.EggplantFred
# Then relaunch the app and enable it again when prompted.
```

---

## App icon (Dock / Finder / DMG)

Rounded-corner silhouette is required for classic PNG asset catalogs — see [app-icon.md](./app-icon.md).

```bash
python3 scripts/generate_app_icons.py
# then rebuild Release / DMG so the Dock icon updates
```

## Menu bar glyph (HatGlyph PDF)

See [menu-bar-icon.md](./menu-bar-icon.md) for size rules.

```bash
cd EggplantFred/Assets.xcassets/HatGlyph.imageset

# Edit HatGlyph.svg, then:
/opt/homebrew/bin/rsvg-convert -f pdf -o HatGlyph.pdf HatGlyph.svg

# Preview raster (optional)
/opt/homebrew/bin/rsvg-convert -w 220 -h 160 HatGlyph.svg -o /tmp/HatGlyph-preview.png
open /tmp/HatGlyph-preview.png
```

Requires Homebrew `librsvg` (`brew install librsvg`).

---

## App icon (Dock / DMG)

Master: `EggplantFred/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-master.png`  
Generator: `scripts/generate_app_icons.py` (needs Pillow: `pip3 install pillow`).

```bash
python3 scripts/generate_app_icons.py
```

Then rebuild so `AppIcon.icns` / `Assets.car` refresh.

---

## Logging / process

```bash
# Is it running?
pgrep -lf EggplantFred

# Stream unified logs (hotkey / launch noise)
log stream --style syslog --predicate 'process == "EggplantFred"'

# Or NSLog-style via Console.app; filter subsystem/process EggplantFred
```

---

## UserDefaults (hotkey settings)

Persisted by `HotkeySettings` / `HotkeyShortcut` (see code for exact keys). Inspect:

```bash
defaults read com.eggplantfred.EggplantFred
# Wipe all app defaults (resets prefs including hotkey):
defaults delete com.eggplantfred.EggplantFred
```

---

## Git

```bash
git status
git diff
git log --oneline -10
```

Commit / push only when you intend to. Project-local agent notes (signing team, git identity) live in `AGENTS.md`, not here.

---

## One-shot: Release → DMG → reveal

```bash
killall EggplantFred 2>/dev/null || true
xcodebuild -scheme EggplantFred -configuration Release -derivedDataPath build build && \
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  build/Build/Products/Release/EggplantFred.app/Contents/Info.plist) && \
STAGE=build/dmg-stage && DMG="build/EggplantFred-${VERSION}.dmg" && \
rm -rf "$STAGE" build/EggplantFred-*.dmg && mkdir -p "$STAGE" && \
cp -R build/Build/Products/Release/EggplantFred.app "$STAGE/" && \
ln -s /Applications "$STAGE/Applications" && \
hdiutil create -volname EggplantFred -srcfolder "$STAGE" -ov -format UDZO "$DMG" && \
rm -rf "$STAGE" && open -R "$DMG"
```
