---
title: "Directional Haptics (Increment vs Decrement)"
mode: ui
createdAt: "2026-07-11T10:25:23Z"
source: manual
---

## Summary

Today the app fires a **single** haptic on every count change — the same
`HapticOption` (`off/light/medium/heavy`) resolves for both increment and
subtract, and it defaults to `.off`. The intent (never actually planned or
built) was for increment and decrement to have **separate** haptics that feel
**qualitatively different**, not just stronger/weaker. This plan (1) **expands
the haptic vocabulary** with iOS's `soft` (dull, cushioned) and `rigid` (crisp,
sharp) impact styles, and (2) splits the one shared haptic setting into two —
an **increment haptic** and a **decrement haptic** — at every layer: the
app-wide `AppSettings` defaults, the per-counter overrides on `Counter`, the
resolution the model performs when emitting change feedback, and both settings
panels. The two default to **different** feels — increment → **Rigid**,
decrement → **Soft** — so a fresh install feels a crisp tap when adding and a
dull tap when subtracting, out of the box. Both defaults are single-tap impacts,
so rapid counting stays responsive.

## Key Decisions

- **Distinct *character*, not just intensity** — per the user, up and down must
  not feel the same. `light/medium/heavy` differ only in *amplitude* (same kind
  of tap), so the plan adds `soft` and `rigid`, which iOS designs as
  *qualitatively* different: `soft` is a dull/cushioned thud, `rigid` a
  sharp/precise click. Increment defaults to `rigid`, decrement to `soft` — a
  clearly-different pair that is still a single, low-latency tap (unlike the
  multi-tap notification patterns, which feel sluggish when counting fast).
- **Expand `HapticOption` rather than add a second concept** — the enum grows to
  `off, light, medium, heavy, soft, rigid`. Every existing use site (the single
  picker, the override, the generator mapping) keeps working; there are just two
  more cases and, per Decision below, two direction-keyed *slots*.
- **Two settings, each the full picker** — increment and decrement each get their
  own `HapticOption` picker (now six options). Reuses the existing enum and
  picker UI; lets a user retune the pairing (or match them, or turn one off).
- **Direction resolves in the model, not the feedback sink** —
  `CounterFeedback.changed(sound:haptic:)` stays a single already-resolved
  haptic; the model picks the increment- vs decrement-haptic *before* calling it.
  Only `SystemCounterFeedback.defaultHaptic` learns the two new styles; the
  Noop/spy implementations and the gating logic are untouched.
- **Defaults flip from `.off` to Rigid/Soft** — the built-in defaults become
  `rigid` (increment) / `soft` (decrement). Because the distribution `SeedPolicy`
  starts an untrusted container from the *built-in* defaults, this correctly
  yields Rigid/Soft (not off) for a real install while still ignoring stray
  injected scenario keys. This is the deliberate reversal of
  `production-rejects-scenario-seed-data`, whose `.off` init values were chosen
  against the *old* built-in default.
- **Migrate the legacy `hapticOption` key** — when the two new keys are absent
  but the old single `hapticOption` key is present (a TestFlight user who already
  tuned it), seed *both* new directions from that legacy value; otherwise use the
  Rigid/Soft defaults. This respects an existing "off" choice (both stay off);
  note that a legacy non-off value migrates to *both* directions, so such a user
  keeps a matched pair until they retune — acceptable for an explicit prior
  choice. New keys win once written.
- **Naming** — `incrementHapticOption` / `decrementHapticOption` on `AppSettings`
  (keys `"incrementHapticOption"` / `"decrementHapticOption"`);
  `incrementHapticOverride` / `decrementHapticOverride` on `Counter`;
  `effectiveIncrementHaptic(default:)` / `effectiveDecrementHaptic(default:)`.

## Implementation

### 1. Expand the haptic vocabulary

**File**: `Sources/AppCore/AppSettings.swift` (the `HapticOption` enum)

- Add two cases: `case off, light, medium, heavy, soft, rigid`. `label`
  (`rawValue.uppercased()`) already yields `SOFT` / `RIGID` for the picker; no
  other change to the enum. Update the doc comment to note that `soft`/`rigid`
  are the qualitatively-distinct feels the default pairing uses.

**File**: `Sources/AppCore/Feedback.swift` (`SystemCounterFeedback.defaultHaptic`)

- Extend the `switch` to map the new cases to `UIImpactFeedbackGenerator.FeedbackStyle`:
  `case .soft: style = .soft` and `case .rigid: style = .rigid` (both iOS 13+;
  the app is iPhone-only/modern). `.off` still early-returns. The switch stays
  exhaustive, so adding the cases is a compile requirement, not optional.

### 2. Split the app-wide haptic default into two directions

**File**: `Sources/AppCore/AppSettings.swift`

- Replace the single `@Published public var hapticOption: HapticOption` (and its
  `didSet`) with two published properties: `incrementHapticOption` and
  `decrementHapticOption`, each persisting on `didSet` (to
  `incrementHapticOptionKey` / `decrementHapticOptionKey`) and stamping
  provenance exactly as the old one did.
- Add the two key constants; keep the legacy string referenced via a
  `legacyHapticOptionKey = "hapticOption"` constant for the migration read.
- In `init`, compute each direction's initial value. When `trusted`:
  1. If the new direction key is present, decode it.
  2. Else if the legacy `"hapticOption"` key is present, decode that (shared
     fallback for both directions).
  3. Else the built-in default: `.rigid` for increment, `.soft` for decrement.
  When **untrusted** (distribution, unstamped container): the built-in
  defaults — `.rigid` / `.soft` — ignoring all seeded keys. (Replaces the
  old `.off`.)
- Update the seeding-contract doc comment atop `AppSettings`: two haptic keys,
  defaults **Rigid (increment) / Soft (decrement)**, the legacy-key migration,
  and that an untrusted container now starts at Rigid/Soft.

### 3. Split the per-counter haptic override

**File**: `Sources/AppCore/Model.swift` (the `Counter` struct)

- Replace `public var hapticOverride: HapticOption?` with
  `incrementHapticOverride: HapticOption?` and `decrementHapticOverride:
  HapticOption?`, both defaulting to `nil` in `init` and in the memberwise
  initializer signature.
- In `init(from:)`, decode each from its `rawValue` string via
  `decodeIfPresent(...).flatMap(HapticOption.init(rawValue:))`, staying `nil`
  when absent. **Legacy migration**: if both new keys are absent but the old
  `hapticOverride` key is present, decode it into *both* directions so a
  previously-pinned counter keeps its feel. (Add a `hapticOverride` CodingKey
  read-only for this; do not re-encode it.)
- Replace `effectiveHaptic(default:)` with
  `effectiveIncrementHaptic(default d: HapticOption) -> HapticOption
  { incrementHapticOverride ?? d }` and the decrement twin.
- Update the doc comments on the override fields to describe direction.

### 4. Resolve direction when emitting feedback

**File**: `Sources/AppCore/Model.swift` (`CounterModel`)

- Change `effectiveFeedback` from `() -> (sound: SoundOption, haptic:
  HapticOption)` to take a direction, e.g. an enum
  `public enum ChangeDirection { case increment, decrement }` and
  `var effectiveFeedback: (ChangeDirection) -> (sound: SoundOption, haptic:
  HapticOption) = { _ in (.off, .off) }`.
- `emitChangeFeedback()` becomes `emitChangeFeedback(_ direction:
  ChangeDirection)`; `increment()` calls `emitChangeFeedback(.increment)` and
  `subtract()` calls `emitChangeFeedback(.decrement)` (still only on a real
  change — the no-op clamp early-returns before emitting, unchanged;
  `reset`/`undoReset` stay silent).
- `feedback.changed(sound:haptic:)` is called exactly as before with the
  resolved pair — sound is direction-independent, haptic is the direction's
  resolved value.

### 5. Wire the direction-aware closure in the view

**File**: `Sources/AppCore/ContentView.swift`

- Update the `model.effectiveFeedback = { ... }` assignment (currently lines
  ~143–147) to accept the `direction` and resolve the correct haptic:

  ```swift
  model.effectiveFeedback = { direction in
      let c = model.activeCounter
      let haptic: HapticOption = direction == .increment
          ? c.effectiveIncrementHaptic(default: settings.incrementHapticOption)
          : c.effectiveDecrementHaptic(default: settings.decrementHapticOption)
      return (c.effectiveSound(default: settings.soundOption), haptic)
  }
  ```

### 6. Two haptic controls in the App Settings panel

**File**: `Sources/AppCore/Views/AppSettingsPanel.swift`

- Replace the single `SettingsField("HAPTIC ON CHANGE")` with two fields —
  `SettingsField("INCREMENT HAPTIC")` bound to `settings.incrementHapticOption`
  (picker id `app-settings-increment-haptic`) and `SettingsField("DECREMENT
  HAPTIC")` bound to `settings.decrementHapticOption` (id
  `app-settings-decrement-haptic`), each reusing the existing `optionPicker`
  over `HapticOption.allCases`. The picker already scrolls when options overflow,
  so the two extra cases need no layout change. Keep SOUND and HANDEDNESS as-is.

### 7. Two haptic override controls in the per-counter panel

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

- Split the `@State private var hapticOverride` into
  `incrementHapticOverride` / `decrementHapticOverride`, seeded from the
  counter's two override fields in `init`.
- Replace the single HAPTIC `OverridePicker` with two — `SettingsField("INCREMENT
  HAPTIC")` and `SettingsField("DECREMENT HAPTIC")` — each an `OverridePicker`
  over `HapticOption.allCases` bound to its `$…Override` state (id prefixes
  `settings-increment-haptic` / `settings-decrement-haptic`).
- Extend the `onSave` closure type and call to carry both override values
  instead of one:
  `(String, String, Bool, Int, Bool?, SoundOption?, HapticOption?, HapticOption?)`.

### 8. Thread the extra override through the save path

**File**: `Sources/AppCore/Model.swift` (`updateActiveCounter`) and its caller
in `ContentView.swift`

- Change `updateActiveCounter(... hapticOverride:)` to
  `... incrementHapticOverride:decrementHapticOverride:` and assign both.
- In `deleteCounter`, reset **both** override fields to `nil` (a revived blank
  slot starts on the app defaults).
- Update the `ContentView` call site that passes the panel's `onSave` values
  into `updateActiveCounter` to forward both.

### 9. Update scenario seed keys

**Files**: the four scenarios seeding `hapticOption` under `.codeyam/scenarios/`:
`counter-app-settings-open.json`, `counter-all-counters-list.json`,
`counter-all-counters-list-with-blank-slot.json`,
`counter-app-settings-sound-and-haptic-on.json`

- Replace each `preferences.hapticOption` with the two new keys
  `incrementHapticOption` / `decrementHapticOption`. For the three currently
  `"off"`, keep both `"off"` so those captures stay silent/unchanged. For
  `counter-app-settings-sound-and-haptic-on` (now `"medium"`), set
  `incrementHapticOption: "rigid"` / `decrementHapticOption: "soft"` so the panel
  renders the new two-control layout with the distinct default pairing.
- Note: the legacy-key migration in Step 2/3 means any scenario left on the old
  `hapticOption` key still decodes (into both directions), so this step is about
  showing the *new* controls correctly, not about avoiding a crash.

## Reused existing code

- `HapticOption` enum from `Sources/AppCore/AppSettings.swift` — extended with
  `soft`/`rigid`, reused for both directions.
- `CounterFeedback` / `SystemCounterFeedback` / `NoopCounterFeedback` from
  `Sources/AppCore/Feedback.swift` (glossary entries: `CounterFeedback`,
  `SystemCounterFeedback`, `NoopCounterFeedback`) — the `changed(sound:haptic:)`
  seam is unchanged; only `defaultHaptic`'s style `switch` gains two cases, and
  direction resolution happens upstream in the model.
- `AppSettings` seeding/`SeedPolicy` provenance pattern from
  `Sources/AppCore/AppSettings.swift` + `Sources/AppCore/SeedPolicy.swift` —
  the two new keys persist and gate identically to `soundOption`.
- `optionPicker` (AppSettingsPanel) and `OverridePicker`
  (`Sources/AppCore/Views/OverridePicker.swift`) — reused for each new haptic
  control; no new picker component needed.
- `effectiveSound(default:)` / prior `effectiveHaptic(default:)` shape on
  `Counter` — the two new `effectiveIncrementHaptic` / `effectiveDecrementHaptic`
  follow it exactly.

## Tests to update/add

**File**: `Tests/AppCoreTests/AppSettingsTests.swift`

- Round-trip both new keys through a scratch `UserDefaults(suiteName:)`,
  including the new `soft`/`rigid` values.
- New defaults are `.rigid` (increment) and `.soft` (decrement) when no keys
  present (trusted) — and they are **not equal** (the "must feel different"
  guarantee, pinned as a test).
- Legacy `hapticOption` present + new keys absent → both directions adopt the
  legacy value.
- Untrusted (distribution) container → `.rigid` / `.soft`, ignoring seeded keys.

**File**: `Tests/AppCoreTests/ModelTests.swift`

- `effectiveIncrementHaptic` / `effectiveDecrementHaptic` return the app default
  when the override is `nil` and the pinned value when set (including explicit
  `.off`).
- Feedback spy: `increment()` fires the **increment** haptic and `subtract()`
  fires the **decrement** haptic, and with the defaults those two differ
  (`rigid` vs `soft`); the no-op subtract clamp still fires nothing;
  `reset`/`undoReset` stay silent.
- Legacy single `hapticOverride` on a decoded counter maps to both directions.

**File**: `Tests/AppCoreTests/FeedbackTests.swift`

- The gating (non-`.off` fires, `.off` does not) is unchanged; add coverage that
  `soft`/`rigid` are treated as non-`.off` so they fire (extends the existing
  gating assertions over the new cases).

Run with `codeyam-editor editor refresh-tests`.

## Scenarios to Demonstrate

- **App Settings open — distinct default haptics** — panel showing INCREMENT
  HAPTIC = Rigid and DECREMENT HAPTIC = Soft (the new out-of-box pairing),
  replacing the old single HAPTIC control.
- **Both haptics off** — INCREMENT = Off, DECREMENT = Off, for a user who wants
  silence/no haptic.
- **Decrement silenced, increment on** — INCREMENT = Rigid, DECREMENT = Off (a
  common "only feel it when I add" preference).
- **Custom distinct pairing** — INCREMENT = Heavy, DECREMENT = Light, showing the
  two are freely and independently configurable.
- **Per-counter override — increment pinned** — a counter's settings panel with
  INCREMENT HAPTIC pinned to Rigid while DECREMENT HAPTIC stays on Default.
- **Per-counter override — both follow default** — settings panel with both
  haptic controls on Default, following the app-wide Rigid/Soft pairing.
- **App-settings sound + directional haptics on** — updates the existing
  `counter-app-settings-sound-and-haptic-on` capture to the two-control layout
  with Rigid/Soft.
