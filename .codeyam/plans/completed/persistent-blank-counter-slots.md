---
title: "Persistent Blank Counter Slots"
mode: ui
createdAt: "2026-06-29T01:13:04Z"
source: manual
---

## Summary

Today, deleting a counter removes it and leaves a dashed "ghost" circle whose
sole job is to **resurrect the original counter** (name, color, and all) when
tapped — via `restoreDefault`. We're changing that. A deleted counter should
become a blank circle that stays blank: tapping it must **not** bring the old
counter back. The blank slot persists in place until the user revives it one of
two ways — adjusting its settings (giving it a name turns it into a real
counter), or simply incrementing it (which turns the dashed outline into a
solid, neutral-colored dot that still has no name or color). Separately, the
DELETE COUNTER button gets an inline two-tap confirmation so a counter can't be
wiped with a single accidental tap.

## Key Decisions

- **Blank-in-place instead of remove-plus-ghost.** Replace the
  `deletedDefaultIds` / `ghostSlots` / `restoreDefault` machinery with a single
  concept: deleting a counter blanks it *in place* (empty name, neutral color,
  count reset to 0) but keeps it in the `counters` array. This generalizes to
  any counter (not just the four defaults), makes `select`/`increment` work on
  a blank slot with no special cases, and removes the resurrection path the user
  explicitly doesn't want.
- **`isBlank` is driven by an empty name.** A counter is blank when its `name`
  is empty. Incrementing does *not* clear blankness (matches "solid blank circle
  but with no name or color"); only giving it a name (via settings) revives it.
- **Blank dot has two visual states.** Blank + count 0 → the existing dashed
  outline circle. Blank + count ≠ 0 → a solid dot in a neutral muted color
  (`CounterTheme.inkMuted`) with no name. Non-blank → today's colored dot.
- **Tapping a blank selects it; it stays blank.** Tap just makes the slot the
  active counter (so the user can then increment it or open its settings). No
  name/color is restored.
- **Header keeps counting blank slots** (per product decision): a blank slot is
  still a slot, so deleting one default keeps the total at `04`. `counterCount`
  /`positionLabel` need no change once blanks remain in `counters`.
- **Inline two-tap delete confirmation** (chosen over a system alert/sheet to
  match the app's brutalist inline aesthetic): first tap arms the button
  ("TAP AGAIN TO CONFIRM"), second tap within ~3s deletes; it auto-disarms.
- **Legacy migration** so users (and existing scenarios) who already deleted a
  default still see a blank circle: on load, any id in the persisted
  `deletedDefaultIds` that's absent from the loaded counters is folded in as a
  blank counter at that default's original order. The `deletedDefaultIds` key
  becomes read-only legacy (no longer written).

## Implementation

### 1. Model: blank state + blank-in-place delete

**File**: `Sources/AppCore/Model.swift`

- Add a computed property to `Counter`:
  `var isBlank: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }`.
  Add a `static let blankColorKey = ""` sentinel used when blanking.
- Rewrite `deleteCounter(id:)` to **blank in place** instead of removing:
  find the counter and set `name = ""`, `colorKey = Counter.blankColorKey`,
  `count = 0`, `step = 1`, `allowNegative = true`, keeping its `id` and `order`.
  Leave it in `counters` and leave it selected. Persist. Drop all
  `deletedDefaultIds` insertion and the selection-clamping that compensated for
  removal (the array length no longer changes).
- Delete `restoreDefault(id:)`, the `ghostSlots` computed property,
  `deletedDefaultIds` (published), `persistDeletedDefaultIds`, and
  `defaultIds`. Keep `defaultCounters()` (still the starter set) and
  `deletedDefaultsKey` + `loadDeletedDefaultIds` for the read-only migration.
- `positionLabel` / `counterCount` stay as-is (they already count `counters`,
  which now includes blanks — keeping the header total stable, e.g. `01 / 04`).
- **Migration** in `loadCounters`/`init`: after loading, for each id in the
  persisted `deletedDefaultIds` that is a known default and **not** present in
  the loaded counters, append a blank `Counter` (empty name, blank color,
  count 0) at that default's `order`, then re-sort by `order`. This preserves a
  blank circle for users who deleted a default before this change shipped.

### 2. CounterDot: render the blank states

**File**: `Sources/AppCore/Views/CounterDot.swift`

Replace the `isGhost` flag with two inputs that describe a blank slot:
- `isBlank: Bool` and `isEmpty: Bool` (blank with count 0).
- Rendering branches:
  - `isBlank && isEmpty` → the current dashed outline circle (unchanged look).
  - `isBlank && !isEmpty` → a **solid** circle filled with `CounterTheme.inkMuted`
    (neutral, nameless), gaining the active ring/glow when `isActive` — reuse
    the existing active-ring overlay so a selected solid-blank still reads as
    selected.
  - otherwise → today's colored fill branch, unchanged.

### 3. Switcher card: drop ghosts, render counters directly

**File**: `Sources/AppCore/Views/CounterSwitcherCard.swift`

- Remove the `ghostSlots` and `onRestore` parameters (and the `slots` merge
  helper). Iterate `counters` sorted by `order`.
- For each counter, render a `CounterDot` with:
  `isBlank: counter.isBlank`, `isEmpty: counter.isBlank && counter.count == 0`,
  `color: counter.isBlank ? CounterTheme.inkMuted : CounterTheme.dotColor(counter.colorKey)`,
  `isActive: counter.id == activeId`, `onTap: { onSelect(counter.id) }`.
- Accessibility identifiers: keep `dot-empty-<id>` for a blank+empty dot and
  `dot-<id>` for everything else, so existing scenario captures keep resolving.
- Active name label: show a muted placeholder when the active counter is blank —
  `Text(activeName.isEmpty ? "—" : activeName)` (em dash in `inkMuted` is fine;
  the existing styling already truncates/scales).

### 4. ContentView: rewire the switcher, keep increment/settings revive

**File**: `Sources/AppCore/ContentView.swift`

- Update the `switcherCard` to stop passing `ghostSlots`/`onRestore`. The
  `onSelect` handler stays (`model.select(id:)` + close settings).
- No change needed to the increment wiring — incrementing the active blank slot
  already runs through `model.increment()` and produces the solid-blank dot.
- The settings `onDelete` still calls `model.deleteCounter(id:)`; after it runs
  the now-blank counter remains selected so the user can immediately revive it.

### 5. Settings panel: inline two-tap delete confirmation + blank-aware defaults

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

- Add `@State private var confirmingDelete = false`. The delete button:
  - When not confirming: label "DELETE COUNTER" (current coffee-colored outline
    style). Tapping sets `confirmingDelete = true` and schedules a reset back to
    `false` after ~3s (`DispatchQueue.main.asyncAfter`).
  - When confirming: label "TAP AGAIN TO CONFIRM" with a stronger/filled
    treatment (e.g. filled coffee background, `onAccent`-style text) to signal
    the armed state. Tapping calls `onDelete(); onClose()`.
  - Keep the `settings-delete` accessibility identifier on the button in both
    states so the delete still automates; the armed state is a label/style swap,
    not a new control.
- Blank-aware initial state: in `init`, when `counter.isBlank`, seed the
  `colorKey` @State to the first palette color (`CounterTheme.palette.first ?? "lime"`)
  instead of the empty sentinel, and leave `name` empty. Saving with a non-empty
  name revives the counter (it stops being blank); saving with an empty name
  leaves it blank. (`CounterColorPicker` already tolerates a non-palette/empty
  selection, so no picker change is required — this is just a sensible default.)

### 6. Tests

**File**: `Tests/AppCoreTests/ModelTests.swift`

Replace the delete/restore tests that assert the old ghost behavior:
- Remove/replace `testDeleteDefaultRemovesAndRecordsGhost`,
  `testRestoreDefaultReaddsAtZeroAndSelects`,
  `testSeededSubsetHasNoGhostSlots`, and adjust
  `testDeleteLastCounterClampsSelection` (the array length no longer shrinks).
- Add coverage for the new model:
  - Deleting a counter blanks it in place: count stays 4, the deleted id is
    still present, its `name` is empty / `isBlank` is true, `count == 0`.
  - The blanked counter stays selectable and increments without resurrecting a
    name (`increment` raises its count while `isBlank` stays true).
  - Setting a name via `updateActiveCounter` revives it (`isBlank` false).
  - Migration: a model seeded with `deletedDefaultIds` and a `counters` array
    missing those ids exposes blank counters at the right orders.

### 7. Scenarios

**Files**: `.codeyam/scenarios/counter-deleted-default-ghost-slot.json` (update),
plus a new `.codeyam/scenarios/counter-blank-slot-incremented.json`.

- Update `counter-deleted-default-ghost-slot.json` to the new representation:
  seed the blank slots directly as blank counters in the `counters` array
  (empty `name`, blank `colorKey`, `count` 0) at their orders, rather than via
  `deletedDefaultIds`. (Migration keeps it working even if left as-is, but
  encoding the blanks directly makes the scenario self-describing.) Consider
  renaming the display name to "Counter - Deleted blank slot".
- Add `counter-blank-slot-incremented.json` demonstrating a **solid blank**: a
  blank-named counter with a non-zero count, selected as the active counter, so
  the capture shows the solid neutral dot, the "—" placeholder name, and a
  non-zero CountHero.
- `counter-all-but-one-deleted.json` continues to render via migration; update
  it to the direct blank representation for consistency if convenient.

### 8. Data-structure doc

**File**: `.codeyam/data-structure.json`

Update the `CounterAppState.deletedDefaultIds` field description to note it is
legacy/read-only (migrated into blank counters on load), and update the
`Counter` description to mention the blank state (empty name = a deleted slot
awaiting revival). No schema field changes required.

## Reused existing code

- `Counter` / `CounterModel` from `Sources/AppCore/Model.swift` (glossary entry:
  `CounterModel`) — extend with `isBlank` and blank-in-place delete.
- `CounterDot` from `Sources/AppCore/Views/CounterDot.swift` (glossary entry:
  `CounterDot`) — reuse the active-ring overlay for the solid-blank state.
- `CounterSwitcherCard` from `Sources/AppCore/Views/CounterSwitcherCard.swift`
  (glossary entry: `CounterSwitcherCard`).
- `CounterSettingsPanel` from `Sources/AppCore/Views/CounterSettingsPanel.swift`
  (glossary entry: `CounterSettingsPanel`) — extend its delete button.
- `CounterColorPicker` from `Sources/AppCore/Views/CounterColorPicker.swift`
  (glossary entry: `CounterColorPicker`) — already tolerates an empty selection.
- `CounterTheme.inkMuted` / `dotColor` from `Sources/AppCore/Theme.swift`
  (glossary entry: `CounterTheme`) — neutral fill for the solid-blank dot.
- `ModelTests` at `Tests/AppCoreTests/ModelTests.swift` (test registry) — the
  delete/restore tests to rewrite.

## Scenarios to Demonstrate

- **Blank slot (dashed):** a default deleted, leaving a dashed empty circle in
  the row; header still shows the full total (e.g. `04`).
- **Solid blank (incremented):** a blank slot that's been incremented — solid
  neutral dot, no name (shows "—"), non-zero count in the hero.
- **Revived via settings:** opening settings on a blank slot, typing a name and
  picking a color, and saving turns it back into a normal colored, named dot.
- **Tap does not resurrect:** tapping a blank dashed circle selects it but it
  stays blank (regression guard against the old `restoreDefault`).
- **Delete confirmation:** settings panel with the delete button armed
  ("TAP AGAIN TO CONFIRM").
- **Multiple blanks:** several defaults deleted, a mix of dashed and solid-blank
  slots alongside live counters.
