---
title: "Counter management (add / grow) + graph toggle"
mode: ui
createdAt: "2026-07-09T22:20:00Z"
source: prototype
step: 11
---

# Counter management (add / grow) + graph toggle

Prototyped in a single session. Four related UI changes across the graph
overlay and the counter switcher, all driven against the live simulator
preview. The working tree already contains the built code; Deconstruct
should extract + TDD over what's here.

## 1. Graph button toggles the graph (open ↔ close)

Previously the bottom-row GRAPH control only *opened* the graph, and the
graph was dismissed by a DONE button in its header.

- `ContentView` — the bottom bar's `onGraph` changed from `showGraph = true`
  to `showGraph.toggle()`, so reclicking the control while the graph is open
  closes it.
- The control's icon + label now reflect state: **`chart.xyaxis.line` / "GRAPH"**
  when closed, **`xmark` / "CLOSE"** when open. A `graphOpen: Bool` flag is
  threaded `ContentView → CounterBottomBar → BottomControlRow` to drive this.
  The slot keeps its `"graph"` accessibility identifier in both states (same
  pattern as RESET ↔ UNDO RESET).

## 2. DONE button removed from the graph overlay

Since the bottom-row CLOSE now dismisses the graph, the graph's own DONE
button is redundant and was removed.

- `CounterGraphView` — dropped the `onClose` closure entirely (field, init
  param, and the DONE `Button` in the header). Header is now just the
  "GRAPH" label + counter name.
- Updated the two call sites: `ContentView` (removed `onClose:` arg) and
  `CounterGraphViewIsolated` (three cases, removed `onClose: {}`), plus the
  now-stale "DONE button" comment in the isolated host.

## 3. Swipe past the last counter grows the list

`CounterModel.selectNext()` previously wrapped around modulo `counters.count`.
It now, when already on the last counter, appends a fresh **blank slot** and
selects it instead of wrapping — so the user can keep swiping forward to add
more counters. `selectPrevious()` still wraps as before.

- New `CounterModel.addCounter()` — appends a blank `Counter` (empty name,
  `blankColorKey`, `count: 0`, next `id`/`order`), selects it, and persists
  counters + selection. Reuses the existing "blank slot" concept (revived by
  naming in settings or incrementing).
- **Product decision (confirmed):** no guard against consecutive empties —
  every forward swipe past the end (and every "+" tap) adds another blank.
  Stacking multiple unused blank slots is acceptable by design.

## 4. "+" add dot in the switcher

- `CounterSwitcherCard` — a trailing muted "+" circle (`addDot`) after the
  counter dots; tapping it calls a new `onAdd` closure. Wired in `ContentView`
  to `model.addCounter()`. Accessibility identifier `"dot-add"`.
- Updated `CounterSwitcherCardIsolated` (both cases) to pass `onAdd: {}`.

## 5. Active ring on an unnamed (blank) selected slot

`CounterDot` previously rendered the blank+empty slot as a bare dashed circle
with no active treatment, so a selected unnamed counter was indistinguishable.
The dashed-empty branch now layers on the same solid accent ring + glow the
solid dots use when `isActive`, so selection is visible with or without a name.

## Files touched

- `Sources/AppCore/ContentView.swift`
- `Sources/AppCore/Model.swift`
- `Sources/AppCore/Views/BottomControlRow.swift`
- `Sources/AppCore/Views/CounterBottomBar.swift`
- `Sources/AppCore/Views/CounterGraphView.swift`
- `Sources/AppCore/Views/CounterSwitcherCard.swift`
- `Sources/AppCore/Views/CounterDot.swift`
- `Sources/AppCore/CodeyamIsolated/BottomControlRowIsolated.swift` (new `GraphOpen` case)
- `Sources/AppCore/CodeyamIsolated/CounterBottomBarIsolated.swift`
- `Sources/AppCore/CodeyamIsolated/CounterGraphViewIsolated.swift`
- `Sources/AppCore/CodeyamIsolated/CounterSwitcherCardIsolated.swift`

## Scenarios

- **Registered:** `counter-added-blank-slot-selected` — full-app "after add"
  state: four named counters + a freshly-added blank slot selected (dashed dot
  with the new active ring, "—" name), followed by the "+" dot.
- **Existing scenarios exercised / that will need recapture:** `counter-graph-open`
  (now shows ✕ CLOSE in the bottom row, no DONE button), `counter-fresh-start`
  (switcher now shows the "+" dot), `counterswitchercard-blank-slots` (active
  dashed dot now ringed), `counter-deleted-default-ghost-slot`, and the
  `bottomcontrolrow-*` / `countergraphview-*` / `counterswitchercard-*` /
  `counterdot-*` component scenarios.

## Verification notes

- Verified each change visually on the iOS simulator via seeded scenario
  captures. Native stacks have no live interaction driver, so the add-on-tap /
  add-on-swipe *behavior* was verified by wiring + model logic, not a live tap —
  Deconstruct should add unit tests over `CounterModel.selectNext()` /
  `addCounter()` and the blank-slot ring rendering.
- Seeded application-scenario captures are sensitive to persisted
  `UserDefaults` bleed-through; a clean capture required uninstall + fresh
  install before seeding.

## Suggested test coverage (for Deconstruct / TDD)

- `selectNext()` on the last index appends a blank and selects it (no wrap);
  on a non-last index advances by one.
- `addCounter()` assigns a unique id + next order, is blank, becomes active,
  and persists.
- `selectPrevious()` still wraps.
- `CounterDot` renders the active ring when `isActive` for both named dots and
  the blank+empty (dashed) dot.
- `BottomControlRow` graph slot shows "GRAPH"/`chart.xyaxis.line` vs
  "CLOSE"/`xmark` by `graphOpen`.
