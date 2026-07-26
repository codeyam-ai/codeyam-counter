---
title: "Reconcile iOS scenario staleness and fix Android capture + tooling gaps"
mode: ui
createdAt: "2026-07-22T22:21:43Z"
source: manual
---

## Summary

Cleanup and maintenance pass for loose ends and tooling defects surfaced while
building the Android Counter UI in Compose. The Android UI feature itself is
complete, tested (156 Kotlin tests green), and its 12 scenarios are captured and
pixel-verified — but committing it is currently blocked by spurious iOS scenario
staleness, and the session exposed several editor/tooling gaps worth fixing
before they bite the next Android session. This plan groups the work as an
ordered checklist; item 1 is highest priority because it blocks landing the
Android UI commit.

## Key Decisions

- **Split "unblock the commit" from "fix the tooling."** Item 1 is the only thing
  gating the pending Android UI commit; items 2–6 are independent quality/tooling
  work that can land separately. They are grouped here because they share a root
  cause — the project runs two native targets (iOS + Android) through tooling that
  was built assuming one.
- **Prefer fixing the name-keyed staleness over forcing a recapture.** The iOS
  gallery is provably unchanged (0 pixels, 0 source), so the "correct" fix is to
  stop a same-named Android glossary entry from cross-marking iOS scenarios stale.
  Recapturing iOS is the fallback, and it is currently impossible anyway (see
  item 1), so the staleness fix is the durable path.
- **Editor-tooling items (5, and the tooling half of 4) are `codeyam-editor` bugs,
  not app bugs.** They are captured here so the app repo has a record, but the fix
  lands in the `codeyam-editor` crate.

## Implementation

### 1. Reconcile iOS scenario staleness (unblocks the Android UI commit)

**Files**: `.codeyam/stack.json`, `App.xcodeproj/` (missing `project.pbxproj`),
`.codeyam/scenarios/screenshots/*--iphone-16.png.hash` (32 drifted sidecars)

The Android UI session added glossary entries whose names collide with existing
iOS views (`CountHero`, `GraphPage`, `CounterSettingsPanel`, `HeaderBar`,
`CounterListPanel`, and ~21 others). The render-input staleness computation is
keyed by entry **name**, so touching the Android `CountHero` entry marked the iOS
`counthero-*` scenarios stale. Result: `stage-feature` refuses the commit,
reporting ~80 stale iOS scenarios, while `git status` confirms **zero** iOS PNGs
and **zero** iOS source files changed — only 32 `.png.hash` render-input sidecars
drifted.

Two independent fixes; do the first to unblock now, the second to prevent
recurrence:

- **Restore a buildable iOS project, then recapture the iOS gallery.** The active
  committed stack is Android (`kotlin-android-compose`, switched from
  `swift-ios-swiftui` in commit `8a81625`). To recapture iOS, `stack.json` must be
  swapped to the iOS config (recoverable from `git show 8a81625^:.codeyam/stack.json`),
  the iOS simulator booted, and `recapture-stale` run. **Blocker:**
  `App.xcodeproj/project.pbxproj` is absent from disk **and** untracked in git — the
  directory holds only `project.xcworkspace` and `xcuserdata` — so `xcodebuild`
  fails with "cannot be opened because it is missing its project.pbxproj file".
  Wire up whatever regenerates the project file (XcodeGen / Tuist / a committed
  `project.pbxproj`), then recapture. The recaptured frames will be byte-identical;
  only the sidecars refresh.

- **Fix the name-keyed cross-marking (durable fix, `codeyam-editor`).** Staleness
  should key on `(name, filePath)` — the glossary's own primary key — not `name`
  alone, so a same-named entry on a different target/file never cross-marks another
  target's scenarios. This removes the whole class of "touch Android, iOS goes
  stale" churn.

### 2. Wire Android sound & haptics

**File**: `android/app/src/main/java/com/codeyam/android/MainActivity.kt:42`

`SystemCounterFeedback()` is constructed with its **default no-op emitters**. The
option gating (a non-`OFF` haptic fires `emitHaptic`, a non-`OFF` sound fires
`emitSound`) is unit-tested in `FeedbackTest`, but neither emitter is connected to
a real Android API, so feedback is silent on device. Supply the emitters at
construction: an `emitHaptic` bridging `HapticOption` to `Vibrator` /
`VibratorManager` (or `View.performHapticFeedback`), and an `emitSound` bridging
`SoundOption` to a short `SoundPool`/`ToneGenerator` cue. Keep the emitter
functions injectable so the existing gating tests stay hardware-free.

### 3. Add an Android component-isolation harness

**Files**: `android/app/build.gradle.kts`, `android/gradle/libs.versions.toml`,
new `android/app/src/test/.../*Previews.kt`, `.codeyam/glossary.json` (26 entries)

`codeyam-editor editor isolate <Component>` scaffolds a **Paparazzi** preview into
a foreign package (`com.example.codeyam.codeyamisolated`) under a stray repo-root
`app/` tree, and Paparazzi is not configured — so no Android composable can be
captured in isolation. The 26 Android visual components are consequently recorded
with `untestabilityReason { kind: "no-isolation-harness" }` (currently the honest
classification, since page-level application scenarios do not credit a component
entry — they were only passing the audit by sharing a name with an iOS view that
has a real component scenario). Configure Paparazzi (or another Compose screenshot
harness), fix the `isolate` scaffold to target the real package
(`com.codeyam.android.ui`) and tree, capture per-component scenarios, then drop the
`no-isolation-harness` reasons. If a proper harness is out of scope, at minimum fix
`isolate` so it scaffolds into the correct package/tree instead of a stray one.

### 4. Aggregate all runners in the test cache and journal

**Files**: `.codeyam/editor.json` (the `android-tests` runner — already patched
this session), `.codeyam/test-cache/all.json`, `codeyam-editor` cache/journal
writers

Two layers here. The **app-side** fix already shipped this session: the
`android-tests` runner needed `--rerun-tasks` (Gradle's `test` task goes
UP-TO-DATE and writes no XML on a re-run) plus a merge step
(`android/scripts/merge-test-results.py`) because Gradle writes one JUnit file per
class while the reader wants one file. That made all 277 tests (121 Swift + 156
Kotlin) visible to `refresh-tests`.

The **editor-side** defect remains: the persisted `test-cache/all.json` stores
only a **single** runner (`runners` has 1 entry, `tests`), so the journal's
`testResults` reports 121, not 277 — the Kotlin runner's results are dropped from
the cache even though `refresh-tests` counts them correctly at run time. Make the
cache and the journal's `testResults` aggregate every configured runner.

### 5. Editor capture-pipeline reliability (codeyam-editor)

**File**: `codeyam-editor` capture path (`register`, `recapture-stale`, the
plausibility check)

Multiple defects observed capturing the 12 Android scenarios:

- **Blank-frame false success.** `register` has a fixed ~2s settle and no
  `settleMs` flag. A force-stopped cold Android launch does not paint within 2s,
  so `register` writes a **solid white pre-paint frame** and still reports
  `Screenshot: <file>` as success. At one point 7 of 12 committed screenshots were
  blank white.
- **The integrity checks don't catch it.** `seeded-capture-check` and
  `distinct-capture-check` only prove frames are *distinct*, never *correct* — each
  blank frame was unique enough to pass both. Found only by pixel-screening the PNGs
  by hand (grayscale-crop off the bars, flag `mean > 180 or stdev < 12`).
- **Pipeline degradation.** The emulator capture path decays after ~4–6 captures
  and only a full `adb emu kill` + cold boot restores it.
- **`recapture-stale` can't target Android.** It resolves the iOS app as the active
  target, so every Android slug returns `skipped_cross_target` and is then reported
  "already fresh" while nothing is written; a project-wide run also tries to
  recapture the whole iOS gallery against the Android emulator (only the
  content-sanity guard prevents damage).

Suggested fixes: thread `settleMs` through `register` with a per-stack default;
add a non-blank/plausibility gate to the capture (reject a near-uniform frame);
classify "frame never stabilized" as restart-eligible so the existing
restart-recovery fires instead of bucketing to `otherFailures`; make
`recapture-stale` target-aware in a multi-target project. The working manual
recipe until then: force-stop → `preview` with `settleMs: 15000` → `register` →
verify the PNG is not blank.

### 6. Fix the reconcile-glossary qualified-name false positive (codeyam-editor)

**File**: `codeyam-editor` glossary reconciler (Swift entity scanner)

`reconcile-glossary` proposes **removing** `HapticOption.resolve`
(`ios/Sources/AppCore/AppSettings.swift:33`), a `static func` that exists and is
called in **5** places across `AppSettings.swift` and `Model.swift`. The Swift
scanner cannot express the qualified `Type.method` name, so it reads the entry as
orphaned; `reconcile-glossary --auto-apply` would delete a live, tested glossary
entry. Fix the scanner to resolve qualified names (or exclude nested type members
from the orphan set) so `--auto-apply` is safe to run.

## Reused existing code

- `SystemCounterFeedback` from `android/app/src/main/java/com/codeyam/android/model/CounterFeedback.kt`
  (glossary entry: `SystemCounterFeedback`) — item 2 supplies its `emitHaptic` /
  `emitSound` constructor arguments, which already default to no-ops.
- `HapticOption` / `SoundOption` from
  `android/app/src/main/java/com/codeyam/android/model/AppSettings.kt`
  (glossary entries: `HapticOption`, `SoundOption`) — the enums item 2's emitters
  map to Android APIs.
- `android/scripts/merge-test-results.py` — the JUnit merge step added this session;
  item 4's editor-side fix should make it unnecessary or fold its behavior in.
- iOS `stack.json` config recoverable from `git show 8a81625^:.codeyam/stack.json`
  — item 1's target swap.
- `HapticOption.resolve` from `ios/Sources/AppCore/AppSettings.swift:33` (glossary
  entry: `HapticOption.resolve`) — item 6's false-positive subject; **exists, do not
  remove**.

## Scenarios to Demonstrate

- iOS gallery recaptured (or staleness fix applied) so `stage-feature` reports 0
  stale iOS scenarios and the Android UI commit lands.
- Android device with sound + a non-`OFF` haptic: incrementing emits real feedback.
- A captured Android component scenario (e.g. `CounterDot`, `IncrementBar`)
  rendered in isolation once a harness exists.
- Journal `testResults` reads 277 (both runners), not 121.
- A capture run that produces a blank frame is rejected rather than committed.
- `reconcile-glossary` on the iOS tree proposes no removal of `HapticOption.resolve`.