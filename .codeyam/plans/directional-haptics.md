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
built) was for increment and decrement to have **separate, independently
configurable** haptics, each defaulting to **Medium**. This plan splits the one
shared haptic setting into two — an **increment haptic** and a **decrement
haptic** — at every layer: the app-wide `AppSettings` defaults, the per-counter
overrides on `Counter`, the resolution the model performs when emitting change
feedback, and both settings panels. The two default to `.medium`, so a fresh
install (and any untrusted distribution container) feels a Medium tap up and a
Medium tap down out of the box.

## Key Decisions

- **Two settings, not two fixed styles** — per the user's choice, increment and
  decrement each get their own full `HapticOption` picker (off/light/medium/
  heavy). This reuses the existing enum and picker UI rather than inventing a
  second concept, and lets a user tune "up feels different from down" to taste.
- **`HapticOption` enum is unchanged; it's the *number of slots* that doubles** —
  keep `off/light/medium/heavy`. Everywhere there was one `hapticOption` /
  `hapticOverride` / `effectiveHaptic`, there are now two, keyed by direction.
- **Direction resolves in the model, not the feedback sink** — `CounterFeedback.changed(sound:haptic:)`
  stays a single already-resolved haptic; the model picks the increment- vs
  decrement-haptic *before* calling it. This keeps the production/Noop/spy
  feedback implementations and `FeedbackTests` untouched, and localizes the new
  branching to `emitChangeFeedback(direction:)`.
- **Default flips from `.off` to `.medium`** — the built-in defaults become
  Medium for both directions. Because the distribution `SeedPolicy` starts an
  untrusted container from the *built-in* defaults, this correctly yields Medium
  (not off) for a real install, while still ignoring stray injected scenario
  keys. This is the deliberate change from `production-rejects-scenario-seed-data`,
  whose `.off` init values were chosen against the *old* built-in default.
- **Migrate the legacy `hapticOption` key so an existing "off" choice is
  respected** — when the two new keys are absent but the old single
  `hapticOption` key is present (a TestFlight user who already tuned it), seed
  *both* new directions from that legacy value; otherwise use `.medium`. Avoids
  silently re-enabling haptics for someone who turned them off. New keys win once
  written.
- **Naming** — `incrementHapticOption` / `decrementHapticOption` on `AppSettings`
  (keys `"incrementHapticOption"` / `"decrementHapticOption"`);
  `incrementHapticOverride` / `decrementHapticOverride` on `Counter`;
  `effectiveIncrementHaptic(default:)` / `effectiveDecrementHaptic(default:)`.

## Implementation

### 1. Split the app-wide haptic default into two directions

**File**: `Sources/AppCore/AppSettings.swift`

- Replace the single `@Published public var hapticOption: HapticOption` (and its
  `didSet`) with two published properties: `incrementHapticOption` and
  `decrementHapticOption`, each persisting on `didSet` (to
  `incrementHapticOptionKey` / `decrementHapticOptionKey`) and stamping
  provenance exactly as the old one did.
- Add the two key constants; remove `hapticOptionKey` **but keep its string
  value referenced** in the migration read below. Suggest a
  `legacyHapticOptionKey = "hapticOption"` constant so the migration is explicit.
- In `init`, compute each direction's initial value. When `trusted`:
  1. If the new direction key is present, decode it.
  2. Else if the legacy `"hapticOption"` key is present, decode that (shared
     fallback for both directions).
  3. Else `.medium`.
  When **untrusted** (distribution, unstamped container): `.medium` for both —
  ignore all seeded keys. (This replaces the old `.off`.)
- Update the seeding-contract doc comment atop `AppSettings`: two haptic keys,
  both default **Medium**, note the legacy-key migration and that an untrusted
  container now starts at Medium.

### 2. Split the per-counter haptic override

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

### 3. Resolve direction when emitting feedback

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

### 4. Wire the direction-aware closure in the view

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

### 5. Two haptic controls in the App Settings panel

**File**: `Sources/AppCore/Views/AppSettingsPanel.swift`

- Replace the single `SettingsField("HAPTIC ON CHANGE")` with two fields —
  `SettingsField("INCREMENT HAPTIC")` bound to `settings.incrementHapticOption`
  (picker id `app-settings-increment-haptic`) and `SettingsField("DECREMENT
  HAPTIC")` bound to `settings.decrementHapticOption` (id
  `app-settings-decrement-haptic`), each reusing the existing `optionPicker`
  over `HapticOption.allCases`. Keep SOUND and HANDEDNESS as-is.

### 6. Two haptic override controls in the per-counter panel

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

### 7. Thread the extra override through the save path

**File**: `Sources/AppCore/Model.swift` (`updateActiveCounter`) and its caller
in `ContentView.swift`

- Change `updateActiveCounter(... hapticOverride:)` to
  `... incrementHapticOverride:decrementHapticOverride:` and assign both.
- In `deleteCounter`, reset **both** override fields to `nil` (a revived blank
  slot starts on the app defaults).
- Update the `ContentView` call site that passes the panel's `onSave` values
  into `updateActiveCounter` to forward both.

### 8. Update scenario seed keys

**Files**: the four scenarios seeding `hapticOption` under `.codeyam/scenarios/`:
`counter-app-settings-open.json`, `counter-all-counters-list.json`,
`counter-all-counters-list-with-blank-slot.json`,
`counter-app-settings-sound-and-haptic-on.json`

- Replace each `preferences.hapticOption` with the two new keys
  `incrementHapticOption` / `decrementHapticOption`. For the three currently
  `"off"`, either keep them `"off"` (to preserve those captures' silence) or drop
  the key to let the new Medium default apply — prefer keeping `"off"` so their
  captures are unchanged. For `counter-app-settings-sound-and-haptic-on` (now
  `"medium"`), set both to `"medium"` so the panel renders the new two-control
  layout with Medium selected.
- Note: the legacy-key migration in Step 1 means any scenario left on the old
  `hapticOption` key still decodes (into both directions), so this step is about
  showing the *new* controls correctly, not about avoiding a crash.

## Reused existing code

- `HapticOption` enum from `Sources/AppCore/AppSettings.swift` — reused verbatim
  for both directions (glossary: none registered for the enum itself; it backs
  `AppSettings`).
- `CounterFeedback` / `SystemCounterFeedback` / `NoopCounterFeedback` from
  `Sources/AppCore/Feedback.swift` (glossary entries: `CounterFeedback`,
  `SystemCounterFeedback`, `NoopCounterFeedback`) — **unchanged**; the
  `changed(sound:haptic:)` seam already takes a resolved haptic, so direction
  resolution happens upstream in the model.
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

- Round-trip both new keys through a scratch `UserDefaults(suiteName:)`.
- New default is `.medium` for both when no keys present (trusted).
- Legacy `hapticOption` present + new keys absent → both directions adopt the
  legacy value.
- Untrusted (distribution) container → both `.medium`, ignoring seeded keys.

**File**: `Tests/AppCoreTests/ModelTests.swift`

- `effectiveIncrementHaptic` / `effectiveDecrementHaptic` return the app default
  when the override is `nil` and the pinned value when set (including explicit
  `.off`).
- Feedback spy: `increment()` fires the **increment** haptic and `subtract()`
  fires the **decrement** haptic (extends the existing feedback-spy test);
  the no-op subtract clamp still fires nothing; `reset`/`undoReset` stay silent.
- Legacy single `hapticOverride` on a decoded counter maps to both directions.

**File**: `Tests/AppCoreTests/FeedbackTests.swift` — expected **no change**
(the `changed(sound:haptic:)` gating is direction-agnostic).

Run with `codeyam-editor editor refresh-tests`.

## Scenarios to Demonstrate

- **App Settings open — directional haptics at default** — panel showing
  INCREMENT HAPTIC = Medium and DECREMENT HAPTIC = Medium (the new out-of-box
  state), replacing the old single HAPTIC control.
- **Asymmetric haptics** — INCREMENT HAPTIC = Heavy, DECREMENT HAPTIC = Light,
  demonstrating the two are independent.
- **Decrement silenced, increment on** — INCREMENT HAPTIC = Medium, DECREMENT
  HAPTIC = Off (a common "only feel it when I add" preference).
- **Per-counter override — increment pinned** — a counter's settings panel with
  INCREMENT HAPTIC pinned to Heavy while DECREMENT HAPTIC stays on Default.
- **Per-counter override — both follow default** — settings panel with both
  haptic controls on Default, following the app-wide Medium/Medium.
- **App-settings sound + directional haptics on** — updates the existing
  `counter-app-settings-sound-and-haptic-on` capture to the two-control layout.
