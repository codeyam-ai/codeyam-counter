# App Store assets — CodeYam Counter

Assembled for **App Store Connect** (this is a native iOS SwiftUI app, so the
original "Chrome Web Store" task was retargeted to the correct store — see the
listing/dimensions below).

## Contents

```
icon/
  AppIcon-1024-A-plus.png    1024×1024  — lime "+" mark + counter dots (recommended)
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
- **Icon**: no AppIcon set existed in the repo. These are freshly designed from
  the brand. Pick A or B; the chosen 1024px PNG also needs to be added to the
  Xcode asset catalog (`App` target → `Assets.xcassets/AppIcon`) for the build.
- **Screenshot size**: 1290×2796 (6.9") is the one currently-required iPhone size.
  Add 6.5"/iPad sets only if you ship on those devices.
- **URLs & privacy**: placeholders in `listing.md` — confirm before submitting.
