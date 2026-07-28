---
title: "ne -- Android Pixel Device Test and Play Store Submission"
prefix: "ne"
mode: ui
createdAt: "2026-07-27T17:52:40Z"
source: manual
---

## Status & Next Steps — updated 2026-07-27 (post-internal-testing)

**Internal-testing milestone: DONE and verified on a physical Pixel.** A few
things diverged from the plan's original assumptions — flagged below.

### ✅ Completed
- **On the Pixel:** installed and running as a release build (versionCode 100003,
  `targetSdk 35`); the separate App Settings stale-selection bug fixed and verified
  moving on-device.
- **Build/identity gaps closed:** display name → "CodeYam Counter"; `compileSdk` /
  `targetSdk` bumped to **35** (Play now requires it on all tracks — not 34 as the
  plan assumed); release `signingConfig` added (reads `android/keystore.properties`
  or `ANDROID_KEYSTORE_*` env vars, unsigned fallback); overridable `versionCode`
  for CI; `proguard-rules.pro` present, build clean (R8 off for now).
- **`applicationId` = `com.codeyam.counter`** — CHANGED from the plan's
  "com.codeyam.android" decision: the Play Console app was registered under
  `com.codeyam.counter` (matching the iOS bundle ID). Kotlin `namespace` stays
  `com.codeyam.android`.
- **Upload keystore** generated (`android/app/upload-keystore.jks`, git-ignored);
  **Play App Signing** enrolled on the first manual upload.
- **Internal-testing track live** with a tester opt-in URL:
  https://play.google.com/apps/internaltest/4701429936624523422
- **One-click CI:** `.github/workflows/play-internal.yml` builds a signed AAB and
  uploads to the internal track on dispatch (Google Cloud service account
  `play-ci-uploader@codeyam-counter.iam.gserviceaccount.com` + GitHub secrets).
  Verified green.
- **Adaptive launcher icon** (CodeYam dark bg + lime "+", matching iOS) replacing
  the stock placeholder — hand-authored vector adaptive icon, NOT the `gen_assets.py`
  density-PNG route the plan sketched.
- **In-app version label** ("v1.0 (<versionCode>)") at the bottom of App Settings.

### ⏳ Remaining — for a PRODUCTION (public) launch only
None of this blocks internal testing; it's the work to go public:
- **Full Play store listing:** title, short description (≤80), full description
  (reuse `.codeyam/store/appstore/listing.md`), phone screenshots (the 1080×2400
  Android scenario captures exist).
- **Feature graphic 1024×500** — required by Play, still needs designing.
- **512×512 Play Store icon.**
- **App-content declarations** — answers are in
  `.codeyam/store/playstore/PLAY_CONSOLE_CHEATSHEET.md` (privacy URL, Data safety =
  none, content rating → Everyone, target audience 13+, no ads).
- **Closed testing → production:** a newer personal Play developer account must run
  closed testing (≥12 testers, ~14 days) before production is unlocked.
- Optionally enable **R8 minification** + upload a deobfuscation mapping file.

### Note
This work was done via direct commits (not the codeyam editor workflow). Parts
A–D below are largely satisfied — treat that checklist as reference for the
remaining production items.

## Summary

Take the Kotlin + Jetpack Compose app under `android/` from its current
scaffold-default state onto a physical Pixel, then to an Internal-testing upload
on Google Play. The Android app is a complete feature-parity port of the iOS app
now live on the App Store, but its Gradle config, launcher label, and icon are
all still the generator's defaults (`app_name` = "Kotlin Android Compose", stock
green-triangle vector icon, `compileSdk`/`targetSdk` 34, `versionCode 1`, no
release signing config), and `android/app/build.gradle.kts` references a
`proguard-rules.pro` file that does not exist. None of that is shippable — but
none of it blocks getting the app onto the Pixel *today*.

So the plan runs in that order: **get it running on the Pixel first** with the
debug build and zero code changes, then fix the build/identity gaps, then
re-verify on the Pixel as a real release build, then assemble the Play listing.
Store assets reuse the App Store listing copy and the 53 existing Android
scenario screenshots (already captured at 1080×2400, exactly Play's phone spec).

Decisions already made with the user: **keep `applicationId = "com.codeyam.android"`**
(scaffold default, but permanent once published — accepted), **build and upload
the first AAB locally** with a follow-up section describing the CI workflow, and
**target the Internal testing track** first rather than production.

## Key Decisions

- **Two separate device passes, not one.** The debug build installs on the Pixel
  right now with no code changes at all — Gradle auto-generates a debug keystore,
  `compileSdk 34` matches the only SDK platform currently installed locally, and
  no signing config is involved. That answers "does the app actually feel right
  on my phone" in minutes, before any build surgery. The *release* build is a
  genuinely different artifact (R8-minified, non-debuggable, upload-key signed)
  and gets its own verification pass in Part C. Collapsing the two would mean
  doing all of Part B before learning anything about the app on real hardware.
- **Keep `applicationId = "com.codeyam.android"`** — user's call. It diverges
  from the iOS bundle ID (`com.codeyam.counter`) but avoids resetting the
  SharedPreferences file name and the codeyam Android scenario seeding path,
  which writes `com.codeyam.android_preferences.xml`. Record the divergence in
  the Play assets README so it isn't mistaken for a bug later.
- **Raise `compileSdk`/`targetSdk` to 36, keep `minSdk 24`.** Google Play
  requires new apps and updates to target API 35 today and **API 36 from
  Aug 31, 2026** — roughly one month out. Shipping on 34 would be rejected at
  upload. Going straight to 36 avoids a forced bump weeks after launch.
  `minSdk 24` stays — nothing in the app needs newer, and it maximizes device
  reach. **Verify the exact current requirement in Play Console before
  building** rather than trusting this plan's number.
- **Adaptive launcher icon derived from the shipped iOS icon**, not a new
  design. `.codeyam/store/appstore/icon/AppIcon-1024-C-minimal.png` is the
  installed App Store icon and `.codeyam/store/appstore/gen_assets.py` already
  encodes the brand tokens (bg `#0C0D08`, accent lime `#D5F560`). Extend that
  generator rather than hand-authoring a second icon — the two stores should
  not drift.
- **Play App Signing with a locally-generated upload key.** Google holds the
  real app signing key; the local keystore is only the upload key and can be
  reset by Google if lost. Keystore file and credentials stay gitignored and
  out of the repo entirely.
- **Release signing config reads from `keystore.properties` / env vars, with a
  graceful fallback.** If the properties file is absent (CI, fresh clone,
  contributors), the release build type simply builds unsigned rather than
  failing the whole Gradle configuration phase — so `compileDebugKotlin` and
  `testDebugUnitTest` in CI keep working untouched.
- **Enable minification (R8) for release, with a real `proguard-rules.pro`.**
  The file is already referenced but missing; `isMinifyEnabled = false` is why
  the build hasn't broken. Turning R8 on shrinks the APK and is standard for
  Play releases — but it must be validated on-device, because the app uses
  `kotlinx.serialization` for counter persistence, which needs keep rules.
  **This is the single highest-risk change in the plan**; the Part C device pass
  exists largely to catch a serialization break under R8.
- **Verify `SeedPolicy` on the real release build.** `SeedPolicy.current(false)`
  → `REQUIRE_PROVENANCE`, so a release build ignores codeyam-injected scenario
  state and the four panel-open seed flags. That logic is unit-tested, but the
  Part C run is the first time it is exercised in a genuinely non-debuggable
  build. It's a privacy/correctness property worth confirming by hand once.
- **Reuse the iOS privacy policy URL rather than writing a second one.** Play
  requires a privacy policy URL unconditionally, and the iOS app now live on the
  App Store must already have one on file with Apple — but it was never written
  back into the repo, so the repo's only trace is a placeholder. Recover it from
  App Store Connect, record it in both stores' `listing.md`, and only author a
  new policy if none turns out to exist. Same app, same zero-collection posture;
  two policies would just drift. See step 14 — this is the plan's one hard
  blocker with an external dependency, so it starts early even though it lands
  late.
- **Internal testing track first.** Available within minutes of upload with no
  review wait, installs on the Pixel via a Play opt-in link, and proves the
  full signed-AAB → Play → device pipeline before committing to a production
  review.
- **Play listing copy is adapted, not rewritten.**
  `.codeyam/store/appstore/listing.md` already contains reviewed, on-brand copy.
  Play's fields differ in name and limits (Title ≤30, Short description ≤80,
  Full description ≤4000, no keywords field), so the copy is re-cut to those
  limits in a sibling `playstore/listing.md` rather than duplicated verbatim.

## Implementation

### Part A — Run it on your Pixel today

No code changes in this part. The goal is the app in your hand, on your own
device, as fast as possible — everything in Part B is build/store housekeeping
that can wait until you know the app feels right.

#### 1. Get the Android toolchain on PATH

`adb` and `emulator` are not on this shell's PATH, though the SDK is present at
`~/Library/Android/sdk` (currently only `platforms/android-34` and
`build-tools/34.0.0` are installed — which is exactly what the debug build needs,
since `compileSdk` is still 34. The SDK 36 platform gets installed later, in
step 5).

Add to the shell profile:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

And persist it for the codeyam editor server, which launches with a different
PATH than the interactive shell (documented in `android/MOBILE_SETUP.md`):

```bash
codeyam-editor editor config-override env.PATH "$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator:$PATH"
```

#### 2. Pair the Pixel and install the debug build

Manual, on-device — carry these as explicit instructions rather than automating
them:

1. On the Pixel: **Settings ▸ About phone ▸ tap "Build number" 7×** to unlock
   Developer options, then **Settings ▸ System ▸ Developer options ▸ USB
   debugging** on.
2. Connect over USB, accept the "Allow USB debugging?" RSA-fingerprint prompt
   on the phone, then confirm the device is visible:
   ```bash
   adb devices -l          # expect the Pixel listed as "device", not "unauthorized"
   ```
3. Build and install:
   ```bash
   android/gradlew -p android assembleDebug
   adb install -r android/app/build/outputs/apk/debug/app-debug.apk
   ```
   No signing setup is needed — Gradle signs debug builds with an
   auto-generated debug keystore.

Wireless alternative if USB is inconvenient: **Developer options ▸ Wireless
debugging ▸ Pair device with pairing code**, then `adb pair <ip:port>` and
`adb connect <ip:port>`.

Expect two cosmetic oddities in this build, both fixed in Part B and neither a
reason to stop: the app installs as **"Kotlin Android Compose"** with the stock
**green-triangle** icon.

`adb logcat --pid=$(adb shell pidof -s com.codeyam.android)` is the tail to
watch if anything crashes.

#### 3. First-pass smoke checklist (debug build)

What this pass can tell you — the feel of the app on real hardware, which no
emulator or unit test covers:

- **Haptics and sound.** `androidHapticEmitter` / `androidSoundEmitter`
  (`ui/AndroidFeedback.kt`) are pure hardware I/O and have **never run on a
  physical device** — only the option-gating logic is unit-tested. Check that
  each `SoundOption` (tock / pop / click) and each `HapticOption` is
  distinguishable and pleasant at tap speed, and that the `VIBRATE` permission
  in `AndroidManifest.xml` is sufficient with no runtime prompt. This is the
  single most valuable thing to learn early: if a cue feels wrong, it's a
  code change, and better found now than after the store assets are built.
- **Tap ergonomics one-handed** — the whole lower half is the increment target.
  Check reach on the Pixel's actual screen size, and toggle **left-handed
  layout** app-wide and per-counter.
- **Cold-start flash.** `android/app/src/main/res/values/themes.xml` parents
  `Theme.KotlinAndroidCompose` on `android:Theme.Material.Light.NoActionBar`
  while the app draws a near-black surface (`CounterColors.bg`), so expect a
  white flash on launch. Confirm it, since step 4 fixes it.
- **Graph page** with real history, and **large-value formatting**
  (`ui/CountFormat.kt`) at a count in the thousands.
- **Rotation and back-navigation** out of each of the four panels.
- **Scrolling and animation smoothness** at 120 Hz — Pixels run high-refresh
  displays that the emulator does not reproduce.

Note this build is debuggable, so `SeedPolicy.current(true)` →
`TRUST_INJECTED`: it will honor codeyam-injected scenario state and the
panel-open seed flags. That's correct for debug and is exactly the behavior
Part C checks is *absent* from the release build.

**Anything that feels wrong here is a code change to make before Part B.**
Fixing app behavior is cheap now and expensive once store assets and a release
pipeline are built around it.

### Part B — Make the app shippable

#### 4. Give the app its real name (and fix the launch theme)

**File**: `android/app/src/main/res/values/strings.xml`

`app_name` is still `Kotlin Android Compose` — that string is the launcher
label, the app-info entry, and the name in the Play "app installed" flow.
Change it to **`CodeYam Counter`**, matching the Play Console listing name so
the store entry and the installed app read the same.

Two notes, neither a blocker:

- This **diverges from iOS**, which installs as the shorter `Counter` via
  `CFBundleDisplayName` (see `.codeyam/store/appstore/README.md`). That's an
  accepted difference, not drift — record it in the Play assets README
  (step 13) alongside the applicationId note so it doesn't get "fixed" later.
- The Pixel launcher truncates labels at roughly 10–12 characters, so
  `CodeYam Counter` will render ellipsized under the icon. Confirm how it
  actually looks during the Part C device pass (step 11 checks the icon in the
  launcher, app drawer, recents, and Settings ▸ Apps — check the label in the
  same sweep). If the truncation reads badly, the fallback is a shorter
  `android:label` on the `<activity>` in `AndroidManifest.xml` while
  `<application android:label>` keeps the full name — the store listing name is
  set in Play Console regardless and is unaffected either way.

**File**: `android/app/src/main/res/values/themes.xml`

`Theme.KotlinAndroidCompose` is parented on
`android:Theme.Material.Light.NoActionBar`. The style *name* is cosmetic and
referenced from `AndroidManifest.xml` twice, so renaming is optional — but the
**Light** parent is not cosmetic: it's the white cold-start flash observed in
step 3. Reparent to a dark NoActionBar theme and set `android:windowBackground`
to the app's `bg` color so launch is seamless.

#### 5. Update SDK levels and version metadata

**File**: `android/app/build.gradle.kts`

- `compileSdk = 36`, `targetSdk = 36` (verify against Play Console's current
  requirement first). `minSdk` stays `24`. Install the SDK 36 platform and
  matching build-tools via Android Studio ▸ SDK Manager first — only
  `android-34` / `34.0.0` are present locally.
- `versionCode = 1` / `versionName = "1.0"` are correct for a first release.
  Add a comment recording the contract: **`versionCode` must increase on every
  single upload**, including re-uploads to the same track, and it can never be
  reused. This is the most common cause of a rejected Play upload.
- Consider deriving `versionCode` from an env var with a default
  (`versionCode = (System.getenv("VERSION_CODE") ?: "1").toInt()`) so the future
  CI workflow can pass `github.run_number`, exactly as `testflight.yml` passes
  `BUILD_NUMBER` for iOS. Keep the literal default so local builds work with no
  env set.

**File**: `android/gradle/libs.versions.toml`

AGP `8.3.1` predates `compileSdk 36` and will emit a "compileSdk not tested
with this AGP" warning — and may hard-fail on some AGP/SDK combinations. Bump
`agp` to a version that officially supports SDK 36, and bump the Gradle wrapper
in `android/gradle/wrapper/gradle-wrapper.properties` (currently `8.4`) to the
distribution that AGP version requires. Bump `composeBom` alongside it. Treat
this as one coordinated upgrade: change all four, then run
`android/gradlew -p android testDebugUnitTest` and confirm all existing JVM
tests under `android/app/src/test/` still pass before going further.

#### 6. Java toolchain pin

**File**: `android/app/build.gradle.kts`

`compileOptions` / `kotlinOptions` currently target Java 1.8, and the local
machine runs JDK 21 while CI pins JDK 17 (`.github/workflows/ci.yml`). That
mismatch is survivable today but is a real source of "works in CI, fails
locally" confusion. Add an explicit Kotlin/Java toolchain declaration so Gradle
provisions a consistent JDK regardless of what `java -version` reports, and
raise the target to Java 17 (AGP's current baseline). Confirm CI still passes
after this change — `.github/workflows/ci.yml`'s `android` job must stay green.

#### 7. Create the missing ProGuard rules file and enable R8

**New file**: `android/app/proguard-rules.pro`

`build.gradle.kts` already lists this file in `proguardFiles(...)`; it does not
exist on disk. It survives only because `isMinifyEnabled = false` means the
files are never consumed.

Create it with keep rules for `kotlinx.serialization` — `CounterModel`,
`Counter`, `CounterHistory`, `AppSettings`, and `SettingsOverlays` under
`com.codeyam.android.model` persist through `kotlinx-serialization-json` into
SharedPreferences, and R8 will strip the generated `$$serializer` companions
without explicit keeps. Use the rule set published in the kotlinx.serialization
README (keep `@Serializable` classes and their synthetic serializers), plus a
keep for `SeedPolicy.PROVENANCE_KEY`'s consumers if reflection is involved.

Then set `isMinifyEnabled = true` and `isShrinkResources = true` in the
`release` build type.

**This is the change most likely to produce a bug that no unit test catches** —
`android/app/src/test/` runs on the JVM against unminified classes, so a
stripped serializer only surfaces at runtime on a real release build. Step 11
is where it gets caught: specifically, incrementing a counter, force-stopping
the app, and reopening it to confirm state round-trips.

#### 8. Release signing config

**New file**: `android/keystore.properties.example`

A committed template documenting the four keys the build reads:
`storeFile`, `storePassword`, `keyAlias`, `keyPassword`.

**File**: `android/.gitignore`

Add `keystore.properties` and `*.jks` / `*.keystore` so the real file and the
keystore itself can never be committed. Mirror both entries into the root
`.gitignore`'s Android block (which already root-anchors `android/local.properties`
and `android/.gradle/` for tooling that only reads the root ignore file) — same
rationale, same place.

**File**: `android/app/build.gradle.kts`

Add a `signingConfigs { create("release") { ... } }` block that loads
`android/keystore.properties` if present, falling back to the
`ANDROID_KEYSTORE_*` env vars (so the future CI workflow needs no file), and
**skips signing entirely when neither is available** rather than throwing.
Wire `signingConfig = signingConfigs.getByName("release")` into the `release`
build type only when it was successfully configured.

The guard matters: `.github/workflows/ci.yml` runs `compileDebugKotlin` and
`testDebugUnitTest` on every push and PR with no keystore present. A signing
block that reads a missing file at configuration time would break CI for every
contributor.

**Keystore generation** (manual, one-time — the file itself is never committed):

```bash
keytool -genkeypair -v \
  -keystore ~/.android-keystores/codeyam-counter-upload.jks \
  -alias codeyam-counter-upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Store the keystore outside the repo and record the passwords in a password
manager. With Play App Signing this is the *upload* key only — recoverable via
Google support if lost — but losing it still means a support round-trip, so
back it up.

#### 9. Adaptive launcher icon

**Files**:
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (new)
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml` (new)
- `android/app/src/main/res/drawable/ic_launcher_foreground.xml` (new)
- `android/app/src/main/res/values/ic_launcher_background.xml` (new)
- density-bucket PNG fallbacks under `mipmap-mdpi` … `mipmap-xxxhdpi` for
  pre-API-26 devices (`minSdk 24` means API 24–25 devices exist and need them)
- `android/app/src/main/AndroidManifest.xml` — point `android:icon` at
  `@mipmap/ic_launcher` and add `android:roundIcon="@mipmap/ic_launcher_round"`
- `android/app/src/main/res/drawable/ic_launcher.xml` — delete the stock
  green-triangle vector once nothing references it

**File**: `.codeyam/store/appstore/gen_assets.py`

Extend the existing generator (it already draws the lime `+` mark and counter
dots from the brand tokens) to also emit the Android adaptive-icon foreground /
background layers, the density-bucket PNGs, and the **512×512 Play Store icon**.
Add an output directory `.codeyam/store/playstore/icon/`. Reusing this script is
what keeps the two stores' icons from drifting.

Note the adaptive-icon safe zone: the foreground layer is 108×108dp with only
the centered **66dp** guaranteed visible — the iOS 1024 artwork cannot be
dropped in unscaled or launcher masks will crop the `+`.

### Part C — Verify the release build on the Pixel

#### 10. Install the release build

The Pixel is already paired from step 2, so this is just a different artifact:

```bash
android/gradlew -p android assembleRelease
adb install -r android/app/build/outputs/apk/release/app-release.apk
```

Uninstall the debug build first (`adb uninstall com.codeyam.android`) — same
applicationId, different signing key, so the install will otherwise fail with
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Uninstalling also clears SharedPreferences,
which is what you want: it makes the fresh-install checks below meaningful.

`assembleRelease` requires the signing config from step 8 to be live — an
unsigned APK will not install. Build the APK here, not the AAB; an AAB can't be
`adb install`ed directly (step 12 covers testing the AAB itself).

#### 11. Release-build verification checklist

The release build differs from the Part A build in three ways that neither unit
tests nor the debug pass can cover: R8 minification, `isDebuggable = false`, and
upload-key signing. Focus the pass there rather than re-walking the whole app:

- **Persistence survives R8** (highest-risk item, see the minification decision):
  increment a counter, add a second counter with a different color, force-stop
  the app from Settings ▸ Apps, reopen. All counters, colors, and counts must be
  exactly as left. A `kotlinx.serialization` keep-rule gap shows up here as
  counters silently resetting to defaults.
- **`SeedPolicy` gating**: the release build is non-debuggable, so
  `SeedPolicy.current(false)` → `REQUIRE_PROVENANCE`. Fresh install must show
  the default counters from the app's own code path with **no panel open** — no
  scenario-injected state, no stray `appSettingsOpen=true`. This is the inverse
  of the debug behavior noted in step 3.
- **Launcher icon and label**: the adaptive icon renders correctly in the Pixel
  launcher under the circle mask, in the app drawer, in recents, and in
  Settings ▸ Apps — four different mask/size treatments, all worth a glance.
  Check the `CodeYam Counter` label in the same sweep; the launcher truncates
  around 10–12 characters, so confirm the ellipsized form reads acceptably
  (fallback in step 4 if not).
- **Cold-start flash gone**: confirm the `themes.xml` fix from step 4 removed
  the white launch flash observed in step 3.
- **Spot-check the app under R8**: open the graph, the counter list, and both
  settings panels. R8 failures are rarely subtle — a stripped class crashes on
  the screen that uses it — so exercising each surface once is enough.
- **Haptics and sound still fire**: already validated in step 3, but confirm R8
  didn't strip the emitters.

Anything that fails here goes back to Part B before Part D starts.

### Part D — Prepare the Play Store submission

#### 12. Build the App Bundle

Play requires an **AAB**, not an APK:

```bash
android/gradlew -p android bundleRelease
# → android/app/build/outputs/bundle/release/app-release.aab
```

Verify the AAB before uploading — a failed upload after a Console form is
filled out is a needless round-trip:

```bash
# Confirm it's signed with the expected upload key
jarsigner -verify -verbose -certs android/app/build/outputs/bundle/release/app-release.aab | head -20
```

Optionally install the AAB on the Pixel exactly as Play would deliver it (this
catches app-bundle splitting problems that `assembleRelease` cannot):

```bash
bundletool build-apks --bundle=app-release.aab --output=app.apks \
  --ks=<keystore> --ks-key-alias=<alias> --connected-device
bundletool install-apks --apks=app.apks
```

#### 13. Play Console listing assets

**New directory**: `.codeyam/store/playstore/`, mirroring the structure of the
existing `.codeyam/store/appstore/`.

**New file**: `.codeyam/store/playstore/listing.md`

Re-cut from `.codeyam/store/appstore/listing.md` to Play's fields and limits —
they do not map one-to-one:

| Play field | Limit | Source |
|---|---|---|
| App name | 30 | `CodeYam Counter` (15) — reuse as-is |
| Short description | **80** | The App Store *subtitle* is 27 chars and too terse; the App Store *short description* overruns 80. Write a new one at ≤80. |
| Full description | 4000 | Adapt the App Store description body. Keep the section structure; drop Apple-specific phrasing. |
| — | — | Play has **no keywords field** — the App Store `keywords` line has no equivalent and is dropped. Play indexes the title and descriptions instead. |

**New file**: `.codeyam/store/playstore/README.md`

Document the asset inventory, the two deliberate divergences from iOS — the
`com.codeyam.android` vs `com.codeyam.counter` applicationId, and the
`CodeYam Counter` vs `Counter` installed app name — so both read as decisions
rather than bugs, plus the upload-key location convention and the
`versionCode`-must-increase rule.

**Graphics** required by Play:

- **App icon**: 512×512 PNG, 32-bit — generated by the extended `gen_assets.py`
  in step 9.
- **Feature graphic**: 1024×500 PNG — **required**, no App Store equivalent
  exists, so this must be newly designed. Build it in `gen_assets.py` from the
  same brand tokens (dark `#0C0D08` field, lime `#D5F560` accent, counter dots)
  so it sits alongside the icon rather than looking bolted on.
- **Phone screenshots**: 2–8 required. The 53 existing Android scenario captures
  in `.codeyam/scenarios/screenshots/android-counter-*--phone-portrait.png` are
  **1080×2400** — already within Play's phone spec, no matting or reframing
  needed (unlike iOS, which required 1206×2622 → 1290×2796 frames). Select and
  copy roughly five into `.codeyam/store/playstore/screenshots/phone/`, mirroring
  the App Store's chosen narrative:
  1. `android-counter-large-value` — "Count anything"
  2. `android-counter-all-counters-list` — "Every tally, one tap away"
  3. `android-counter-graph-open` — "Watch it add up"
  4. `android-counter-counter-settings-open` — "Make it yours"
  5. `android-counter-app-settings-sound-and-haptic-on` — "One-handed by design"

  Note these captures predate Part B, so they show the **old launcher label and
  icon** only if either appears in-frame — they're in-app screenshots, so
  re-capture only if Part B changed something visible inside the app (the
  `themes.xml` reparent does not alter in-app rendering). Confirm before reusing.

  Decide whether to add the App Store's marketing captions. Play shows
  screenshots smaller in listings, so plain uncaptioned captures are a
  defensible choice — but be consistent across all five.

#### 14. Privacy policy URL — start this early

**Play requires one, and there is no way around it.** Google Play requires a
privacy policy URL for **every** app, regardless of whether it collects anything
— unlike the App Store, where it's conditional. It must be a public, live,
non-expiring URL that loads without a login and describes *this specific app*.
A dead link, a redirect to a generic company homepage, or a Google Doc behind
sign-in are all common rejection causes.

**Nothing in this repo records one.** A grep for "privacy" across the repo turns
up only `.codeyam/store/appstore/listing.md`, which still says the URL is
"required" and lists `https://codeyam.com/support` as an unconfirmed
placeholder, and `.codeyam/store/appstore/README.md`, which flags "URLs &
privacy: placeholders in `listing.md` — confirm before submitting."

**But the iOS app is live on the App Store**
(`apps.apple.com/us/app/codeyam-counter/id6789247345`), and Apple requires a
privacy policy URL for every published app. So one was necessarily supplied to
App Store Connect at submission — it just was never written back into the repo.

Resolution, in order:

1. **Look it up in App Store Connect** (App Information ▸ Privacy Policy URL)
   and reuse that exact URL. Same app, same zero-collection posture, so a
   second policy would be needless divergence.
2. **Record it in the repo** — replace the placeholder in
   `.codeyam/store/appstore/listing.md`, and write the confirmed URL into the
   new `.codeyam/store/playstore/listing.md` and README from step 13. Closing
   this gap stops the next submission from rediscovering it.
3. **If no policy exists** (or the one on file is a placeholder that Apple
   happened not to catch), publish one before touching Play Console. The
   content is short because the app genuinely collects nothing — the manifest
   requests only `VIBRATE`, there is no `INTERNET` permission, and all state
   lives in local SharedPreferences. It needs to state: what is collected
   (nothing), what leaves the device (nothing), no accounts, no analytics, no
   third-party SDKs, no ads, that data is removed when the app is uninstalled,
   a contact email, and a last-updated date. Host it anywhere stable and
   public — a page under `codeyam.com`, or a GitHub Pages page from this repo,
   which has the advantage of living next to the code it describes.

The same URL is entered in **two** Play Console places: the Store listing's
privacy policy field, and the Data safety form. This step is placed late in the
plan because that's where it's *consumed*, but it's the one item with an
external dependency — check App Store Connect for the existing URL while Part A
is still running, so it's never the thing blocking an upload.

#### 15. Play Console setup (manual, in the browser)

Steps the plan should enumerate but cannot automate:

1. **Google Play Developer account** — $25 one-time fee, and identity
   verification that can take days. Like step 14, start it early; it gates
   everything else in this part. Note the **organization vs. personal account**
   distinction: personal accounts created recently must run a closed test with
   **12 testers for 14 continuous days** before production access. This does not
   block the Internal testing track, but it does change the timeline to
   production — confirm which account type applies before planning a launch date.
2. **Create the app** in Play Console: name, default language, app-vs-game,
   free-vs-paid (free — matching iOS).
3. **Complete the required declarations.** These are the ones that actually
   block a release:
   - **Data safety form** — declare **no data collected, no data shared**.
     This mirrors the App Store privacy answers already recorded in
     `.codeyam/store/appstore/listing.md`: everything persists in local
     SharedPreferences, no network calls, no accounts, no analytics. The
     manifest confirms it — `VIBRATE` is the *only* permission requested, and
     there is no `INTERNET` permission.
   - **Privacy policy URL** — settled in step 14; entered here and in the Data
     safety form.
   - Content rating questionnaire, target audience, ads declaration (none),
     app category, contact details.
4. **Upload the AAB** to **Internal testing**, enroll the Pixel's Google account
   as a tester, and install via the generated opt-in link. Confirm the
   Play-delivered build behaves identically to the sideloaded one from step 10 —
   Play re-signs with the app signing key, so this is the first build signed the
   way real users will receive it.
5. Promote to **Closed → Open → Production** only after the Internal testing
   install is verified end to end.

### Part E — Follow-up (not built in this plan)

**New file (future)**: `.github/workflows/play-release.yml`

Mirror `.github/workflows/testflight.yml`: `workflow_dispatch` trigger,
base64-encoded keystore in `secrets.ANDROID_KEYSTORE_BASE64` decoded to
`$RUNNER_TEMP`, `versionCode` from `github.run_number` (the env-var hook added
in step 5), `bundleRelease`, then upload via the Google Play Developer API with
a service-account JSON key. The service account must be created in Play Console
**after** the app exists, which is why this is deferred rather than built now.

A companion `.codeyam/store/playstore/upload-play.sh` would parallel
`.codeyam/store/appstore/upload-testflight.sh` — same shape: env-var
preconditions, fail-fast preflight, build, upload.

## Reused existing code

- `SeedPolicy` from `android/app/src/main/java/com/codeyam/android/model/SeedPolicy.kt`
  — `REQUIRE_PROVENANCE` already makes release builds ignore codeyam-injected
  scenario state. No change needed; step 11 verifies it end to end for the first
  time in a genuinely non-debuggable build.
- `SystemCounterFeedback` / `androidHapticEmitter` / `androidSoundEmitter` from
  `android/app/src/main/java/com/codeyam/android/ui/AndroidFeedback.kt` — the
  real `Vibrator` / `ToneGenerator` I/O. Unchanged; exercised on hardware in
  step 3.
- `.codeyam/store/appstore/gen_assets.py` — brand-token-driven asset generator
  (bg `#0C0D08`, lime `#D5F560`, counter-dot palette). Extended in step 9 to
  emit Android adaptive-icon layers, density PNGs, the 512×512 Play icon, and
  the 1024×500 feature graphic.
- `.codeyam/store/appstore/listing.md` — reviewed App Store copy, re-cut to
  Play's field limits in step 13.
- `.codeyam/store/appstore/upload-testflight.sh` and
  `.github/workflows/testflight.yml` — the structural model for the deferred
  Play upload script and workflow in Part E.
- 53 Android scenario captures in `.codeyam/scenarios/screenshots/` at
  1080×2400 — used directly as Play phone screenshots, no reframing.
- `android/scripts/merge-test-results.py` and the `android-tests` runner in
  `.codeyam/editor.json` — the existing JVM test path that must stay green
  through the AGP/Gradle/SDK bumps in step 5.
- `.github/workflows/ci.yml` (`android` job) — must keep passing with no
  keystore present; this is what constrains the signing config to degrade
  gracefully in step 8.

## Scenarios to Demonstrate

- **Debug build on the Pixel, first run** — the app in hand on real hardware,
  before any build changes.
- **All sound and haptic options on a physical Pixel** — each cue
  distinguishable at tap speed, no runtime permission prompt.
- **Left-handed layout, app-wide and per-counter override** — thumb reach on a
  real device held in one hand.
- **Release build, fresh install, no seed data** — `SeedPolicy.REQUIRE_PROVENANCE`
  in effect: default counters, every panel closed, nothing injected.
- **Persistence round-trip under R8** — counters and colors survive a
  force-stop and relaunch. The regression this plan is most likely to
  introduce.
- **Large count with the graph open** — `CountFormat` at a four-digit value,
  history rendered.
- **Empty history graph** — a freshly created counter with nothing to plot.
- **Adaptive icon under the Pixel launcher's circle mask** — plus app drawer,
  recents, and Settings ▸ Apps.
- **Cold start against the dark surface** — white flash present in step 3,
  gone in step 11.
- **Play-delivered Internal testing install** — build re-signed by Play App
  Signing behaves identically to the sideloaded release APK.
