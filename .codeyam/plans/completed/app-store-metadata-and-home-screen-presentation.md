---
title: "App Store Metadata & Home-Screen Presentation"
mode: ui
createdAt: "2026-07-09T23:27:29Z"
source: manual
---

## Summary

The app installs to the home screen labeled **"App"** and ships an icon that
doesn't fit the brand. Fix both facets of how the app presents itself:
(1) give it a proper home-screen name ("Counter") via `CFBundleDisplayName`,
and (2) replace the current glowing lime "+" icon with a new **minimalist**
icon built from the real app palette (flat `#0C0D08` background, crisp lime
`#D5F560` "+" with square/hard-edged arms, and the four flat signature counter
dots — no glow, no gradient, no text). Wire the new 1024px icon into the Xcode
asset catalog so both the build and future App Store submission use it.

## Key Decisions

- **Home-screen name = "Counter"** — short, never truncates (home screen caps
  ~12 chars), and reads cleanly. The App Store listing name stays the fuller
  "CodeYam Counter" (already in `listing.md`); the two are independent and this
  plan does not change the listing name.
- **Add `CFBundleDisplayName`, don't repurpose `CFBundleName`** — iOS shows
  `CFBundleDisplayName` on the home screen when present, falling back to
  `CFBundleName`. Adding the display key is the minimal, correct fix and leaves
  `CFBundleName`/`PRODUCT_NAME` (the "App" target name) untouched so nothing
  else in the build breaks.
- **New minimalist icon over reusing B-motif** — the user wants the real app
  colors *and* a minimalist, hard-edged look. B-motif uses the palette but is
  busy (ghost "7", "TAP +" band, ringed dots); A-plus adds a glow + gradient +
  rounded plus arms. Neither is minimalist, so author a fresh design instead of
  adopting either existing candidate.
- **Keep the single-size (1024×1024, `universal`) appiconset** — the existing
  `Contents.json` already uses the modern single-image form Xcode auto-scales
  from; only the PNG bytes need to change, not the catalog structure.
- **Design lives in `gen_assets.py`** — the repo already generates icon
  candidates there; add the new design as a function so it's reproducible and
  version-controlled alongside the existing A/B generators, rather than
  hand-painting a one-off PNG.

## Implementation

### 1. Give the app a home-screen name

**File**: `App/Info.plist`

Add a `CFBundleDisplayName` key set to `Counter` (a literal string, not a
`$(…)` build-setting reference). Place it near the other `CFBundle*` keys.
Leave `CFBundleName` (`$(PRODUCT_NAME)`) as-is. After this, a fresh install
shows "Counter" under the icon instead of "App".

Expected result: home-screen label reads **Counter**.

### 2. Author the new minimalist icon generator

**File**: `.codeyam/store/appstore/gen_assets.py`

Add a new function (e.g. `icon_minimal(path)`) alongside `icon_plus` /
`icon_app_motif`, and call it from `__main__` to emit a new candidate, e.g.
`icon/AppIcon-1024-C-minimal.png`. Design spec:

- **Background**: flat fill `BG` (`#0C0D08`) — no `vgrad`, no glow layer.
- **Plus glyph**: centered lime (`ACCENT` `#D5F560`) "+", drawn with the
  existing `plus()` helper but with **`radius=0`** so the arms are square /
  hard-edged (not the rounded `radius=60` used by `icon_plus`). Size it as the
  dominant element (large, generous margins), vertically centered or biased
  slightly up to leave room for the dot row.
- **Signature dots**: one tight row of four **flat** dots using the real
  counter palette in order `lime, coffee, steps, bugs`
  (`D5F560, FF7A4D, 4DB5FF, C98BFF`) — no outer ring, no glow. Keep them small
  and restrained so the "+" stays the hero. (If the row competes with the
  minimalist goal during execution, dropping the dots entirely is an
  acceptable simpler fallback — decide from the rendered result.)
- No text, no gradient, no drop shadow, no rounded background corners (iOS
  masks the squircle itself).

Keep the brand tokens sourced from the constants already at the top of the file
(`BG`, `ACCENT`, `DOTS`) so the icon can't drift from `Theme.swift`.

### 3. Install the new icon into the app target

**File**: `App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

Replace the bytes of `AppIcon-1024.png` with the newly generated minimalist
1024×1024 PNG (copy the generator's `C-minimal` output over it). `Contents.json`
already references `AppIcon-1024.png` at `size 1024x1024`, `idiom universal`,
`platform ios`, so no catalog edit is required. `ASSETCATALOG_COMPILER_APPICON_NAME`
is already `AppIcon` in both build configs — no `project.pbxproj` change needed.

Expected result: the app builds with the new icon; the home screen and App
Store both show it.

### 4. Update the store asset docs

**File**: `.codeyam/store/appstore/README.md`

Note the new recommended icon (C-minimal) and that it's the one installed into
the Xcode catalog, so the "Pick A or B" note and the icon inventory stay
accurate. Optionally note the chosen home-screen display name ("Counter") vs the
App Store listing name ("CodeYam Counter").

## Reused existing code

- `plus(draw, cx, cy, arm, thick, color, radius)` from
  `.codeyam/store/appstore/gen_assets.py` — reuse with `radius=0` for the
  hard-edged glyph.
- Brand token constants `BG`, `ACCENT`, `ON_ACCENT`, `DOTS` from
  `.codeyam/store/appstore/gen_assets.py` (mirrored from
  `Sources/AppCore/Theme.swift`: bg `#0C0D08`, accent lime `#D5F560`, dots
  lime/coffee/steps/bugs).
- `CounterTheme` palette in `Sources/AppCore/Theme.swift` — the source of truth
  for the colors the icon must match (glossary: `CounterTheme`).
- Existing `AppIcon.appiconset/Contents.json` single-image `universal` catalog
  form — reused unchanged; only the referenced PNG is swapped.

## Reproduction Test

No unit-level reproduction is writable: both facets are packaging/asset config
(an `Info.plist` key and a PNG in the asset catalog), not code with an
isolatable runtime unit. Verify by building the `App` target and confirming
(a) the home screen reads "Counter" on a fresh install, and (b) the new
minimalist icon renders. Demonstrate the icon design itself via the generated
`.codeyam/store/appstore/icon/AppIcon-1024-C-minimal.png` candidate.

## Scenarios to Demonstrate

- New minimalist icon rendered at 1024×1024 (the generated candidate PNG).
- Icon at home-screen scale (small) — confirm the square-armed "+" stays legible
  and the dots don't muddy at size.
- Home-screen tile showing the "Counter" label under the icon (fresh install).
- Before/after icon comparison: current glowing "+" vs new flat minimalist "+".
