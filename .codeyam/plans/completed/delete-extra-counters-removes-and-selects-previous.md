---
title: "Delete Extra Counters Removes And Selects Previous"
mode: ui
createdAt: "2026-07-13T18:34:43Z"
source: manual
---

## Summary

Deleting a counter that lives in position 5 or later should truly remove it
from the list and leave the user on the *previous* counter — not blank it in
place. Today `CounterModel.deleteCounter(id:)` always blanks a counter in place
(empties its name, resets it, keeps the slot and selection), which is the right
behavior for the four permanent base slots but wrong for extra, user-added
counters: those should disappear entirely and hand focus back to the counter
before them. This plan splits `deleteCounter` into two behaviors keyed on the
counter's position: positions 1–4 keep blank-in-place; position 5+ is removed
and the previous counter becomes active.

## Key Decisions

- **"First four" means the first four positions (indices 0–3), not the four
  default ids.** Chosen by the user over an id-based rule. The base row always
  keeps at least four slots; anything the user swiped-to-add past the fourth is
  fully removable. Positional is simpler and matches what the user sees in the
  switcher.
- **On removal, select the previous counter (`idx - 1`).** The user explicitly
  asked to "be placed on the previous counter." Because removal only happens
  when `idx >= 4`, `idx - 1` is always `>= 3` and always a valid index — no
  clamping or empty-list edge case is reachable.
- **Removal drops the counter's history and clears any pending reset-undo**, matching
  what blank-in-place already does (`histories[id] = nil`, `resetUndo = nil`),
  so no orphaned run history lingers under a now-absent id.
- **No UI/delete-button gating.** The DELETE COUNTER control in the settings
  panel stays visible and identical for every counter; only the model's reaction
  differs by position. This keeps the change contained to `Model.swift` and
  avoids touching the two-tap confirm affordance.
- **Reorder the `order` fields after removal is unnecessary** — `order` is only
  used to sort on load and to compute the next id/order on add
  (`max(order) + 1`). Leaving a gap in `order` after a removal is harmless, so
  the plan does not renumber.

## Implementation

### 1. Branch `deleteCounter` on position

**File**: `Sources/AppCore/Model.swift`

In `deleteCounter(id:)` (currently ~line 497), after resolving `idx`, add an
early branch: when `idx >= 4`, remove the counter and select the previous one
instead of blanking. Keep the existing blank-in-place body for `idx < 4`.

Sketch:

```swift
public func deleteCounter(id: Int) {
    guard let idx = counters.firstIndex(where: { $0.id == id }) else { return }
    resetUndo = nil

    // Counters past the four permanent base slots are removed outright, not
    // blanked in place, and focus falls back to the previous counter. idx >= 4
    // guarantees idx - 1 is a valid index, so no clamp is needed.
    if idx >= 4 {
        histories[counters[idx].id] = nil
        counters.remove(at: idx)
        selectedIndex = idx - 1
        persistCounters()
        persistSelection()
        persistHistories()
        return
    }

    // ... existing blank-in-place body unchanged (positions 1–4) ...
}
```

Update the doc comment above `deleteCounter` (and the related note on
`positionLabel` at ~line 307 that says "deleting a counter blanks it in place
without shrinking the row") to reflect that this now only holds for the first
four positions; positions 5+ shrink the row.

### 2. (Verify only) header total and switcher react to a shorter list

**File**: `Sources/AppCore/Model.swift` (no code change expected)

`counterCount` and `positionLabel` are already derived from `counters.count`
and `selectedIndex`, and the switcher/header read those. Removing an element and
lowering `selectedIndex` should flow through automatically — confirm the
"NN / NN COUNTERS" header and the switcher dots update via a scenario, no code
change anticipated.

## Reused existing code

- `CounterModel.deleteCounter(id:)` from `Sources/AppCore/Model.swift` — the
  method being split (glossary entry: `CounterModel`).
- `histories` / `persistHistories()` / `persistCounters()` / `persistSelection()`
  from `Sources/AppCore/Model.swift` — existing persistence helpers reused
  verbatim on the removal path.
- `addCounter()` from `Sources/AppCore/Model.swift` — the "swipe past the last
  counter" path that creates the position-5+ counters this behavior targets;
  used to set up the reproduction test.
- `positionLabel` / `counterCount` from `Sources/AppCore/Model.swift` — already
  drive the header total off `counters.count`, so they need no change.

## Reproduction Test

Pins that deleting a counter in position 5+ removes it from the list and selects
the previous counter, instead of blanking it in place.

**Target**: `Tests/AppCoreTests/ModelTests.swift` — run with
`codeyam-editor editor refresh-tests --test testDeleteBeyondFirstFourRemovesAndSelectsPrevious`.

```swift
// Deleting a counter past the first four positions removes it outright and
// moves selection to the previous counter, rather than blanking it in place.
func testDeleteBeyondFirstFourRemovesAndSelectsPrevious() {
    let model = makeModel()   // COUNTER 1...4 (the four base slots)
    model.addCounter()        // a 5th counter at index 4, now selected
    XCTAssertEqual(model.counterCount, 5)
    XCTAssertEqual(model.selectedIndex, 4)
    let fifthId = model.activeCounter.id

    model.deleteCounter(id: fifthId)

    // The 5th counter is gone, not blanked in place.
    XCTAssertEqual(model.counterCount, 4)
    XCTAssertNil(model.counters.first { $0.id == fifthId })
    // Focus falls back to the previous counter.
    XCTAssertEqual(model.selectedIndex, 3)
}
```

Status: PROPOSED — confirm red at execution. Expected failure: current
`deleteCounter` blanks in place, so `counterCount` stays `5` and the
`XCTAssertEqual(model.counterCount, 4)` assertion fails (the counter is still
present as a blank slot, so the `XCTAssertNil` would also fail).

## Scenarios to Demonstrate

- **Delete a 5th counter** — a list of five named counters with the 5th active;
  after delete, four counters remain and COUNTER 4 (position 4) is active with
  the header reading "04 / 04 COUNTERS".
- **Delete a middle extra counter** — six counters, position 5 active; after
  delete, the former 6th slides into position 5 and selection lands on
  position 4.
- **First-four unchanged (regression guard)** — four base counters, COUNTER 2
  active with a non-zero count; delete blanks it in place, row stays at four
  slots, blank slot stays selected.
- **Delete the last (6th) counter** — six counters, the last active; delete
  removes it and selects the new last (position 5).
