---
title: "Counter Settings Panel"
mode: ui
createdAt: "2026-06-28T15:21:29Z"
source: manual
---

## Summary

Make the settings gear functional. Tapping it expands an inline settings panel
that overlays the giant count numeral (the `CountHero` region) and lets the user
configure the **active** counter: rename it, pick its color from a fixed swatch
palette, toggle whether it can go negative, and choose how much each tap counts
by (the step). The panel also has a **Delete** action. Deleting one of the four
default counters leaves an **empty circle** in the switcher dot row where it was;
tapping that empty circle **restores** the default (fresh at 0). The increment
and subtract actions start respecting the per-counter step.

## Key Decisions

- **Settings overlays the number, not a separate screen** — the user asked for
  the settings area to "expand over the number." Implement as a conditional
  panel that replaces/overlays `CountHero` while open, anchored under the
  switcher card, with the gear toggling it. Keeps the single-screen feel and
  avoids navigation plumbing.
- **Color via fixed palette (chosen)** — reuse `CounterTheme.dotHex`'s named
  swatches (`lime`, `coffee`, `steps`, `bugs`) plus a small number of additional
  keys. The counter keeps storing a `colorKey` string; no migration to raw hex.
  Add any new keys to `dotHex` so theming stays centralized and unit-testable.
- **Empty dot taps to restore (chosen)** — instead of an explicit "add counter"
  affordance, a deleted default's empty circle restores that default when tapped.
  Non-default counters (none exist today) would just disappear on delete.
- **Track deleted defaults explicitly** — persist a `deletedDefaultIds` set under
  a new UserDefaults key rather than inferring "deleted" from a default id simply
  being absent from `counters`. This preserves seeding semantics: a scenario that
  seeds only 2 counters should show 2 dots, NOT 2 colored + 2 ghost dots. Ghost
  dots appear only for ids the user explicitly deleted.
- **Step applies to both directions** — "count by N" affects increment and
  subtract symmetrically. Reset still zeroes regardless of step.

## Implementation

### 1. Extend the Counter model with `step`

**File**: `Sources/AppCore/Model.swift`

- Add `public var step: Int` to `Counter` (default `1`) and include it in the
  `init`. Because `Counter` is `Codable`, give the decoder a safe default for
  older persisted JSON that lacks the field (custom `init(from:)` or rely on a
  default — verify decode of existing seeds still works; the seeded-state test
  uses `JSONEncoder`, so add `step` there or keep the default).
- Update `defaultCounters()` so each starter counter has `step: 1`.

### 2. Make increment/subtract honor the step

**File**: `Sources/AppCore/Model.swift`

- `increment()` adds `activeCounter.step` instead of `1`.
- `subtract()` subtracts `activeCounter.step`; keep the `allowNegative` clamp,
  but when clamping is on and the step would overshoot below zero, clamp the
  result to `0` rather than skipping the change entirely (decide and document:
  clamp-to-zero is the friendlier behavior).

### 3. Add edit + delete + restore mutations

**File**: `Sources/AppCore/Model.swift`

- Add a new persisted key `deletedDefaultIds` (JSON-encoded `[Int]`) and a
  `@Published private(set) var deletedDefaultIds: Set<Int>` loaded in `init`.
- `updateActiveCounter(name:colorKey:allowNegative:step:)` — applies edits to the
  selected counter and persists. (Granular setters are fine too; one batched
  method keeps the panel's "Save" simple.)
- `deleteCounter(id:)` — removes the counter from `counters`, fixes
  `selectedIndex` (clamp into range; if the active one was deleted, select a
  neighbor), persists. If the id is one of the default ids (1–4), insert it into
  `deletedDefaultIds` and persist that too.
- `restoreDefault(id:)` — re-creates the default counter from the
  `defaultCounters()` template (fresh `count: 0`, original color/order/name),
  removes the id from `deletedDefaultIds`, persists, and selects it.
- Add a derived `ghostSlots` (or similar): the `defaultCounters()` templates whose
  id is in `deletedDefaultIds`, sorted by `order`, used by the dot row to render
  empty circles in the right position.
- `positionLabel` / counts should reflect live counters only (ghosts are not
  "real" counters for the `NN / NN` header — confirm desired wording; simplest is
  to count only live counters).

### 4. Make the gear a real button

**File**: `Sources/AppCore/Views/GearButton.swift`

Add an `action: () -> Void` (or wrap in a `Button`) so tapping toggles the
settings panel. Keep the existing styling and `accessibilityIdentifier("gear")`.

### 5. New settings panel view

**New file**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

A view bound to the active counter that renders:
- a **name** text field,
- a **color** row of selectable swatches (reusing `CounterTheme.dotColor`),
- an **allow-negative** toggle,
- a **count-by / step** control (stepper or numeric field, min 1),
- a **Delete** button (destructive styling),
- a **Done/Close** affordance.

Style with `CounterTheme` tokens (`surface`, `panel`, `ink`, `lineStrong`,
`accent`). Give controls accessibility identifiers
(`settings-name`, `settings-color-<key>`, `settings-allow-negative`,
`settings-step`, `settings-delete`, `settings-restore`/`settings-close`) so
scenarios and UI tests can drive them.

### 6. Wire the panel into the screen and overlay the number

**File**: `Sources/AppCore/ContentView.swift`

- Add `@State private var showSettings = false`.
- Pass an `onGearTap: { withAnimation { showSettings.toggle() } }` down through
  `CounterSwitcherCard` to `GearButton`.
- When `showSettings` is true, show `CounterSettingsPanel` in place of / overlaying
  `CountHero` (same vertical region) so it visually "expands over the number."
  Wire its callbacks to the new model mutations; close on save/delete.

### 7. Empty-circle ghost dots in the switcher

**Files**: `Sources/AppCore/Views/CounterSwitcherCard.swift`,
`Sources/AppCore/Views/CounterDot.swift`

- `CounterSwitcherCard` should render the merged, order-sorted sequence of live
  counters (colored, selectable) and ghost slots (empty circles). Pass the
  ghost slots and an `onRestore` callback in from `ContentView`/model.
- Extend `CounterDot` with an empty/ghost variant: outline-only circle, no fill,
  no active ring; tapping calls the restore callback. Give ghosts an
  identifier like `dot-empty-<id>`.

### 8. Tests

**File**: `Tests/AppCoreTests/ModelTests.swift`

Add cases:
- increment/subtract respect a non-1 `step` (e.g. step 5),
- subtract with `allowNegative == false` and a step clamps to 0,
- `updateActiveCounter` changes name/color/allowNegative/step and persists,
- `deleteCounter` removes a counter, adjusts selection, and records the default
  id in `deletedDefaultIds`,
- `restoreDefault` re-adds a deleted default at 0 and clears it from
  `deletedDefaultIds`,
- decoding legacy persisted counters without `step` still works (defaults to 1).

## Reused existing code

- `Counter` / `CounterModel` from `Sources/AppCore/Model.swift` (glossary entry:
  `CounterModel`, tested by `Tests/AppCoreTests/ModelTests.swift`)
- `CounterTheme.dotColor` / `dotHex` / tokens from `Sources/AppCore/Theme.swift`
  (glossary entry: `CounterTheme`, tested by `Tests/AppCoreTests/ThemeTests.swift`)
- `CounterDot` from `Sources/AppCore/Views/CounterDot.swift` (glossary entry:
  `CounterDot`)
- `CounterSwitcherCard` from `Sources/AppCore/Views/CounterSwitcherCard.swift`
  (glossary entry: `CounterSwitcherCard`)
- `GearButton` from `Sources/AppCore/Views/GearButton.swift` (glossary entry:
  `GearButton`)
- `CountHero` from `Sources/AppCore/Views/CountHero.swift` (glossary entry:
  `CountHero`)
- UserDefaults seeding contract documented in `CounterModel` (the `counters` /
  `selectedCounterId` keys) — extend it with the new `deletedDefaultIds` key.

## Scenarios to Demonstrate

- **Settings open over the number** — gear tapped on a counter with a healthy
  count; the panel covers the big numeral, fields pre-filled with that counter's
  name/color/step/allow-negative.
- **Rename + recolor** — change a counter's name and pick a different swatch;
  switcher dot and label update.
- **Count by 5** — step set to 5; tapping increment jumps 0 → 5 → 10.
- **Disallow negative, then subtract at zero** — toggle off negatives, subtract
  clamps at 0; compare against an allow-negative counter going negative.
- **Delete a default → empty circle** — delete one of the four; its dot becomes
  an empty outline circle, header count reflects the remaining live counters.
- **Restore via empty circle** — tap the empty circle; the default comes back at 0
  and becomes selected.
- **All-but-one deleted** — three empty circles, one live counter, to show the
  ghost row at its busiest.
