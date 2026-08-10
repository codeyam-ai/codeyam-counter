---
title: "ne -- Target Android 16 (API 36) for continued Play updates"
prefix: "ne"
mode: ui
createdAt: "2026-08-07T00:00:00Z"
source: manual
---

## Summary

CodeYam Counter is **live on Google Play** and now non-compliant: Play reports the
highest non-compliant target API level as Android 15 (API 35). Apps must target
**Android 16 (API 36)** or higher. From **Oct 31, 2026**, an app whose target API
is not within one year of the latest Android release **cannot be updated at all**.

This is an availability deadline, not a warning — missing it freezes the app on
the store. Nothing about the app's behaviour needs to change for users; what
changes is the toolchain underneath it and two platform behaviours that API 36
makes unconditional.

The bump is **not a one-line change**. `targetSdk = 36` requires `compileSdk = 36`,
which the current Android Gradle Plugin cannot compile against, which in turn
forces a Gradle upgrade — and the snapshot-test harness that landed days ago has
no stable release that works at API 36 at all.

## The toolchain cascade

| | Current | Target |
|---|---|---|
| `targetSdk` / `compileSdk` | 35 | **36** |
| Android Gradle Plugin | 8.3.1 | **8.13.x** |
| Gradle | 8.7 | **8.13+** (AGP 8.13 floor) |
| SDK Build-Tools | 34.0.0 | 35.0.0+ (AGP 8.13 default; the Android 16 guide asks for 36.x) |
| Installed SDK platforms | `android-34`, `android-35` | `android-36` |
| Paparazzi | 1.3.5 | **2.0.0-alpha05** |
| CI JDK | 17 | **21** — forced by Paparazzi, not by AGP |

### Why AGP 8.13 rather than the documented 8.9 floor

[Set up the Android 16 SDK](https://developer.android.com/about/versions/16/setup-sdk)
names **8.9.0-rc01** as the minimum for `compileSdk = 36`, but that is only a
floor. The
[AGP 8.9.0 release notes](https://developer.android.com/build/releases/past-releases/agp-8-9-0-release-notes)
still list **maximum API level 35**, so 8.9 would compile against 36 while
continuing to emit the untested-SDK warning — precisely the state this build is
already papering over today.

[AGP 8.13.0](https://developer.android.com/build/releases/past-releases/agp-8-13-0-release-notes)
lists **maximum API level 36.1**, making it the first line that genuinely supports
API 36. It requires Gradle 8.13 and JDK 17.

This also converges with Paparazzi: **2.0.0-alpha05 is itself built against AGP
8.13.2**. Picking 8.13.x satisfies the API 36 requirement and the snapshot harness
with one decision instead of two independent guesses.

**Consequence:** `android/gradle.properties` carries
`android.suppressUnsupportedCompileSdk=35`. On AGP 8.13 that suppression is
unnecessary, so **delete the line** rather than bumping it to 36 — retaining it
would go on hiding exactly the class of warning we are upgrading to stop needing.

### SDK provisioning

CI provisions the SDK through `android-actions/setup-android@v4`, so the runner
needs no change. Locally there is **no `cmdline-tools`/`sdkmanager`**, but
`~/Library/Android/sdk/licenses/android-sdk-license` is present, so AGP's
automatic SDK download should fetch platform 36 and matching build-tools on the
first build. If it does not, install them via Android Studio's SDK Manager rather
than adding a cmdline-tools dependency to the repo.

## The blocker: Paparazzi has no stable API 36 release

**Paparazzi 1.3.5 crashes on `compileSdk 36`**
([cashapp/paparazzi#1877](https://github.com/cashapp/paparazzi/issues/1877), closed
against milestone **2.0.0-alpha02**). 1.3.5 is still the latest *stable* release
and there is no 1.3.x backport, so the fix exists only in the 2.0.0 alpha line.

This collides directly with work that landed on 2026-07-29 (`f03e67b`): Paparazzi
renders Compose components off-device, `verifyPaparazziDebug` is a CI gate at
`.github/workflows/ci.yml:58`, and two goldens are committed under
`android/app/src/test/snapshots/images/`.

**Decision: upgrade to the 2.0.0 alpha line.** Paparazzi is a `testImplementation`
harness — it is never packaged into the AAB and cannot reach a user. Alpha risk is
contained to CI, and the alternative is discarding a component-isolation gate the
project just gained and has wanted for a long time.

The alpha line moved its own floors, so the version choice is not arbitrary:

- `2.0.0-alpha02` — first with `compileSdk 36`; built against AGP 8.10.1.
- `2.0.0-alpha03` — deprecated by upstream; skip.
- `2.0.0-alpha04` — AGP 8.13.2, and **requires Java 21+**.
- `2.0.0-alpha05` — latest; AGP 8.13.2, supports pre-AGP 9.0 consumers.

**Target `2.0.0-alpha05`**, since it matches the AGP 8.13.x chosen above. There is
no stable 2.0.0 release, so an alpha is unavoidable if the gate is to survive.

Because alpha04 explicitly requires Java 21 and alpha05 shares its AGP baseline,
plan on **CI moving off `java-version: "17"`** (`.github/workflows/ci.yml:40`).
The comment at `ci.yml:36` explains the JDK 17 choice in terms of "Gradle 8.7 +
AGP" — it must be rewritten in the same edit rather than left contradicting the
code. Confirm the actual Java floor empirically; do not bump CI's JDK if the build
is green without it.

## Behaviour change that needs real code: edge-to-edge

Android 15 already enforces edge-to-edge for apps targeting 35; **Android 16 makes
it unconditional** — the `windowOptOutEdgeToEdgeEnforcement` escape hatch is
ignored at target 36.

The app has **no inset handling anywhere**. A grep across `android/app/src/main`
for `enableEdgeToEdge`, `WindowInsets`, `systemBars`, `safeDrawing`, and
`setDecorFitsSystemWindows` returns nothing. Meanwhile `res/values/themes.xml`
still sets `android:statusBarColor` and `android:navigationBarColor`, both of
which are **deprecated no-ops on API 35+** — they are already doing nothing.

Because the app is already at target 35, this is very likely a **live defect on
Android 15 devices today**, not merely a future risk. Verifying that on a real
API 35/36 device is part of this work, not an afterthought.

### The subtle part: where the padding goes

`CounterScreen` drives its entire layout off `BoxWithConstraints`:

```kotlin
val screenHeight = maxHeight
val screenWidth = maxWidth
```

Under edge-to-edge those constraints become the **full window**, including the
status and navigation bar regions. Hero sizing, the increment target's lower-half
geometry, and the bottom bar are all computed from them.

Apply the inset padding **outside** `BoxWithConstraints` so `maxHeight` /
`maxWidth` continue to describe *usable* space. Applying it inside would leave
every derived measurement computed against full-window height while the content
is visually inset — the classic "correct on the device I tested, wrong on the one
with a bigger nav bar" failure.

Keep the window background itself edge-to-edge (the app is a uniform near-black,
so the bars should blend), and ensure the status-bar icons are light-on-dark via
the appearance APIs rather than the dead colour attributes.

### Out of scope for this cycle (deliberate)

**Predictive back.** It defaults on at target 36, and the app has no back handling
at all — `BackHandler`, `onBackPressed`, and `enableOnBackInvokedCallback` are all
absent, so back exits the app even with a settings, list, or graph panel open.
That is a genuine UX gap but it is a *separate behavioural feature* needing its
own scenarios; folding it in here would widen the diff on a deadline-driven
compliance change. Queue it as a follow-up plan.

## Not affected

- **16 KB page sizes** — required at target 36 only for apps with native code.
  This app is pure Kotlin/Compose with no NDK, so it is N/A.
- **Large-screen orientation/resizability** — Android 16 ignores orientation
  restrictions on large screens; the app already has the `MaxContentWidth` tablet
  layout and declares no orientation lock, so nothing to undo.
- **`draft` in `play-release.yml`** — already defaults to `false` (line 46). Now
  that the app is published, simply leave it off; no edit required.
- **Permissions** — `VIBRATE` remains the only one; API 36 changes nothing here.

## Release

- Bump `versionName` from `"1.0"` (`android/app/build.gradle.kts:47`) to reflect a
  user-facing update.
- `versionCode` needs no scheme change: `play-release.yml` derives it as
  `110000 + GITHUB_RUN_NUMBER` and remains the sole uploader, so monotonicity holds.
- Ship via the existing `play-release.yml` production path. Consider a staged
  rollout (`rollout` < 1.0) rather than a full one, since this cycle changes the
  build toolchain and window handling on a live app.

## Verification

1. `android/gradlew -p android testDebugUnitTest` and `testReleaseUnitTest` green
   on both variants (baseline: debug 171, release 169).
2. `android/gradlew -p android verifyPaparazziDebug` green on the upgraded
   Paparazzi. If goldens shift, re-record and inspect the diff — a changed golden
   here is evidence, not noise.
3. `android/gradlew -p android bundleRelease` produces a signed AAB with R8 still
   enabled and `mapping.txt` present.
4. **On-device on API 36**: confirm the hero numeral and bottom control row clear
   the status and navigation bars, that the background still runs edge to edge,
   and that no cold-start flash regressed.
5. Confirm in Play Console that the target API warning clears after the update
   reaches production.

## Scenarios to demonstrate

Edge-to-edge is a visual change to the app's outermost layout, so it is exactly
what scenario captures are for. Re-capture the main counter states at API 36 and
compare against the current goldens; the top and bottom margins are where a
regression would show.

## Open

The user has more requirements to add to this cycle ("the targetSDK is the first
piece"). Fold them in before implementation begins rather than treating this file
as final.
