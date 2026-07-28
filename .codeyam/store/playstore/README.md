# Google Play assets — CodeYam Counter

Assembled for the **Google Play Console**. Mirrors `../appstore/` for the
Android build under `android/`. The app is live on the **Internal testing**
track; everything here is what a **production** rollout additionally needs.

## Contents

```
icon/
  PlayIcon-512.png            512×512   — Play Store icon, 32-bit PNG
feature-graphic-1024x500.png  1024×500  — REQUIRED by Play; no App Store equivalent
screenshots/phone/            1080×2400 — real scenario captures, uncaptioned
  01-count-anything.png                  "Count anything"
  02-every-tally-one-tap-away.png        "Every tally, one tap away"
  03-watch-it-add-up.png                 "Watch it add up"
  04-make-it-yours.png                   "Make it yours"
  05-one-handed-by-design.png            "Make it yours" / "One-handed by design"
screenshots/tablet-7/         1080×1920 — 9:16, five frames
screenshots/tablet-10/        1440×2560 — 9:16, four frames
listing.md                    App name, short + full description, release notes
PLAY_CONSOLE_CHEATSHEET.md    Every App content / Policy declaration answer
```

## Sources
- Brand tokens: `android/.../ui/CounterTheme.kt` and the shipped adaptive icon
  (bg `#0C0D08`, accent lime `#D5F560`).
- Screenshots: the Android scenario captures in
  `.codeyam/scenarios/screenshots/android-counter-*--phone-portrait.png`. These
  are **already 1080×2400**, exactly Play's phone spec, so they are copied
  verbatim — unlike the iOS set, which is matted onto 1290×2796 marketing
  frames.
- Regenerate everything: `python3 ../appstore/gen_assets.py`. One generator
  emits both stores' artwork deliberately, so the two listings cannot drift.

### Why the store icon and the launcher icon are not the same drawing

The **Play Store icon** is rendered from `render_icon_minimal()` — the identical
artwork as the shipped App Store icon: the lime plus **and** the four signature
counter dots. Listing tiles get only a gentle rounded-square mask, so the full
brand mark survives, and matching iOS is the point.

The **Android adaptive launcher icon** is plus-only, and that is a constraint
rather than an oversight. An adaptive icon guarantees only the centred 66dp of
its 108dp foreground is visible; every launcher mask crops the rest. The dot row
sits at 80% of the icon's height, so a circular mask would slice it off. Adding
the dots there would not match iOS — it would produce a clipped mess.

So: store tile = full mark (matches iOS), launcher icon = plus only (mask-safe).
Do not "fix" the launcher icon to match the store tile.

### Feature graphic

Rendered at 4x and downsampled. PIL antialiases text but **not** geometry, so
drawing the plus and dots straight at 1024×500 leaves visibly stepped edges on
exactly the shapes the brand is built from. The lime glow behind the mark is
deliberately tight and low-alpha — a wide, strong one washes the right half
olive and reads as muddy.

## Tablet support

The app is phone-first — a one-handed design with a left-aligned hero numeral and
a thumb-reach bottom bar. Stretched to a tablet's ~960dp width it fell apart: the
numeral stranded itself against the left edge with half the screen empty.
`MaxContentWidth` (`ui/CounterScreen.kt`) now caps the column at 480dp and centres
it, so a tablet renders the designed proportions instead of a scaled-up phone.
Below the cap — every phone — the constraint is inert and layout is unchanged.

Tablet screenshots were captured by reconfiguring a booted emulator with
`wm size` / `wm density` (240dpi → 720dp and 960dp wide), not by creating a
tablet AVD. Two cautions if you regenerate them:

- The emulator's WindowManager destabilises after repeated `wm size` changes
  (`BLASTSyncEngine: Unfinished container`, SystemUI ANRs) and the app parks on
  its launch window. Reboot the emulator between passes and verify each frame
  actually shows the header bar rather than the splash.
- The tablet taskbar renders into the frame, so captures are cropped of device
  chrome and rescaled to the exact Play dimensions.

## Deliberate divergences from iOS

These are decisions, not bugs. Do not "fix" them.

- **Installed app name.** Android installs as **CodeYam Counter**
  (`res/values/strings.xml` → `app_name`); iOS installs as the shorter
  **Counter** (`CFBundleDisplayName`). Both stores list the app as
  *CodeYam Counter*. The Pixel launcher truncates around 10–12 characters, so
  the label renders ellipsized under the icon — verified acceptable on device.
- **Kotlin namespace ≠ applicationId.** `applicationId` is
  **`com.codeyam.counter`**, matching the iOS bundle ID so both stores show one
  app. The Kotlin `namespace` is still the scaffold's `com.codeyam.android`, and
  the launch activity is therefore
  `com.codeyam.counter/com.codeyam.android.MainActivity`. The two need not
  match; moving the namespace would rewrite every source path in `.codeyam`'s
  test registry and dependency graph for no user-visible gain.
  (`.codeyam/stack.json` records this pair as
  `simulator.androidPackage` / `simulator.androidActivity` — without it the
  editor's simulator preview launches the wrong component and scenario seeding
  silently misses, since the seed writes
  `shared_prefs/<applicationId>_preferences.xml`.)
- **Screenshots are uncaptioned** on Play but captioned on the App Store. Play
  renders listing screenshots small, where marketing text does not survive
  legibly.

## Release mechanics

- **`versionCode` must increase on every single upload**, including a re-upload
  to the same track, and can never be reused. This is the most common cause of a
  rejected Play upload. Local builds default to `1`; CI passes
  `-PversionCodeOverride=<n>` (see `.github/workflows/play-internal.yml`).
- **Upload key** lives at `android/app/upload-keystore.jks` (git-ignored), with
  credentials in `android/keystore.properties` (git-ignored) or the
  `ANDROID_KEYSTORE_*` env vars. **Play App Signing** is enrolled, so this is
  the *upload* key only — Google holds the real app signing key and can reset
  the upload key if it is lost. Back it up anyway; losing it means a support
  round-trip.
- **R8 minification is ON** for release (`isMinifyEnabled` / `isShrinkResources`).
  Keep rules live in `android/app/proguard-rules.pro`. Persistence uses
  kotlinx.serialization's JSON *tree* API with explicit `fromJson`/`toJson` — no
  `@Serializable` classes, so there are no generated serializers for R8 to
  strip. The round-trip is verified on-device (increment → force-stop →
  relaunch → counts intact).
- **Target API.** Play currently requires new uploads to target **API 35** on
  all tracks, and **API 36 from Aug 31, 2026**. Verify the current requirement
  in Play Console before each release rather than trusting this file.

## Still to do before a PRODUCTION rollout

- Fill the Play Console store listing from `listing.md` and upload the graphics
  above.
- Clear the App content declarations using `PLAY_CONSOLE_CHEATSHEET.md`.
- **Closed testing gate:** a recently-created *personal* developer account must
  run a closed test with **≥12 testers for 14 continuous days** before
  production access is unlocked. This does not affect Internal testing. Confirm
  which account type applies before committing to a launch date.
- Optionally upload the R8 deobfuscation mapping file
  (`android/app/build/outputs/mapping/release/mapping.txt`) so Play can
  symbolicate release crash reports.
- The privacy policy page mentions iCloud backups; consider making that line
  OS-neutral (Android uses Google Auto Backup) for a public launch.
