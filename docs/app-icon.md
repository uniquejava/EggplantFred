# App icon (Dock / Finder / DMG) — design spec

Reference: [Apple HIG — App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)

## What the HIG says

- Provide a **1024×1024 square** canvas.
- On modern platforms (especially with Icon Composer / layered icons), the **system masks** layers into a rounded rectangle. Don’t pre-mask layered glass icons.
- For **classic Asset Catalog PNGs / `.icns`** on current macOS (what this project uses), Dock and Finder often show your pixels as-is. A hard square with opaque corners looks like a **rectangle** next to other apps.

## What we ship

| Rule | Value |
|------|--------|
| Master | `EggplantFred/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-master.png` |
| Shape | Continuous rounded rect, corner radius ≈ **22.37%** of edge (Big Sur+ grid) |
| Corners | **Transparent** outside the rounded rect |
| Sizes | All `mac` idiom 16…512 @1x/@2x via `scripts/generate_app_icons.py` |

The generator applies the mask if the master still has opaque corners.

```bash
python3 scripts/generate_app_icons.py
# then rebuild so AppIcon.icns / Assets.car refresh
```

## Separate from menu bar

Menu bar uses template `HatGlyph` PDF — see [menu-bar-icon.md](./menu-bar-icon.md). Do not use the Dock icon there.
