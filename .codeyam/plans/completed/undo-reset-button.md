---
title: "Undo Reset Button"
mode: ui
createdAt: "2026-06-28T21:15:00Z"
source: manual
---

## Summary

The bottom-row **RESET** control should flip to **UNDO RESET** the moment it
is tapped (zeroing the active counter but remembering the prior value), so the
user can immediately recover from an accidental reset. As soon as the counter
"starts" again — i.e. the count changes via increment or subtract — the button
reverts to plain **RESET** and the recovery offer expires. Switching counters or
editing/deleting a counter also clears the pending undo.

## Key Decisions

- **Undo state lives in `CounterModel`, scoped to the active counter.** Reset is
  already a model mutation; tracking the pre-reset value next to it (rather than
  in a view's `@State`) keeps the single source of truth in the observable store
  and lets every view that observes the model re-render the label correctly.
- **"The counter starts" = any count change.** Per the user's choice, both
  `increment()` and `subtract()` clear the pending undo. Selection changes, edits,
  and deletes clear it too, since the captured pre-reset value no longer applies
  to whatever is now active. (The alternative — increment-only — was rejected.)
- **The undo value is captured even when the pre-reset count was 0.** Tapping
  reset always enters undo mode for a consistent affordance; undoing a 0→0 reset
  is a harmless no-op. This avoids a special-case branch.
- **A single button slot, two modes — dispatched by the model.** Rather than add
  a fourth control, the existing RESET `ControlButton` swaps its glyph/label and
  the `onReset` closure dispatches to `reset()` or `undoReset()` based on
  `model.canUndoReset`. The accessibility identifier stays `"reset"` so existing
  scenario interactivity/handlers keep targeting the same slot.
- **Undo state is seedable for scenarios.** Like `settingsOpen`/`selectedCounterId`,
  the model reads a `resetUndoPreviousCount` preference in `init`, so a static
  scenario capture can render the UNDO RESET state without a live tap driver. The
  state is otherwise transient (not persisted on live mutations), matching its
  ephemeral "starts again and it's gone" intent.

## Implementation

### 1. Add undo-reset state and behavior to the model

**File**: `Sources/AppCore/Model.swift`

- Add a small value type to hold the pending undo, e.g.
  `public struct ResetUndo: Equatable { public let counterId: Int; public let previousCount: Int }`.
- Add `@Published public private(set) var resetUndo: ResetUndo?` (defaults to nil).
- Add a derived `public var canUndoReset: Bool` returning
  `resetUndo?.counterId == activeCounter.id` (nil → false). This is what the view
  reads to decide RESET vs UNDO RESET.
- Update `reset()` to capture the current value before zeroing:
  set `resetUndo = ResetUndo(counterId: activeCounter.id, previousCount: counters[selectedIndex].count)`,
  then set the count to 0 and `persistCounters()`.
- Add `public func undoReset()`: guard `canUndoReset`; restore
  `counters[selectedIndex].count = resetUndo!.previousCount`; set `resetUndo = nil`;
  `persistCounters()`.
- Clear `resetUndo = nil` at the start of `increment()` and `subtract()` (the
  "counter starts again" trigger), and also in `select(index:)`
  (covers `select(id:)`, `selectNext()`, `selectPrevious()`),
  `updateActiveCounter(...)`, and `deleteCounter(id:)`.
- Add a public key constant `public static let resetUndoKey = "resetUndoPreviousCount"`.
- In `init`, after `selectedIndex` is resolved, seed the undo state when present:
  if `defaults.object(forKey: Self.resetUndoKey) != nil`, set
  `resetUndo = ResetUndo(counterId: counters[selectedIndex].id, previousCount: defaults.integer(forKey: Self.resetUndoKey))`.
  Use the same `object(forKey:)`-presence-then-`integer(forKey:)` pattern already
  used for `selectedKey`, so a string-injected seed coerces correctly.

### 2. Render RESET vs UNDO RESET in the bottom control row

**File**: `Sources/AppCore/Views/BottomControlRow.swift`

- Add a `let resetIsUndo: Bool` stored property and constructor parameter
  (keep the existing parameter order otherwise).
- In `controlsGroup`, build the reset button's glyph/label from `resetIsUndo`:
  when true, glyph `"↶"` and label `"UNDO RESET"`; when false, the current
  glyph `"↺"` and label `"RESET"`. Keep `identifier: "reset"` in both cases.

### 3. Ensure the longer label fits its quarter-width column

**File**: `Sources/AppCore/Views/ControlButton.swift`

The label `Text` should not wrap or overflow when it becomes "UNDO RESET" in a
quarter-screen column. Add `.lineLimit(1)` and a `.minimumScaleFactor(~0.8)` to
the label `Text` so the wider text scales down gracefully if needed. This is a
safe, general improvement to the shared control button.

### 4. Thread the flag through the bottom bar

**File**: `Sources/AppCore/Views/CounterBottomBar.swift`

Add a `let resetIsUndo: Bool` stored property + constructor parameter and pass it
straight through to `BottomControlRow(resetIsUndo:)`.

### 5. Wire the model state and dispatching action in the screen

**File**: `Sources/AppCore/ContentView.swift`

In the `CounterBottomBar(...)` call:
- Pass `resetIsUndo: model.canUndoReset`.
- Change `onReset` to dispatch by mode:
  `onReset: { if model.canUndoReset { model.undoReset() } else { model.reset() } }`.

### 6. Tests for the model behavior

**File**: `Tests/AppCoreTests/ModelTests.swift`

Add cases following the existing `makeModel()` / `seededModel(_:)` patterns:
- Reset captures the pre-reset value and enters undo mode (`canUndoReset == true`,
  count == 0).
- `undoReset()` restores the captured count and exits undo mode
  (`canUndoReset == false`).
- `increment()` clears the pending undo (`canUndoReset == false`).
- `subtract()` clears the pending undo.
- Switching counters (`selectNext()` / `select(id:)`) clears the pending undo.
- A model seeded with `CounterModel.resetUndoKey` enters undo mode on launch
  (drives the scenario seed path).

### 7. Scenario demonstrating the UNDO RESET affordance

**New file**: `.codeyam/scenarios/counter-undo-reset-available.json`

Mirror the shape of `.codeyam/scenarios/counter-active-count.json`: seed the
active counter (`selectedCounterId`) with `count: 0`, set
`resetUndoPreviousCount` in `deviceState.preferences` (e.g. `12`), so the static
capture renders the bottom row showing **UNDO RESET**. Keep `pageFilePath`
pointing at `Sources/AppCore/ContentView.swift`. (Use a fresh UUID for `id`.)

## Reused existing code

- `CounterModel.reset()` / `increment()` / `subtract()` / `select(index:)` from
  `Sources/AppCore/Model.swift` — extended with undo bookkeeping.
- `ControlButton` from `Sources/AppCore/Views/ControlButton.swift` — reused
  as-is for both RESET and UNDO RESET (only glyph/label differ).
- `BottomControlRow` / `CounterBottomBar` from `Sources/AppCore/Views/` — the
  existing prop-threading pattern (already passes `onReset` etc.) extended with
  one `resetIsUndo` flag.
- The `init`-time UserDefaults seed pattern (presence check + `integer(forKey:)`)
  already used for `selectedKey` in `Sources/AppCore/Model.swift`.
- Test scaffolding `makeModel()` / `seededModel(_:)` in
  `Tests/AppCoreTests/ModelTests.swift`.
- Scenario JSON contract from `.codeyam/scenarios/counter-active-count.json`.

## Scenarios to Demonstrate

- **Undo available** — active counter at 0 with a pending undo; bottom row shows
  **UNDO RESET** (`↶`) instead of RESET. (New scenario file above.)
- **Default / no undo** — a normal active count; bottom row shows **RESET** (`↺`).
  (Covered by existing `counter-active-count`.)
- **Reset → Undo round trip (interactive)** — tap RESET (count → 0, label →
  UNDO RESET), tap UNDO RESET (count restored, label → RESET).
- **Counter starts again** — after a reset, tapping `+` (increment) reverts the
  label to RESET; the undo offer is gone.
- **Subtract also reverts** — after a reset, tapping SUBTRACT reverts the label to
  RESET.
- **Switching counter clears undo** — reset counter A, swipe to counter B, swipe
  back to A: the label is RESET (undo did not survive the switch).
- **Edge: reset a zero counter** — UNDO RESET appears; undoing restores 0 (no-op).
