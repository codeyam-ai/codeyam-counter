---
title: "ne -- App Settings Panel Stale Selection"
prefix: "ne"
mode: ui
createdAt: "2026-07-27T20:04:05Z"
source: manual
---

## Summary

In the Android app, tapping **LEFT** or **RIGHT** in the HANDEDNESS picker of the
App Settings panel (the top-right sliders button) applies the change — the bottom
bar visibly flips — but the picker's own highlight stays on the previously
selected option. The setting is written and persisted correctly; only the panel's
rendering is stale.

The cause is a Compose recomposition-scope gap, and it affects **all four
controls in that panel**, not just handedness. `AppSettingsPanel` is invoked from
`CounterScreen`'s outer `BoxWithConstraints` content scope, which reads only the
four `mutableStateOf` overlay flags and never reads `CounterScreenState.revision`
— the counter that every model mutation bumps. So `settingsChanged()` bumping
`revision` does not recompose that scope, and the panel is never re-invoked.
Meanwhile the panel reads `settings.defaultLeftHanded` (and the three feedback
options) straight off `AppSettings`, a deliberately framework-free class of plain
Kotlin `var`s with nothing observable to subscribe to. The inner `Column` scope
*does* read `revision` via `state.leftHanded`, which is why the bottom bar flips
and the highlight doesn't — the two halves of the reported symptom.

The fix routes the panel's reads through revision-keyed getters on
`CounterScreenState`, matching the pattern that layer already uses for every
other model read, and passes plain values into `AppSettingsPanel` instead of the
mutable `AppSettings` object. A Compose UI test harness (Robolectric +
`ui-test-junit4`) is added because this class of bug is invisible to both the
existing JVM unit tests and to static scenario captures.

## Key Decisions

- **Fix all four controls in the panel, not just handedness.** HANDEDNESS, SOUND
  ON CHANGE, INCREMENT HAPTIC and DECREMENT HAPTIC all read plain `AppSettings`
  vars from a scope that never recomposes — one root cause, four symptoms.
  Handedness is simply the one where the bottom bar flipping proves the tap
  registered, making the stale highlight obvious; the other three go unnoticed
  because a chip that doesn't move looks like a tap that missed. Fixing only the
  reported control would leave three identical bugs in the same panel.
- **Route reads through `CounterScreenState`, don't make `AppSettings`
  observable.** `AppSettings` lives in `model/` and is deliberately Compose- and
  Android-free so it stays JVM-unit-testable — `CounterScreenState`'s own KDoc
  states this is intentional, and the `revision` counter exists precisely to
  bridge it to Compose. Backing `AppSettings` with `mutableStateOf` would pull
  Compose into the model layer and break `AppSettingsTest`'s dependency-free
  setup. The revision-keyed getter is the pattern the codebase already chose;
  this is a place it was simply not applied.
- **Read the new getters inside the overlay's content lambda, not at the top of
  `CounterScreen`.** `HeaderAnchoredOverlay(content: @Composable () -> Unit)`
  (`PanelChrome.kt:43-46`) makes its content a separate restartable scope, so
  reading `state.defaultLeftHanded` *there* subscribes only that lambda to
  `revision`. Reading it in the outer `BoxWithConstraints` scope would work too,
  but would recompose the entire screen on every increment, since `revision`
  bumps on every count change. Same fix, tighter blast radius.
- **Pass values into `AppSettingsPanel`, not the `AppSettings` object.** Turning
  the panel into a value-driven composable (four values + four callbacks) makes
  it renderable in a test and in a `@Preview` without constructing a store, and
  removes the unstable-parameter footgun where the panel's correctness silently
  depends on a caller-side recomposition it can't see. This mirrors
  `CounterBottomBar`, which already takes `leftHanded: Boolean` rather than
  reaching into state.
- **Keep the panel write-through; do not add local draft state.** The panel's
  KDoc is explicit that it "holds no local edit state: every control writes
  straight through to the persisted default, so there is no save/cancel."
  Mirroring the values into `remember` would mask the symptom while leaving the
  observation gap in place, and would introduce a desync path the per-counter
  panel avoids only because it has an explicit DONE-saves boundary.
- **Add Compose UI test infrastructure.** A static scenario capture cannot catch
  this: a scenario seeds `leftHanded` before launch, so the panel renders
  correctly on *first* composition — the bug only exists on *re*-composition
  after a tap. The existing JVM tests can't catch it either, since they assert on
  state getters and never compose anything. Robolectric + `ui-test-junit4` lets a
  plain `testDebugUnitTest` run tap the control and assert the highlight moved.
  This is new dependency surface, but it's the only thing that actually guards
  the fix, and it unlocks interaction tests for the rest of the UI.
- **Assert on `contentDescription` semantics, which the components already
  carry.** `Chip` and the handedness options are tagged (`app-settings-sound-*`,
  `app-settings-handedness`, …) for scenario capture. Tests can reuse those
  identifiers rather than introducing a parallel `testTag` vocabulary — but note
  `HandednessOption` currently sets no per-option identifier, only the wrapping
  Row does (see step 2).

## Implementation

### 1. Expose the App Settings values as revision-keyed state

**File**: `android/app/src/main/java/com/codeyam/android/ui/CounterScreenState.kt`

Add four getters alongside the existing `leftHanded` (line 74-75), each reading
`revision` so the calling composable subscribes to it:

```kotlin
val defaultLeftHanded: Boolean get() = revision.let { settings.defaultLeftHanded }
val soundOption: SoundOption get() = revision.let { settings.soundOption }
val incrementHapticOption: HapticOption get() = revision.let { settings.incrementHapticOption }
val decrementHapticOption: HapticOption get() = revision.let { settings.decrementHapticOption }
```

Note the distinction from the existing `leftHanded`, and keep both: `leftHanded`
is the *effective* value for the active counter (its override, else the app
default) and drives the bottom bar; `defaultLeftHanded` is the raw app-wide
default the panel edits. Naming them apart matters — conflating them would make
the panel show the active counter's override.

Add matching mutators that write through and bump the revision in one place,
replacing the `settings.x = it; onChanged()` pairs the panel currently does at
each call site:

```kotlin
fun setDefaultLeftHanded(value: Boolean) = mutate { settings.defaultLeftHanded = value }
fun setSoundOption(value: SoundOption) = mutate { settings.soundOption = value }
fun setIncrementHapticOption(value: HapticOption) = mutate { settings.incrementHapticOption = value }
fun setDecrementHapticOption(value: HapticOption) = mutate { settings.decrementHapticOption = value }
```

`settingsChanged()` (line 161) becomes unused once the panel routes through
these. Remove it rather than leaving a second, now-redundant way to bump the
revision — a leftover no-arg `mutate {}` invites exactly the "write then forget
to notify" split this bug came from.

### 2. Make `AppSettingsPanel` value-driven

**File**: `android/app/src/main/java/com/codeyam/android/ui/AppSettingsPanel.kt`

Replace the `settings: AppSettings` + `onChanged: () -> Unit` parameter pair with
explicit values and callbacks:

```kotlin
fun AppSettingsPanel(
    leftHanded: Boolean,
    soundOption: SoundOption,
    incrementHapticOption: HapticOption,
    decrementHapticOption: HapticOption,
    onLeftHandedChange: (Boolean) -> Unit,
    onSoundChange: (SoundOption) -> Unit,
    onIncrementHapticChange: (HapticOption) -> Unit,
    onDecrementHapticChange: (HapticOption) -> Unit,
    availableHeight: Dp,
    onOpenList: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
)
```

Update the four control call sites (lines 56-94) to use them, and drop the
`import com.codeyam.android.model.AppSettings`. Rewrite the KDoc: the current
text explains `onChanged` in terms of `AppSettings` having "no observable
streams" — replace it with a note that the panel is a pure value-driven view and
that its caller is responsible for supplying values that recompose (pointing at
the revision-keyed getters), so the next person doesn't reintroduce the gap.

**Also add a per-option identifier to `HandednessOption`** (lines 114-135). Only
the wrapping `HandednessControl` Row carries `app-settings-handedness`; the two
options carry none, so neither a test nor a scenario can address LEFT and RIGHT
individually. Add an `identifier` parameter and set
`app-settings-handedness-left` / `-right` via `semantics { contentDescription = … }`,
matching the `$idPrefix-${label.lowercase()}` convention `Chip` already uses in
`SettingsControls.kt:313` and `:348`.

### 3. Update the call site

**File**: `android/app/src/main/java/com/codeyam/android/ui/CounterScreen.kt`

In the `if (state.showAppSettings && !state.showCounterList)` block (lines
143-153), read the new getters **inside** the `HeaderAnchoredOverlay` content
lambda so the subscription lands on that scope:

```kotlin
HeaderAnchoredOverlay(anchor = { header() }) {
    AppSettingsPanel(
        leftHanded = state.defaultLeftHanded,
        soundOption = state.soundOption,
        incrementHapticOption = state.incrementHapticOption,
        decrementHapticOption = state.decrementHapticOption,
        onLeftHandedChange = { state.setDefaultLeftHanded(it) },
        onSoundChange = { state.setSoundOption(it) },
        onIncrementHapticChange = { state.setIncrementHapticOption(it) },
        onDecrementHapticChange = { state.setDecrementHapticOption(it) },
        availableHeight = screenHeight,
        onOpenList = { state.openCounterList() },
        onClose = { state.closeAppSettings() },
    )
}
```

`screenHeight` is captured from the outer `BoxWithConstraints` scope, which is
fine — it's a `Dp` value, not a state read.

### 4. Audit the other overlays for the same gap

The same structural condition — a panel invoked from the outer scope, reading
values that don't subscribe to `revision` — could affect the other three
overlays. Check each rather than assuming:

- **`CounterSettingsPanel`** (lines 112-133): reads `state.activeCounter` inside
  the overlay content lambda, so it already subscribes to `revision`. It also
  holds `remember(counter.id)` draft state and saves on DONE, so live external
  updates aren't expected. **Likely fine** — confirm, don't change.
- **`CounterListPanel`** (lines 157-166): reads `state.counters` and
  `state.activeCounter.id` inside the content lambda → subscribes. **Likely
  fine.**
- **`GraphPage`** (lines 169-178): reads `state.activeCounter` and
  `state.activeHistories` inside the content lambda → subscribes. **Likely
  fine.**

If all three check out, say so in the commit message — the audit is worth
recording even when it finds nothing, since "why wasn't this fixed everywhere"
is the obvious follow-up question.

### 5. Add Compose UI test infrastructure

**File**: `android/gradle/libs.versions.toml`

Add versions and libraries for `robolectric`, `androidx.compose.ui:ui-test-junit4`
(from the existing `composeBom` platform, so no separate version), and
`androidx.test:core`. Robolectric is what lets these run under
`testDebugUnitTest` on the JVM rather than needing a booted emulator — which
matters because `.github/workflows/ci.yml`'s `android` job runs on
`ubuntu-latest` with no emulator, and the `android-tests` runner in
`.codeyam/editor.json` invokes `gradlew -p android test`.

**File**: `android/app/build.gradle.kts`

- Add `testImplementation` entries for the above plus
  `debugImplementation(libs.androidx.compose.ui.test.manifest)` (the test
  manifest must be on the debug variant, not the test one — a common setup
  mistake that produces a confusing "no activity found" failure).
- Enable `testOptions { unitTests { isIncludeAndroidResources = true } }`, which
  Robolectric requires to resolve resources.

Keep these on the **test** configurations only so no new dependency reaches the
release APK — worth verifying against the `ne--android-pixel-device-test-and-play-store-submission`
plan's R8 work, since new test deps that leak into `implementation` would show up
in the shipped bundle.

### 6. Regression tests

**New file**:
`android/app/src/test/java/com/codeyam/android/ui/AppSettingsPanelInteractionTest.kt`

The test that actually reproduces the bug. Compose `CounterScreen` with a real
`CounterScreenState` seeded `appSettingsOpen = true`, then:

1. Assert the RIGHT option renders as selected (handedness defaults to false).
2. `onNodeWithContentDescription("app-settings-handedness-left").performClick()`.
3. Assert LEFT now renders selected **and** RIGHT does not.

Step 3 is the whole point: against the current code it fails, because the panel
never recomposes. Verify that it fails before applying steps 1-3 — a regression
test that passes against the broken code is worse than none.

Asserting "renders as selected" needs a signal the semantics tree exposes.
Selection is currently only a color difference (`CounterColors.accent` background,
`onAccent` text), which the semantics tree doesn't carry. Add `selected = …` to
the `semantics` block on the handedness options and on `Chip`
(`SettingsControls.kt:358-385`) via the `selected` semantics property, then
assert with `assertIsSelected()` / `assertIsNotSelected()`. This is the right fix
independent of testing — it's also what makes the pickers legible to TalkBack,
which today announces both options identically with no indication of which is
active.

Cover the other three controls the same way, at least one assertion each: tap a
different `SoundOption` chip and assert the selection moved.

**File**: `android/app/src/test/java/com/codeyam/android/ui/CounterScreenStateTest.kt`

Add plain JVM coverage for the new getters and mutators — cheap, fast, and they
pin the `leftHanded` vs `defaultLeftHanded` distinction that step 1 introduces:

- `setDefaultLeftHanded(true)` makes `defaultLeftHanded` true.
- With an active counter pinning `handednessOverride = false`,
  `defaultLeftHanded` reports `true` while `leftHanded` reports `false` — the
  panel edits the app default, the bar renders the effective value.
- Each of the three feedback setters round-trips through its getter.

The existing `leftHandedFollowsTheAppDefaultWithoutAnOverride` test (line 155)
sets `s.settings.defaultLeftHanded` directly; leave it as-is — it pins the
effective-value delegation and is unaffected by this change.

### 7. Scenario coverage

Add a scenario capturing the App Settings panel with **LEFT** selected, alongside
the existing `android-counter-app-settings-open` and
`android-counter-app-settings-sound-and-haptic-on`. Seed `leftHanded = true` and
`appSettingsOpen = true`.

Be clear about what this does and doesn't buy: it will render correctly *even
against the broken code*, because seeding happens before first composition and
the bug is strictly a re-composition failure. It is not a regression guard — step
6 is. It's worth adding anyway so the panel's left-handed state is visible in the
gallery and in review diffs, and so a future change that breaks the *initial*
render is caught.

## Reused existing code

- `CounterScreenState.revision` / `mutate` from
  `android/app/src/main/java/com/codeyam/android/ui/CounterScreenState.kt` — the
  existing Compose-bridging pattern. The fix applies it where it was missed
  rather than introducing a new mechanism.
- `CounterScreenState.leftHanded` (same file, line 74) — the model for the new
  revision-keyed getters, and the effective-value counterpart the new
  `defaultLeftHanded` must stay distinct from.
- `HeaderAnchoredOverlay` from
  `android/app/src/main/java/com/codeyam/android/ui/PanelChrome.kt:43` — its
  `content: @Composable () -> Unit` parameter is what makes the tight
  recomposition scope in step 3 possible.
- `Chip` / `OptionPicker` from
  `android/app/src/main/java/com/codeyam/android/ui/SettingsControls.kt:326-385`
  — already carry `$idPrefix-$label` content descriptions; step 2 extends the
  same convention to the handedness options, and step 6 adds `selected`
  semantics to `Chip` itself.
- `CounterBottomBar`'s `leftHanded: Boolean` parameter
  (`android/app/src/main/java/com/codeyam/android/ui/CounterBottomBar.kt`) — the
  precedent for a value-driven panel rather than one reaching into state.
- `CounterScreenStateTest` helper `state(...)` from
  `android/app/src/test/java/com/codeyam/android/ui/CounterScreenStateTest.kt:20`
  — constructs a state over an `InMemoryKeyValueStore`; reuse it for both the new
  unit tests and the Compose test's fixture.
- `AppSettingsTest` from
  `android/app/src/test/java/com/codeyam/android/model/AppSettingsTest.kt` —
  already pins persistence and provenance for all four settings. Unchanged; it's
  the evidence that the *model* half of this feature is correct and the bug is
  purely in observation.
- `.codeyam/editor.json`'s `android-tests` runner and
  `android/scripts/merge-test-results.py` — the new Compose tests run under the
  same `gradlew -p android test` command and flow into the same JUnit XML, so no
  runner config changes are needed.

## Scenarios to Demonstrate

- **App Settings open, RIGHT selected** — the default state, highlight on RIGHT.
- **App Settings open, LEFT selected** — the new capture; panel highlight on LEFT
  with the app-wide default set.
- **Tap LEFT with the panel open** — highlight moves to LEFT *and* the bottom bar
  mirrors, both in the same frame. The bug is exactly the case where only the
  second half happens.
- **Tap a different SOUND ON CHANGE chip** — selection moves; the same defect as
  handedness, with no bottom-bar tell to reveal it.
- **Tap an INCREMENT HAPTIC chip, then a DECREMENT HAPTIC chip** — the two rows
  track independently and neither resets the other.
- **Active counter with a handedness override, panel open** — the panel shows the
  app-wide default while the bar renders the counter's override; editing the
  default does not visibly move the bar. Guards the `leftHanded` vs
  `defaultLeftHanded` distinction.
- **Reopen the panel after changing handedness** — the new value is still
  selected, confirming the write persisted and the fix didn't turn the control
  into display-only local state.
