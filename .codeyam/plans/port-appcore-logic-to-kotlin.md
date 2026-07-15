---
title: "Port AppCore Logic to Kotlin"
mode: backend
createdAt: "2026-07-15T17:52:46Z"
source: manual
dependsOn: ["scaffold-android-app-kotlin-compose"]
---

## Summary

Port the iOS app's platform-independent domain logic — the counter model,
history/aggregation, seed policy, app settings, feedback abstraction, and theme
values — from Swift (`ios/Sources/AppCore/`) to Kotlin in the Android app, along
with a faithful port of their unit tests. This establishes logic parity between
the two apps with no Android UI yet: the Kotlin model behaves identically to
`CounterModel`, proven by the same test cases. UI work is the next plan.

## Key Decisions

- **Port pure logic first, UI later.** `Model.swift`, `History.swift`,
  `SeedPolicy.swift`, `AppSettings.swift`, `SettingsOverlays.swift`,
  `Feedback.swift`, and `Theme.swift` are (almost) UI-free and are the
  correctness core of the app. Porting them with their tests up front means the
  Compose UI later sits on an already-verified foundation.
- **Test-for-test parity, not approximate.** Each Swift test case
  (`ModelTests`, `AppSettingsTests`, `SettingsOverlaysTests`, `FeedbackTests`,
  `CounterFeedbackOverrideTests`, `ThemeTests`) gets a Kotlin equivalent with the
  same inputs and expectations, so any behavioral drift between platforms fails
  a test. `ModelTests.swift` is 1066 lines — the single biggest correctness
  asset in the repo — and is ported in full.
- **Keep the Kotlin API idiomatic.** Swift `struct`/`enum`/`ObservableObject`
  map to Kotlin `data class` / `enum class` / a `ViewModel`-style holder. The
  goal is behavioral parity, not a line-by-line transliteration — Kotlin naming
  and null-safety conventions win where they differ.
- **Feedback is an interface, mirroring the Swift protocol.** `CounterFeedback`
  (with `NoopCounterFeedback` / `SystemCounterFeedback`) becomes a Kotlin
  interface with a no-op and a system (haptic/sound) implementation, so the
  model stays free of Android framework types and stays unit-testable.

## Implementation

### 1. Port the counter model and history

**New files** (under `android/app/src/main/java/<pkg>/model/`, exact package per
the scaffold):

- `Counter.kt`, `CounterModel.kt` — ported from
  `ios/Sources/AppCore/Model.swift` (glossary: `Counter`, `CounterModel`).
- `CounterHistory.kt` — `CounterEvent`, `CounterHistory`, `CumulativePoint`
  from `ios/Sources/AppCore/History.swift`.
- `SeedPolicy.kt` — from `ios/Sources/AppCore/SeedPolicy.swift`.

Preserve the increment/step/delete/reorder semantics and the cumulative-history
aggregation exactly as the Swift model implements them.

### 2. Port settings, feedback, and theme

**New files**:

- `AppSettings.kt` — `AppSettings` + `HapticOption.resolve` from
  `ios/Sources/AppCore/AppSettings.swift`.
- `SettingsOverlays.kt` — from `ios/Sources/AppCore/SettingsOverlays.swift`.
- `CounterFeedback.kt` — the `CounterFeedback` interface plus
  `NoopCounterFeedback` and `SystemCounterFeedback` (Android haptics/sound)
  from `ios/Sources/AppCore/Feedback.swift`.
- `CounterTheme.kt` — the theme/color tokens from
  `ios/Sources/AppCore/Theme.swift`.

### 3. Port the unit tests

**New files** (under `android/app/src/test/java/<pkg>/`, JVM unit tests —
`kotlin.test` / JUnit per the scaffold's test config):

- `CounterModelTest.kt` ← `ModelTests.swift` (full port, all cases).
- `AppSettingsTest.kt` ← `AppSettingsTests.swift`.
- `SettingsOverlaysTest.kt` ← `SettingsOverlaysTests.swift`.
- `FeedbackTest.kt` ← `FeedbackTests.swift` + `CounterFeedbackOverrideTests.swift`.
- `CounterThemeTest.kt` ← `ThemeTests.swift`.

Every test keeps its mandatory description comment. Run with
`codeyam-editor editor refresh-tests` so the Gradle test runner (wired in the
scaffold plan) executes them and the results register.

### 4. Register the ported entities and tests

**Commands**:

- `codeyam-editor editor reconcile-glossary --auto-apply` then
  `glossary-update` to fill descriptions/tags for the new Kotlin entities,
  cross-referencing their Swift counterparts.
- `codeyam-editor editor reconcile-registry --auto-apply` to register the new
  Kotlin tests and link them to the ported entities.

## Reused existing code

- `ios/Sources/AppCore/Model.swift` (`CounterModel`, `Counter`) — ported source
  of truth for counter behavior.
- `ios/Sources/AppCore/History.swift` (`CounterHistory`, `CounterEvent`,
  `CumulativePoint`) — history/aggregation logic.
- `ios/Sources/AppCore/SeedPolicy.swift` (`SeedPolicy`) — initial-state seeding.
- `ios/Sources/AppCore/AppSettings.swift` (`AppSettings`, `HapticOption.resolve`),
  `SettingsOverlays.swift` (`SettingsOverlays`), `Feedback.swift`
  (`CounterFeedback`, `NoopCounterFeedback`, `SystemCounterFeedback`),
  `Theme.swift` (`CounterTheme`) — settings/feedback/theme sources.
- `ios/Tests/AppCoreTests/*` — the parity test suite being ported case-for-case.
- **Config-field survey:** this plan adds source + tests only; it introduces no
  new codeyam config field or gate dimension.

## Scenarios to Demonstrate

- Kotlin `CounterModel` increment/step/reset produces the same sequence of
  counts as the Swift model for the same operations (covered by the ported
  `CounterModelTest`).
- History cumulative points match the Swift `CumulativePoint` output for a
  representative event stream.
- `HapticOption.resolve` and settings-overlay resolution match the Swift results
  across the same inputs.
- All ported Kotlin tests pass under `refresh-tests`, and the audit reports the
  new entities as tested (no untested-entity regressions on the Android side).