---
title: "App Settings & Feedback"
mode: ui
createdAt: "2026-07-02T12:28:11Z"
source: manual
---

## Summary

Introduce a **system-wide app settings** surface. Replace the passive
"NN / 04 COUNTERS" position label in the header with an **app settings button**
that opens an inline **App Settings** panel. The panel holds three system-wide
defaults — **handedness** (left/right), **sound on change**, and **haptic on
change** — plus a **list all counters** action that opens a simple list of every
counter (name + count) you can tap to select. Increment and subtract begin
emitting sound and/or haptic feedback per these defaults, routed through a small,
test-friendly feedback abstraction. This is the first of three plans; per-counter
overrides ([[per-counter-overrides]]) and the Graph ([[counter-graph-and-history]])
build on the store and feedback plumbing introduced here.

## Key Decisions

- **A dedicated `AppSettings` store, not scattered `@AppStorage`** — today
  handedness lives as a lone `@AppStorage("leftHanded")` in `ContentView`.
  Consolidate handedness, sound, and haptic into one `ObservableObject`
  (`AppSettings`) backed by UserDefaults, mirroring `CounterModel`'s seeding
  contract (scenarios inject `deviceState.preferences`). This gives Plan 2 a
  single default source to resolve per-counter overrides against.
- **Two independent booleans for sound & haptic** — the user asked for "sound, or
  haptic, or both." Two toggles (`soundEnabled`, `hapticEnabled`) express all four
  combinations (neither / sound / haptic / both) without a mode enum.
- **Header button replaces the position label** — the "NN / 04 COUNTERS" text is
  removed from `HeaderBar` and replaced with a tappable settings button (distinct
  from the per-counter gear on the switcher card, which stays). Reuse the
  `GearButton` styling/idiom but with a `slider.horizontal.3` (sliders) glyph and
  a new `app-settings` identifier so the two settings entry points don't collide.
- **App Settings panel mirrors `CounterSettingsPanel`** — same floating-overlay
  pattern (anchored under the header, drawn on top, `DONE` to close), reusing
  `SettingsField` and `CounterTheme` tokens so it feels native to the app.
- **Feedback behind a protocol** — increment/subtract call a `CounterFeedback`
  abstraction. The production implementation uses `UINotificationFeedbackGenerator`
  /`UIImpactFeedbackGenerator` (haptic) and `AudioServicesPlaySystemSound` (sound),
  guarded by `#if canImport(UIKit)`. A no-op default keeps unit tests and the
  macOS/preview builds silent and deterministic, and lets `ModelTests` assert
  "feedback requested" via a spy without real audio/haptics.
- **SWITCH stays, repointed** — the bottom-row `SWITCH` button currently toggles
  handedness. Repoint it to toggle `AppSettings.defaultLeftHanded` so behavior is
  unchanged and this plan ships demonstrable. Its removal (replaced by GRAPH)
  is [[counter-graph-and-history]]'s job.

## Implementation

### 1. New system-wide settings store

**New file**: `Sources/AppCore/AppSettings.swift`

A `public final class AppSettings: ObservableObject` backed by `UserDefaults`,
following `CounterModel`'s seeding contract (read keys in `init`, coerce
string-injected seeds, persist on change):

- `@Published public var defaultLeftHanded: Bool` — key `"leftHanded"` (reuse the
  existing key so on-device preference and existing `counter-left-handed-layout`
  scenario carry over).
- `@Published public var soundEnabled: Bool` — key `"soundEnabled"` (default `false`).
- `@Published public var hapticEnabled: Bool` — key `"hapticEnabled"` (default `false`).
- Static key constants + a documented seeding note like the one atop `CounterModel`.
- Persist each on `didSet`.

### 2. Feedback abstraction

**New file**: `Sources/AppCore/Feedback.swift`

- `public protocol CounterFeedback { func changed(sound: Bool, haptic: Bool) }`
- `SystemCounterFeedback` — real implementation. `#if canImport(UIKit)` uses a
  light impact haptic and `AudioServicesPlaySystemSound` (a short system sound id)
  when the respective flag is true; `#else` no-op.
- `NoopCounterFeedback` — default for tests/previews.

### 3. Route increment/subtract through feedback

**File**: `Sources/AppCore/Model.swift`

- Give `CounterModel` an injected `feedback: CounterFeedback` (default
  `NoopCounterFeedback()`), and an injected/settable source of the effective
  sound/haptic flags. For this plan the flags come straight from `AppSettings`;
  Plan 2 swaps in the per-counter effective resolution. Simplest wiring: add
  `public func increment(sound:haptic:)` / `subtract(sound:haptic:)` params, OR
  hold a closure `var effectiveFeedback: () -> (sound: Bool, haptic: Bool)` the
  view sets. Choose the closure approach so the model stays UI-agnostic and Plan 2
  only changes the closure body.
- In `increment()` and `subtract()`, after mutating, call
  `feedback.changed(sound:haptic:)` with the resolved flags. Do **not** fire on the
  `subtract` no-op clamp (count already at/below zero, `allowNegative == false`).
- Keep `reset()`/`undoReset()` silent (no change-feedback).

### 4. App Settings panel view

**New file**: `Sources/AppCore/Views/AppSettingsPanel.swift`

An inline panel (styled exactly like `CounterSettingsPanel`) bound to
`AppSettings`, containing:

- Header row: `"APP SETTINGS"` caption + a `DONE` button (`app-settings-close`).
- A **HANDEDNESS** control — a two-way segmented/labeled toggle
  (`Left` / `Right`) writing `defaultLeftHanded` (`app-settings-handedness`).
- A **SOUND** `Toggle` → `soundEnabled` (`app-settings-sound`).
- A **HAPTIC** `Toggle` → `hapticEnabled` (`app-settings-haptic`).
- An **ALL COUNTERS** button (`app-settings-list`) that opens the counter list
  (below). Use `SettingsField` captions and `CounterTheme` tokens throughout.

### 5. Counter list view

**New file**: `Sources/AppCore/Views/CounterListPanel.swift`

A simple scrollable list of every counter: colored dot + name (em-dash for blank
slots) + current count, each row tappable to select that counter and dismiss the
list. Row identifier `counter-list-row-<id>`; a back/close affordance
(`counter-list-close`). Reuse `CounterTheme.dotColor` and the blank-slot
em-dash/muted treatment from `CounterSwitcherCard`.

### 6. Header button replaces the position label

**File**: `Sources/AppCore/Views/HeaderBar.swift`

- Remove the `positionLabel` parameter and the `"\(positionLabel) COUNTERS"`
  `Text`. Replace the trailing element with an app-settings button (GearButton-like
  styling, `slider.horizontal.3` glyph, identifier `app-settings`), taking an
  `onSettingsTap: () -> Void`. Keep the `CODEYAM COUNTER` brand text.
- `CounterModel.positionLabel` becomes unused by the header; leave it on the model
  (harmless, still unit-tested) or note it may be removed later — do not remove it
  in this plan to avoid churning `ModelTests`.

### 7. Wire settings + list into the screen

**File**: `Sources/AppCore/ContentView.swift`

- Replace the `@AppStorage("leftHanded")` property with
  `@StateObject private var settings = AppSettings()`; read
  `settings.defaultLeftHanded` where `leftHanded` was used.
- Add `@State private var showAppSettings = false` and
  `@State private var showCounterList = false` (seedable from preferences like
  `settingsOpen`, e.g. `appSettingsOpen` / `counterListOpen`, so static captures
  can render them open).
- `headerBar` passes `onSettingsTap: { withAnimation { showAppSettings.toggle() } }`.
- When `showAppSettings`, overlay `AppSettingsPanel` (same floating pattern as the
  counter settings overlay), with `onOpenList: { showCounterList = true }`.
- When `showCounterList`, overlay `CounterListPanel` wired to `model.select(id:)`.
- Set `model.effectiveFeedback = { (settings.soundEnabled, settings.hapticEnabled) }`
  and pass `SystemCounterFeedback()` into `CounterModel` (via an initializer or a
  settable property). In previews/tests the default no-op is used.
- Repoint `onSwitch` to `{ withAnimation { settings.defaultLeftHanded.toggle() } }`.

### 8. Tests

**File**: `Tests/AppCoreTests/ModelTests.swift` (and a new
`Tests/AppCoreTests/AppSettingsTests.swift`)

- `AppSettings` reads seeded string-injected preferences and persists changes
  (round-trip through a scratch `UserDefaults(suiteName:)`).
- Increment/subtract call the feedback spy with the resolved `(sound, haptic)`
  flags; the `subtract` no-op clamp does **not** fire feedback; `reset`/`undoReset`
  stay silent.

## Reused existing code

- `CounterModel` / `Counter` from `Sources/AppCore/Model.swift` (glossary entry:
  `CounterModel`, tested by `Tests/AppCoreTests/ModelTests.swift`) — extend with
  the feedback hook; reuse its UserDefaults seeding contract for `AppSettings`.
- `GearButton` from `Sources/AppCore/Views/GearButton.swift` (glossary entry:
  `GearButton`) — style/idiom reference for the new header app-settings button.
- `CounterSettingsPanel` from `Sources/AppCore/Views/CounterSettingsPanel.swift`
  (glossary entry: `CounterSettingsPanel`) — overlay/`DONE` pattern to mirror.
- `SettingsField` from `Sources/AppCore/Views/SettingsField.swift` (glossary entry:
  `SettingsField`) — labeled-section wrapper for the new toggles.
- `CounterTheme` from `Sources/AppCore/Theme.swift` (glossary entry: `CounterTheme`,
  tested by `Tests/AppCoreTests/ThemeTests.swift`) — colors/tokens and `dotColor`.
- `CounterSwitcherCard` from `Sources/AppCore/Views/CounterSwitcherCard.swift`
  (glossary entry: `CounterSwitcherCard`) — blank-slot em-dash / muted treatment to
  reuse in the counter list.

## Scenarios to Demonstrate

- **Header shows the settings button** — the position label is gone; the header
  brand sits opposite a sliders/settings button.
- **App Settings open** — panel overlaying the screen with HANDEDNESS, SOUND, and
  HAPTIC controls and the ALL COUNTERS button, in a default (all-off, right-handed)
  state.
- **Sound + haptic both on** — the panel with both toggles enabled.
- **Left-handed default set** — handedness set to Left; the bottom bar renders its
  mirrored layout (reuses the existing left-handed layout).
- **All counters list** — the counter list overlay showing the four starter
  counters with dots, names, and counts.
- **All counters list with a blank slot** — one slot blank (em-dash placeholder)
  among live counters.
