---
title: "Taller Bottom Control Row for Easier Increment"
mode: ui
createdAt: "2026-07-18T20:22:11Z"
source: manual
---

## Summary

Make the increment button easier to tap higher up by increasing the height of
the bottom control row on the iOS counter screen. The increment button is an
L-shape: a full-width top face (`IncrementBar`) plus a downward continuation
that lives inside the lower control row. Today the lower row is a fixed 64pt
inside an assembly pinned to 20% of screen height. Growing the lower row (and
the overall assembly, so the "TAP TO INCREMENT" top bar keeps its full size)
extends the increment continuation's tappable surface higher up the screen,
giving a bigger, easier-to-reach increment target.

## Key Decisions

- **Grow the whole assembly, don't shrink the top bar.** The lower row height
  goes from 64pt to 100pt, and the top increment bar keeps its current height
  (`assemblyHeight - 64`). Net effect: the overall bottom assembly grows by
  ~36pt and the increment continuation's top edge sits higher. Chosen over the
  alternative (keep the assembly at 20% and let the top bar shrink) because the
  user wants a *larger* increment target reaching higher, not a smaller
  "TAP TO INCREMENT" bar. (User-confirmed during planning.)
- **One height constant, one derived value.** All the sizing lives in
  `CounterBottomBar.body`; the fix is a two-line change there. `IncrementBar`,
  `BottomControlRow`, and the increment continuation already stretch to fill
  whatever height they're given (`.frame(maxHeight: .infinity)`), so nothing
  downstream needs to change — the taller row just fills correctly.
- **Preserve the top-bar height explicitly.** Decouple `topBarHeight` from the
  new `lowerRowHeight` so raising the row doesn't steal space from the top bar.
  Keep the `max(..., 64)` floor so very short screens still render sanely.

## Implementation

### 1. Increase the lower control row height and preserve the top bar

**File**: `ios/Sources/AppCore/Views/CounterBottomBar.swift`

In `body`, the sizing block currently reads:

```swift
let assemblyHeight = screenHeight * 0.20
let lowerRowHeight: CGFloat = 64
let topBarHeight = max(assemblyHeight - lowerRowHeight, 64)
```

Change it so the lower row is taller while the top increment bar keeps its
previous size (derived from the original 64pt baseline, not the new row
height):

```swift
let assemblyHeight = screenHeight * 0.20
// Taller lower row → the increment button's downward continuation reaches
// higher up the screen, giving a larger, easier-to-tap increment target.
let lowerRowHeight: CGFloat = 100
// Keep the top "TAP TO INCREMENT" bar at its previous height (derived from the
// original 64pt row baseline) so growing the lower row grows the whole
// assembly instead of shrinking the top bar.
let topBarHeight = max(assemblyHeight - 64, 64)
let columnWidth = screenWidth / 4
```

The `.frame(height: lowerRowHeight)` applied to `BottomControlRow` (and
`.frame(height: topBarHeight)` on `IncrementBar`) already pick up these
values — no other edits are needed. Update the doc comment on the struct if it
pins the exact "one-fifth" figure so it still reads accurately (the assembly is
now slightly taller than 20%).

## Reused existing code

- `CounterBottomBar` from `ios/Sources/AppCore/Views/CounterBottomBar.swift`
  (glossary entry: `CounterBottomBar`) — the only file that changes; it owns all
  the height math for the bottom assembly.
- `IncrementBar` from `ios/Sources/AppCore/Views/IncrementBar.swift` — top face
  of the increment button; already fills `topBarHeight` via
  `.frame(maxHeight: .infinity)`, unchanged.
- `BottomControlRow` from `ios/Sources/AppCore/Views/BottomControlRow.swift` —
  the lower row; its `incrementContinuation` already fills the row height via
  `.frame(maxHeight: .infinity)`, so it grows automatically with the new
  `lowerRowHeight`. Unchanged.
- Existing isolated scenarios for the assembly: `counterbottombar-default`,
  `counterbottombar-increment-pressed`, `counterbottombar-left-handed-pressed`
  (registered under the `CounterBottomBar` glossary entry) — reused as the
  before/after visual proof.

Survey note: no existing height/config field already controls the lower-row
height — it is a hardcoded `64` literal local to `CounterBottomBar.body`. This
change edits that literal in place rather than introducing a new config knob.

## Scenarios to Demonstrate

- `counterbottombar-default` — the bottom assembly at rest; shows the taller
  lower row and the raised increment continuation.
- `counterbottombar-increment-pressed` — pressed state; confirms both increment
  faces (top bar + taller continuation) still dim in unison.
- `counterbottombar-left-handed-pressed` — left-handed mirror; confirms the
  taller row mirrors correctly and the continuation lands under the thumb.
- Full counter screen (application scenario) — the whole screen showing the
  increment button reaching higher up relative to the count hero above it.