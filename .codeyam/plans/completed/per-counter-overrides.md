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
"default-or-value" controls — **handedness**, **sound on change**, and **haptic
on change** — each offering `Use default` plus every explicit value:
- **HANDEDNESS**: `Default` / `Left` / `Right`
- **SOUND**: `Default` / `Tock` / `Pop` / `Click` / `Bloop` / `Ding` / `Off`
- **HAPTIC**: `Default` / `Light` / `Medium` / `Heavy` / `Off`

Counters left on `Use default` follow the app settings and update retroactively
when the default changes; a counter that overrides pins its own value. The active
counter's **effective** handedness now drives the bottom-bar layout, and its
effective sound/haptic drive the feedback fired on increment/subtract.

> **Design note (Prepare step):** the app's `app-settings-and-feedback` was
> implemented with multi-value enums (`SoundOption` = off/tock/pop/click/bloop/
> ding, `HapticOption` = off/light/medium/heavy), not booleans. The user chose a
> **full per-counter picker** so each counter can pin any specific option. The
> override fields are therefore typed as the enums, not `Bool?`. Handedness
> stays boolean.

## Key Decisions

- **Override via optionals** (per the chosen "use-default + override" model) —
  add `handednessOverride: Bool?`, `soundOverride: SoundOption?`,
  `hapticOverride: HapticOption?` to `Counter`. `nil` = follow the app default; a
  non-`nil` value = explicit override (including an explicit `.off`). Optionals
  decode cleanly for legacy persisted counters via `decodeIfPresent(...) ?? nil`,
  matching how `step`/`allowNegative` already handle older JSON; the enum
  overrides decode their `rawValue` string (`decodeIfPresent(String.self) ...`
  then `SoundOption(rawValue:)`), staying `nil` on absent/unrecognized values.
- **Resolution lives on the model, not the view** — add
  `effectiveLeftHanded(default:) -> Bool`, `effectiveSound(default:) -> SoundOption`,
  `effectiveHaptic(default:) -> HapticOption` (or a single `effectiveSettings(defaults:)`) so both
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

- Add `public var handednessOverride: Bool?`, `soundOverride: SoundOption?`,
  `hapticOverride: HapticOption?` to `Counter`, all defaulting to `nil` in `init`.
- In `init(from:)`, decode `handednessOverride` with
  `decodeIfPresent(Bool.self, forKey:) ?? nil`; decode the enum overrides from
  their `rawValue` string (`decodeIfPresent(String.self, forKey:)` →
  `SoundOption(rawValue:)` / `HapticOption(rawValue:)`, staying `nil` when absent
  or unrecognized) so pre-existing persisted counters and seeds decode unchanged.
  Encode the enum overrides back as `rawValue` strings.
- `defaultCounters()` leaves them `nil` (all four follow the app defaults).
- Add resolution helpers, e.g.:
  `func effectiveLeftHanded(default d: Bool) -> Bool { handednessOverride ?? d }`,
  `func effectiveSound(default d: SoundOption) -> SoundOption { soundOverride ?? d }`,
  and the same shape for haptic.

### 2. Update the save path

**File**: `Sources/AppCore/Model.swift`

- Extend `updateActiveCounter(name:colorKey:allowNegative:step:)` with
  `handednessOverride:soundOverride:hapticOverride:` and persist them.
- Blanking a counter (`deleteCounter`) resets the overrides to `nil` alongside the
  other neutral fields, so a revived slot starts on `Use default`.

### 3. Resolve effective feedback for the active counter

**File**: `Sources/AppCore/Model.swift` / `Sources/AppCore/ContentView.swift`

- The feedback resolution now resolves through the active counter:
  `let c = model.activeCounter; feedback.changed(sound: c.effectiveSound(default: settings.soundOption), haptic: c.effectiveHaptic(default: settings.hapticOption))`.
- The bottom bar's `leftHanded` becomes
  `model.activeCounter.effectiveLeftHanded(default: settings.defaultLeftHanded)`.

### 4. Override pickers in the counter settings panel

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

- Add three `SettingsField`-wrapped "default-or-value" controls below the existing
  ALLOW NEGATIVE toggle. Each prepends a `Default` choice to the value list:
  - **HANDEDNESS**: `Default` / `Left` / `Right` (`settings-handedness`). Three
    segments fit a segmented control.
  - **SOUND**: `Default` + every `SoundOption` (`Tock`/`Pop`/`Click`/`Bloop`/
    `Ding`/`Off`) (`settings-sound`).
  - **HAPTIC**: `Default` + every `HapticOption` (`Light`/`Medium`/`Heavy`/`Off`)
    (`settings-haptic`).
- Back each with a local `@State` optional (`Bool?` for handedness,
  `SoundOption?` / `HapticOption?` for the others) seeded from the counter, where
  `nil` selects the `Default` segment; include them in the `onSave` call. Style
  with `CounterTheme` tokens to match the existing panel.
- Because SOUND (7) and HAPTIC (5) exceed a comfortable segmented-control width,
  render those two as a compact `Menu`/wheel or a horizontally scrollable chip row
  with a leading `Default` chip, rather than a fixed segmented control. Handedness
  stays a 3-segment control.

**New file (optional)**: `Sources/AppCore/Views/OverridePicker.swift` — a reusable
`Default`-plus-values picker generic over a `CaseIterable & RawRepresentable`
option bound to an optional, if extracting keeps the panel readable.

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
  `nil` and the pinned option when set (including an explicit `.off` override
  winning over a non-`.off` default).
- `updateActiveCounter` round-trips the three overrides and persists them (enum
  overrides survive an encode/decode cycle as their `rawValue`).
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
- `SoundOption` / `HapticOption` enums from `Sources/AppCore/AppSettings.swift` —
  the value sets the per-counter overrides pin (each override typed as the
  optional enum).
- `CounterSettingsPanel` from `Sources/AppCore/Views/CounterSettingsPanel.swift`
  (glossary entry: `CounterSettingsPanel`) — extend with the override-picker rows.
- `SettingsField` from `Sources/AppCore/Views/SettingsField.swift` (glossary entry:
  `SettingsField`) — caption wrapper for the new rows.
- `CounterTheme` from `Sources/AppCore/Theme.swift` (glossary entry: `CounterTheme`).
- `CounterBottomBar` from `Sources/AppCore/Views/CounterBottomBar.swift` (glossary
  entry: `CounterBottomBar`) — consumes the resolved handedness.

## Scenarios to Demonstrate

- **Counter settings with overrides on Default** — panel showing the three new
  override rows all on `Default`.
- **Left-handed override on one counter** — a counter pinned to Left; its bottom
  bar mirrors while active even though the app default is Right.
- **Sound overridden Off on a noisy default** — app default sound `Ding`, but this
  counter's SOUND override is `Off`.
- **Haptic overridden to a specific option** — app default `.off`, but this
  counter's HAPTIC pinned to `Heavy`.
- **Switching counters re-resolves handedness** — active counter with a Left
  override vs. a neighbor on Default (Right), demonstrating the layout flips per
  active counter.
