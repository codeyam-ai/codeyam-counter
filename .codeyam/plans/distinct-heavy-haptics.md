---
title: "Distinct Heavy Haptics"
mode: ui
createdAt: "2026-07-12T10:53:01Z"
source: manual
---

## Summary

The haptic option list is confusing: `light`/`medium`/`heavy` are just amplitude
variants of the same tap (which is stronger? does it matter?), padding the picker
without adding meaningfully different feels. Replace those three amplitude cases
with a small set of **qualitatively distinct** feels that are all strong ("heavy"):
the new `HapticOption` set is **OFF, SOFT, SHARP, DOUBLE, BUZZ**. `SOFT` and
`SHARP` are impact taps fired at full intensity (cushioned vs. crisp); `DOUBLE`
and `BUZZ` are inherently strong multi-tap notification patterns (a rising
two-tap and a three-tap rumble). The per-counter panel keeps its **DEFAULT**
(follow-app) chip unchanged — only the option list behind it changes. The
directional default pairing stays distinct: increment `SHARP`, decrement `SOFT`
(the same crisp-up / dull-down feel as today's rigid/soft, just renamed).

## Key Decisions

- **Distinct feels, not amplitudes** — drop `light`/`medium`/`heavy`; keep the two
  qualitatively-different impacts (`soft`, and `rigid` renamed to `sharp`) and add
  two notification-generator patterns (`double` = `.success`, `buzz` = `.error`).
  These four are easy to tell apart on-device; amplitude siblings were not.
- **All fired strong** — the two impacts pass `intensity: 1.0` to
  `UIImpactFeedbackGenerator.impactOccurred(intensity:)` so neither reads as
  "weak"; the notification patterns are already pronounced. This satisfies the
  "all Heavy" intent without keeping an amplitude ladder.
- **Rename `rigid` → `sharp`** rather than keep the raw value — "SHARP" describes
  the feel and pairs cleanly with "SOFT". Handled by a persisted-value migration
  so no tuned user or seeded scenario silently resets.
- **Keep the follow-app DEFAULT chip** (confirmed with the user) — the
  `HapticOption?` override model and `OverridePicker`'s DEFAULT chip are unchanged;
  this plan only edits the enum, its feedback mapping, the defaults, and the
  read-path migration.
- **Migrate persisted/legacy rawValues** — old strings (`light`, `medium`,
  `heavy`, `rigid`) still live in `UserDefaults` (per-direction keys and the
  legacy single key) and in persisted `Counter` overrides. Map them to the nearest
  surviving feel on read so a returning TestFlight user keeps a sensible tap
  instead of snapping back to the default.

## Implementation

### 1. Redefine the haptic option set

**File**: `Sources/AppCore/AppSettings.swift`

Replace the `HapticOption` cases with `off, soft, sharp, double, buzz` and refresh
the doc comment (drop the amplitude framing). Add a persisted-value migration
helper so removed/renamed rawValues resolve to a surviving case:

```swift
public enum HapticOption: String, CaseIterable, Codable {
    case off, soft, sharp, double, buzz

    public var label: String { rawValue.uppercased() }

    /// Resolve a persisted rawValue (a per-direction key, the legacy single key,
    /// or a `Counter` override) into a current case, mapping the removed
    /// amplitude/`rigid` values to their nearest surviving feel. Returns `nil`
    /// only for a genuinely unknown token, so callers can fall back to a default.
    public static func resolve(_ raw: String?) -> HapticOption? {
        guard let raw else { return nil }
        if let current = HapticOption(rawValue: raw) { return current }
        switch raw {
        case "rigid", "heavy", "medium": return .sharp
        case "light":                     return .soft
        default:                          return nil
        }
    }
}
```

Update the two default constants:

- `defaultIncrementHaptic` → `.sharp` (was `.rigid`)
- `defaultDecrementHaptic` → `.soft` (unchanged)

Update `AppSettings.loadHaptic(...)` to route both the new per-direction key and
the legacy `hapticOption` key through `HapticOption.resolve(...)` instead of the
bare `HapticOption(rawValue:)`, so migrated values survive. Refresh the type-level
doc comment that names the `rigid`/`soft` defaults to say `sharp`/`soft`.

### 2. Map the new feels to real haptic hardware

**File**: `Sources/AppCore/Feedback.swift`

Rewrite `SystemCounterFeedback.defaultHaptic(_:)` to branch by feel: the impacts
fire at full intensity, the patterns use `UINotificationFeedbackGenerator`:

```swift
private static func defaultHaptic(_ option: HapticOption) {
    #if canImport(UIKit)
    switch option {
    case .off:
        return
    case .soft:
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 1.0)
    case .sharp:
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
    case .double:
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .buzz:
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    #endif
}
```

The `changed(sound:haptic:)` gating (`if haptic != .off { emitHaptic(haptic) }`)
is unchanged — every non-`.off` case still fires exactly once.

### 3. Migrate persisted per-counter overrides on decode

**File**: `Sources/AppCore/Model.swift`

In `Counter.init(from:)`, the increment/decrement haptic overrides and the legacy
single `hapticOverride` are currently decoded via `HapticOption.init(rawValue:)`
(around lines 100–108). Route each through `HapticOption.resolve(...)` so a
persisted `rigid`/`heavy`/etc. override migrates to `sharp`/`soft` instead of
decoding to `nil` (which would silently drop the override and fall back to the app
default). No signature or other logic changes.

### 4. Pickers need no structural change

**Files**: `Sources/AppCore/Views/CounterSettingsPanel.swift`,
`Sources/AppCore/Views/AppSettingsPanel.swift`, `Sources/AppCore/Views/OverridePicker.swift`

All three drive their chips off `HapticOption.allCases` + `label`, so the new set
flows through automatically and the per-counter DEFAULT chip stays. No edits
expected here beyond confirming the rendered rows read
`[ DEFAULT ] [ OFF ] [ SOFT ] [ SHARP ] [ DOUBLE ] [ BUZZ ]` (per-counter) and the
same without DEFAULT (app settings). Verify the wider row still scrolls cleanly.

### 5. Update tests to the new cases

**File**: `Tests/AppCoreTests/AppSettingsTests.swift`

- `testUnknownOptionFallsBackToDefault` uses `"buzz"` as its "unrecognized"
  increment value — **`buzz` is now a real case**, so this test would change
  meaning. Swap the token to a still-unknown one (e.g. `"kazoo"`/`"wobble"`) and
  update the expected increment default from `.rigid` to `.sharp`. Update the
  decrement default assertion (`.soft`) — unchanged value, still correct.
- Default-pairing assertions (`incrementHapticOption == .rigid`) → `.sharp`.
- Legacy-migration tests that seed `"heavy"` and expect `.heavy` must now expect
  the migrated `.sharp` (e.g. `testLegacyHapticKeyMigratesToBothDirections`,
  `testNewHapticKeyWinsOverLegacy`). Legacy `"off"` still → `.off`.
- Round-trip/independence tests that set `.heavy`/`.light` should use surviving
  cases (`.sharp`/`.soft`/`.double`/`.buzz`).
- Add one test asserting `HapticOption.resolve("rigid") == .sharp`,
  `resolve("heavy") == .sharp`, `resolve("light") == .soft`, and
  `resolve("nonsense") == nil`.

**File**: `Tests/AppCoreTests/FeedbackTests.swift`

- Replace `.heavy`/`.light`/`.medium` references with new cases.
- `testSoftAndRigidAreTreatedAsNonOff` → retarget to `.soft`/`.sharp` (and rename),
  and extend to cover `.double`/`.buzz` firing the haptic emitter (they gate the
  same way — non-`.off`).

**File**: `Tests/AppCoreTests/ModelTests.swift`

- If any test seeds a persisted/legacy haptic override rawValue, update expected
  values for the migration (e.g. a stored `"rigid"` override now resolves to
  `.sharp`). Confirm the legacy `hapticOverride` decode test still passes through
  `resolve(...)`.

Run the affected tests with
`codeyam-editor editor refresh-tests --test <name>` after implementation.

## Reused existing code

- `HapticOption` enum + `label` — `Sources/AppCore/AppSettings.swift`
- `SystemCounterFeedback` / `CounterFeedback` seam and its injectable emitters —
  `Sources/AppCore/Feedback.swift`
- `AppSettings.loadHaptic` legacy-migration path and the `defaultIncrementHaptic`/
  `defaultDecrementHaptic` constants — `Sources/AppCore/AppSettings.swift`
- `Counter.init(from:)` legacy `hapticOverride` decode + `effectiveIncrementHaptic`
  / `effectiveDecrementHaptic` — `Sources/AppCore/Model.swift`
- `OverridePicker` (DEFAULT chip) and the app-settings `optionPicker` — reused
  as-is, driven by `HapticOption.allCases`

## Scenarios to Demonstrate

- App Settings panel with the new haptic rows —
  `[ OFF ] [ SOFT ] [ SHARP ] [ DOUBLE ] [ BUZZ ]` — increment `SHARP`,
  decrement `SOFT` selected (fresh-install default).
- Per-counter settings panel showing INCREMENT/DECREMENT HAPTIC with the DEFAULT
  chip retained ahead of the new options.
- A counter that overrides increment to `DOUBLE` and decrement to `BUZZ`.
- Migration: a container seeded with legacy `incrementHapticOption = "rigid"` and
  `decrementHapticOption = "heavy"` renders as `SHARP` / `SHARP`.
- All haptics `OFF` (both directions) — silent.
