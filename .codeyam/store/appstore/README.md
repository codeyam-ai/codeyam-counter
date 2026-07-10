# App Store assets — CodeYam Counter

Assembled for **App Store Connect** (this is a native iOS SwiftUI app, so the
original "Chrome Web Store" task was retargeted to the correct store — see the
listing/dimensions below).

## Contents

```
icon/
  AppIcon-1024-C-minimal.png 1024×1024  — flat bg, hard-edged lime "+", flat dots (INSTALLED / recommended)
  AppIcon-1024-A-plus.png    1024×1024  — lime "+" mark + counter dots, with glow/gradient
  AppIcon-1024-B-motif.png   1024×1024  — literal app-motif (dots + increment band)
screenshots/6.9-inch/         1290×2796 — iPhone 6.9" (16 Pro Max), App Store-accepted
  01-counter-large-value.png             "Count anything"
  02-counter-all-counters-list.png       "Every tally, one tap away"
  03-counter-graph-open.png              "Watch it add up"
  04-counter-settings-open-over-number.png  "Make it yours"
  05-counter-app-settings-...on.png      "One-handed by design"
listing.md                    App name, subtitle, promo text, description, keywords
```

## Sources
- Brand tokens: `Sources/AppCore/Theme.swift` (bg `#0C0D08`, accent lime `#D5F560`).
- Screenshots: real scenario captures in `.codeyam/scenarios/screenshots/`
  (1206×2622, iPhone 16 Pro), matted onto 1290×2796 marketing frames.
- Regenerate everything: `python3 gen_assets.py` (kept in the session scratchpad;
  copy it here if you want it version-controlled).

## Notes / still to do
- **Icon**: the minimalist **C-minimal** design is the chosen icon and is
  installed into the Xcode asset catalog (`App` target →
  `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`), so the build and the
  App Store submission both use it. A and B remain as alternate candidates.
- **Home-screen name**: the app installs as **Counter** (via `CFBundleDisplayName`
  in `App/Info.plist`). The App Store listing name stays the fuller
  **CodeYam Counter** (see `listing.md`) — the two are independent.
- **Screenshot size**: 1290×2796 (6.9") is the one currently-required iPhone size.
  Add 6.5"/iPad sets only if you ship on those devices.
- **URLs & privacy**: placeholders in `listing.md` — confirm before submitting.
