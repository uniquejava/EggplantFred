# Menu bar icon (HatGlyph) — design spec

Apple HIG is thin on menu bar extras. Practical rules from [Bjango — Designing macOS menu bar extras](https://bjango.com/articles/designingmenubarextras) and what EggplantFred ships.

## Rules

| Rule | Value / guidance |
|------|------------------|
| Menu bar height | **24pt** (Big Sur+; taller on notch MacBooks with scaling) |
| Extra working height | **≤ 22pt** — cannot be taller |
| Optical weight | ~**16×16pt** to match system items (Control Center, etc.) |
| Width | **Not fixed** — follows content (`NSVariableStatusItemLength`). Peers may measure ~32–38pt wide; **do not** force a wide `.frame` (e.g. 34×24) or the item balloons (~50pt) with huge gaps |
| Padding | Usually **none** in the asset; OS centers vertically. Don’t bake large empty margins into the canvas |
| Color | **Template image** only (black + alpha). System tints for light/dark / selected |
| Format | Prefer **PDF or SVG** (vector). Or PNG **1× + 2×**. We use `HatGlyph.pdf` with `preserves-vector-representation` + `template-rendering-intent` |
| Our canvas | **22×16pt** PDF in `EggplantFred/Assets.xcassets/HatGlyph.imageset/` |
| Code | `HatTemplateImage.menuBar()` → height **16**, proportional width. `MenuBarExtra`: `Image(nsImage:)` + `.renderingMode(.template)` — **no fixed wide frame** |

## Regenerate PDF

```bash
cd EggplantFred/Assets.xcassets/HatGlyph.imageset
# edit HatGlyph.svg
/opt/homebrew/bin/rsvg-convert -f pdf -o HatGlyph.pdf HatGlyph.svg
```

## App icon (separate)

Dock / Preferences / DMG: see **[app-icon.md](./app-icon.md)** (rounded corners + regenerate).  
Not the menu-bar glyph.
