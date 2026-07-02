---
title: "Per-Counter Handedness & Feedback Overrides"
mode: ui
createdAt: "2026-07-02T12:29:00Z"
source: manual
dependsOn: ["app-settings-and-feedback"]
---

## Summary

Let each counter optionally **override** the system-wide defaults introduced in
[[app-settings-and-feedback]]. In the per-counter settings panel, add three
tri-state controls — **handedness**, **sound on change**, and **haptic on
change** — each offering `Use default`, plus an explicit On/Off (or Left/Right).
Counters left on `Use default` follow the app settings and update retroactively
when the default changes; a counter that overrides pins its own value. The active
counter's **effective** handedness now drives the bottom-bar layout, and its
effective sound/haptic drive the feedback fired on increment/subtract.

## Key Decisions

- **Tri-state via optionals** (per the chosen "use-default + override" model) —
  add `handednessOverride: Bool?`, `soundOverride: Bool?`, `hapticOverride: Bool?`
  to `Counter`. `nil` = follow the app default; `true`/`false` = explicit override.
  Optionals decode cleanly for legacy persisted counters via
  `decodeIfPresent(...) ?? nil`, matching how `step`/`allowNegative` already
  handle older JSON.
- **Resolution lives on the model, not the view** — add
  `effectiveLeftHanded(default:)`, `effectiveSound(default:)`,
  `effectiveHaptic(default:)` (or a single `effectiveSettings(defaults:)`) so both
  the layout and the feedback closure resolve identically and it's unit-testable.
- **Handedness becomes per-active-counter** — Plan 1 fed the layout from the global
  default; now `ContentView` feeds it the *active counter's* effective handedness.
  The app-settings default still governs any counter on `Use default`, so the
  global toggle keeps working for the common case.
- **`For` = For the current counter** — the panel controls edit the active
  counter's overrides and are saved on `DONE` alongside name/color/step, extending
  the existing `updateActiveCounter` signature rather than adding new save paths.

## Implementation

### 1. Extend the Counter model with override fields

**File**: `Sources/AppCore/Model.swift`

- Add `public var handednessOverride: Bool?`, `soundOverride: Bool?`,
  `hapticOverride: Bool?` to `Counter`, all defaulting to `nil` in `init`.
- In `init(from:)`, decode each with `decodeIfPresent(Bool.self, forKey:) ?? nil`
  so pre-existing persisted counters and seeds decode unchanged.
- `defaultCounters()` leaves them `nil` (all four follow the app defaults).
- Add resolution helpers, e.g.:
  `func effectiveLeftHanded(default d: Bool) -> Bool { handednessOverride ?? d }`
  and the same shape for sound and haptic.

### 2. Update the save path

**File**: `Sources/AppCore/Model.swift`

- Extend `updateActiveCounter(name:colorKey:allowNegative:step:)` with
  `handednessOverride:soundOverride:hapticOverride:` and persist them.
- Blanking a counter (`deleteCounter`) resets the overrides to `nil` alongside the
  other neutral fields, so a revived slot starts on `Use default`.

### 3. Resolve effective feedback for the active counter

**File**: `Sources/AppCore/Model.swift` / `Sources/AppCore/ContentView.swift`

- The feedback closure set in Plan 1 now resolves through the active counter:
  `model.effectiveFeedback = { let c = model.activeCounter; return (c.effectiveSound(default: settings.soundEnabled), c.effectiveHaptic(default: settings.hapticEnabled)) }`.
- The bottom bar's `leftHanded` becomes
  `model.activeCounter.effectiveLeftHanded(default: settings.defaultLeftHanded)`.

### 4. Tri-state controls in the counter settings panel

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

- Add three `SettingsField`-wrapped segmented controls below the existing
  ALLOW NEGATIVE toggle:
  - **HANDEDNESS**: `Default` / `Left` / `Right` (`settings-handedness`).
  - **SOUND**: `Default` / `On` / `Off` (`settings-sound`).
  - **HAPTIC**: `Default` / `On` / `Off` (`settings-haptic`).
- Back each with a local `@State` optional (`Bool?`) seeded from the counter, and
  include them in the `onSave` call. A small three-segment picker component may be
  extracted (e.g. `TriStatePicker`) and reused across the three rows; style with
  `CounterTheme` tokens to match the existing panel.

**New file (optional)**: `Sources/AppCore/Views/TriStatePicker.swift` — a reusable
`Default / A / B` segmented control bound to a `Bool?`, if extracting keeps the
panel readable.

### 5. Wire effective handedness into the layout

**File**: `Sources/AppCore/ContentView.swift`

- Replace the `leftHanded` value passed to `CounterBottomBar` with the active
  counter's effective handedness (per step 3). Switching counters now re-resolves
  the layout, so a left-handed-override counter mirrors the bar only while active.
- Keep the app-settings default and the repointed `SWITCH`/global toggle working
  for counters on `Use default`.

### 6. Tests

**File**: `Tests/AppCoreTests/ModelTests.swift`

- `effectiveLeftHanded/Sound/Haptic` return the app default when the override is
  `nil` and the pinned value when set.
- `updateActiveCounter` round-trips the three overrides and persists them.
- A `nil`-override counter's effective value tracks a changed app default; an
  overriding counter does not.
- Legacy persisted counters without the override fields decode with `nil` overrides.
- Feedback fired on increment uses the active counter's effective sound/haptic
  (extends the Plan 1 feedback-spy test).

## Reused existing code

- `Counter` / `CounterModel` from `Sources/AppCore/Model.swift` (glossary entry:
  `CounterModel`, tested by `Tests/AppCoreTests/ModelTests.swift`).
- `AppSettings` / `CounterFeedback` from [[app-settings-and-feedback]]
  (`Sources/AppCore/AppSettings.swift`, `Sources/AppCore/Feedback.swift`) — the
  defaults these overrides resolve against and the sink they feed.
- `CounterSettingsPanel` from `Sources/AppCore/Views/CounterSettingsPanel.swift`
  (glossary entry: `CounterSettingsPanel`) — extend with the tri-state rows.
- `SettingsField` from `Sources/AppCore/Views/SettingsField.swift` (glossary entry:
  `SettingsField`) — caption wrapper for the new rows.
- `CounterTheme` from `Sources/AppCore/Theme.swift` (glossary entry: `CounterTheme`).
- `CounterBottomBar` from `Sources/AppCore/Views/CounterBottomBar.swift` (glossary
  entry: `CounterBottomBar`) — consumes the resolved handedness.

## Scenarios to Demonstrate

- **Counter settings with overrides on Default** — panel showing the three new
  tri-state rows all on `Default`.
- **Left-handed override on one counter** — a counter pinned to Left; its bottom
  bar mirrors while active even though the app default is Right.
- **Sound overridden Off on a noisy default** — app default sound On, but this
  counter's SOUND override is Off.
- **Haptic overridden On** — app default off, this counter's HAPTIC pinned On.
- **Switching counters re-resolves handedness** — active counter with a Left
  override vs. a neighbor on Default (Right), demonstrating the layout flips per
  active counter.
