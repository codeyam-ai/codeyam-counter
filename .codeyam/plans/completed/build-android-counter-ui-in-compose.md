---
title: "Build Android Counter UI in Compose"
mode: ui
createdAt: "2026-07-15T17:52:49Z"
source: manual
dependsOn: ["port-appcore-logic-to-kotlin"]
---

## Summary

Build the Android counter UI in Jetpack Compose on top of the already-ported
Kotlin domain logic, matching the iOS app's screens and interactions: the
count hero, increment bar, multi-counter list/switcher, per-counter and app
settings panels, color picker, and the history graph. Then capture the Android
scenarios that mirror the iOS scenario gallery, so the same app states are
visible on both platforms in codeyam-editor.

## Key Decisions

- **Match the iOS view inventory screen-for-screen.** The iOS UI in
  `ios/Sources/AppCore/Views/` decomposes into ~25 small views. Rebuild the
  equivalent set as Compose composables so the two apps present the same states
  — this is what makes the scenario galleries comparable.
- **Composables bind to the ported `CounterModel`.** The UI is a thin,
  declarative layer over the Kotlin model from the previous plan; no new domain
  logic is introduced in this plan. Feedback (haptics/sound) routes through the
  Kotlin `CounterFeedback` interface.
- **Capture scenarios via the Android emulator.** Reuse the same simulator
  capture path the iOS app uses (`start-simulator kotlin-android-compose`),
  seeding each scenario's `deviceState` so the emulator renders the intended
  state — verified distinct by `seeded-capture-check`.
- **Mirror the existing scenario slugs.** Reproduce the iOS gallery states
  (active count, all-counters list, blank slot selected/incremented, app
  settings open, sound+haptic on, all-but-one-deleted) so reviewers can diff the
  platforms state-by-state.

## Implementation

### 1. Build the core counter screen in Compose

**New files** (under `android/app/src/main/java/<pkg>/ui/`):

- `CounterScreen.kt` — top-level screen ≈ `ContentView.swift`.
- `CountHero.kt`, `IncrementBar.kt`, `IncrementFaceButton.kt` — the tap-to-count
  hero + increment controls (≈ `CountHero`, `IncrementBar`,
  `IncrementFaceButtonStyle`).
- `CounterDot.kt`, `AddCounterDot.kt`, `CounterSwitcherCard.kt`,
  `CounterListPanel.kt` — the multi-counter switcher/list.

### 2. Build settings and customization UI

**New files**:

- `AppSettingsPanel.kt`, `CounterSettingsPanel.kt`, `SettingsField.kt`,
  `SettingsToggleRow.kt`, `CounterStepStepper.kt` — settings panels
  (≈ the matching Swift views).
- `CounterColorPicker.kt`, `GearButton.kt`, `DeleteCounterButton.kt` —
  customization controls.
- Overlay/anchoring behavior equivalent to `HeaderAnchoredOverlay` /
  `SettingsOverlays`.

### 3. Build the history graph

**New files**:

- `GraphPage.kt`, `CounterGraphChart.kt`, `GraphHeader.kt`,
  `GraphCloseButton.kt` — the cumulative-history chart
  (≈ `CounterGraphView` / `CounterGraphChart`), driven by the ported
  `CumulativePoint` data.

### 4. Capture the Android scenario set

**Command**: `codeyam-editor editor start-simulator kotlin-android-compose`, then
capture each state through the App-Scenarios flow with a seeded `deviceState`:

- `counter-active-count`
- `counter-all-counters-list`
- `counter-all-counters-list-with-blank-slot`
- `counter-added-blank-slot-selected`
- `counter-blank-slot-incremented`
- `counter-app-settings-open`
- `counter-app-settings-sound-and-haptic-on`
- `counter-all-but-one-deleted`

Run `codeyam-editor editor seeded-capture-check` afterward to confirm distinct
seeds produced distinct screenshots (guards against screenshotting ambient
emulator state).

### 5. Register UI entities

**Commands**: `reconcile-glossary --auto-apply` + `glossary-update` for the new
composables; add interaction/scenario tests where the Compose UI has testable
behavior (e.g. increment updates the displayed count).

## Reused existing code

- `ios/Sources/AppCore/Views/*` — the screen-for-screen reference for the
  Compose inventory (`CountHero`, `IncrementBar`, `CounterListPanel`,
  `AppSettingsPanel`, `CounterSettingsPanel`, `CounterColorPicker`,
  `CounterGraphChart`, `CounterSwitcherCard`, `AddCounterDot`, …).
- The Kotlin `CounterModel` / `CounterHistory` / `CounterTheme` /
  `CounterFeedback` from the logic-port plan — the UI binds to these, adding no
  new domain logic.
- `.codeyam/scenarios/` iOS scenario definitions — the slug list and intended
  states the Android captures mirror.
- `codeyam-editor editor start-simulator kotlin-android-compose` /
  `seeded-capture-check` — the emulator capture + verification path.
- **Mechanism-feasibility (per-scenario state):** per-scenario state is
  delivered through each scenario's seeded `deviceState` on the emulator (the
  MockEngine/seed path), read on scenario activation — not via a launch-time env
  var. This matches how the iOS app already seeds native scenarios.

## Scenarios to Demonstrate

- `counter-active-count` on Android visually matches the iOS capture.
- `counter-app-settings-open` and `counter-app-settings-sound-and-haptic-on`
  render the settings panel and toggle states.
- `counter-all-counters-list` / `…-with-blank-slot` show the multi-counter
  switcher, including the add-blank affordance.
- `counter-all-but-one-deleted` shows the single-counter edge state.
- Tapping the hero increments the displayed count (interaction), driven by the
  ported model.