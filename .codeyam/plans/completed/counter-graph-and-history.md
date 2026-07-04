---
title: "Counter Graph & Event History"
mode: ui
createdAt: "2026-07-02T12:29:30Z"
source: manual
dependsOn: ["per-counter-overrides"]
---

## Summary

Give each counter a recorded **event history** and a way to see it. Every
increment and subtract is logged as an event (a timestamp and a signed delta)
within the counter's **current history** — a run that begins fresh and ends when
the counter is **reset**. Reset closes the current history and opens a new empty
one; we keep the **10 most recent histories** per counter (oldest dropped). Then
replace the bottom-row **SWITCH** button with a **GRAPH** button that opens a
graph view: a chart of the counter's activity over a *relative* time scale (time
since that history's start) plus a scrollable list of each increment/decrement
with its delta and relative time. You can page between the up-to-10 stored
histories.

## Key Decisions

- **History = a run between resets** (per the chosen model) — a `CounterHistory`
  has a `startedAt` and an ordered `[CounterEvent]`. `reset()` seals the current
  history and pushes a new empty one; the per-counter list is capped at 10
  (drop-oldest ring). This makes "relative to the start" unambiguous: time is
  measured from the active history's `startedAt`.
- **Separate persisted store, keyed by counter id** — histories can grow, so keep
  them out of the `counters` JSON blob. Persist a `[counterId: [CounterHistory]]`
  map under a new `"counterHistories"` UserDefaults key, following the same
  JSON-string seeding contract as `counters` so scenarios can inject a rich
  history for a static capture (there is no live driver to accumulate events).
- **Custom SwiftUI chart, not Swift Charts** — the package targets **iOS 15**
  (`Package.swift`), and Swift Charts requires iOS 16. Draw the chart with SwiftUI
  `Path`/shapes (a step line of the running count over relative time, with a marker
  per event sized/colored by delta sign). Deterministic to render in the isolated
  preview and unit-testable via the geometry helper.
- **Undo-reset reopens the sealed history** — `undoReset()` restores the pre-reset
  count, so it must also pop the just-opened empty history and reopen the sealed
  one (re-appending nothing, since undo restores rather than re-events) to keep the
  count and the active history consistent. Only valid immediately after a reset,
  matching the existing `canUndoReset` window.
- **GRAPH replaces SWITCH** — with handedness now living in settings
  ([[app-settings-and-feedback]], [[per-counter-overrides]]), the SWITCH button is
  redundant. Remove it and its `onSwitch` plumbing; add a GRAPH control in the same
  slot (identifier `graph`, a chart glyph). Handedness mirroring of the bottom row
  is unaffected — the row still mirrors, GRAPH just takes SWITCH's place.

## Implementation

### 1. Event + history model types

**File**: `Sources/AppCore/Model.swift` (or a new
`Sources/AppCore/History.swift`)

- `public struct CounterEvent: Codable, Equatable { let at: Date; let delta: Int }`.
- `public struct CounterHistory: Codable, Equatable { let startedAt: Date; var events: [CounterEvent] }`
  with a helper for **cumulative series** (running count over time) and
  **relative offsets** (`event.at.timeIntervalSince(startedAt)`), used by both the
  chart and the list. Keep the time math in a pure function so it's unit-testable
  without views.

### 2. Record events in the model

**File**: `Sources/AppCore/Model.swift`

- Add `@Published private(set) var histories: [Int: [CounterHistory]]` loaded in
  `init` (new `counterHistories` key; empty when absent — seed a first empty
  history lazily on first event or at counter creation).
- `increment()` / `subtract()` append a `CounterEvent(at: now, delta: +step / −applied)`
  to the active counter's current (last) history. Use an injectable clock
  (`var now: () -> Date = Date.init`) so tests are deterministic. The no-op
  subtract clamp records **no** event (consistent with firing no feedback).
- `reset()` seals the current history (leaves it in the list) and appends a new
  empty `CounterHistory(startedAt: now)`; enforce the **10-history cap** per
  counter (drop the oldest). Zeroing the count is unchanged.
- `undoReset()` reverses that: drop the empty history opened by the matching reset
  and keep the sealed one active again, in addition to restoring the count.
- `deleteCounter` clears that counter id's histories (a blank slot starts clean).
- Persist histories alongside counters (new `persistHistories()`), and document the
  new key in the seeding-contract comment atop `CounterModel`.

### 3. Replace SWITCH with GRAPH in the bottom row

**Files**: `Sources/AppCore/Views/BottomControlRow.swift`,
`Sources/AppCore/Views/CounterBottomBar.swift`,
`Sources/AppCore/ContentView.swift`

- Rename the `onSwitch`/switch slot to `onGraph`/graph: a `ControlButton` with a
  chart glyph (e.g. `"▚"` or an SF Symbol via `Image(systemName: "chart.xyaxis.line")`
  if glyph rendering is preferred), label `GRAPH`, identifier `graph`.
- Remove the `onSwitch` parameter threaded through `CounterBottomBar` →
  `BottomControlRow`, and drop the repointed handedness-toggle wiring from Plan 1
  (handedness now lives only in settings). The mirrored-row logic stays.
- `ContentView` passes `onGraph: { withAnimation { showGraph = true } }`.

### 4. Graph view

**New file**: `Sources/AppCore/Views/CounterGraphView.swift`

An overlay (same floating pattern as the settings panels) for the active counter:

- **Header**: counter name + a `DONE`/close (`graph-close`).
- **History selector**: prev/next or a segmented control paging the up-to-10 stored
  histories, labeled by relative recency ("CURRENT", "−1", …) or start offset
  (`graph-history-<n>`); defaults to the current history.
- **Chart**: a custom SwiftUI-drawn plot — x = relative time since the selected
  history's `startedAt`, y = running count; a step/line path plus a marker per event
  (up-tick vs down-tick colored by delta sign using `CounterTheme.accent` /
  `dotColor("coffee")`). Empty history → a muted "NO ACTIVITY YET" placeholder.
- **Event list**: a scrollable list, most-recent-first (or chronological), each row
  `+N` / `−N` and the relative time formatted `mm:ss` (or `h:mm:ss`) since start
  (`graph-event-row-<i>`). Reuse `SettingsField`/`CounterTheme` idioms.

**New file (optional)**: `Sources/AppCore/Views/CounterGraphChart.swift` — the
pure chart shape, split out so its geometry (point mapping) is small and reusable.

### 5. Wire the graph into the screen

**File**: `Sources/AppCore/ContentView.swift`

- Add `@State private var showGraph = false` (seedable via a `graphOpen` preference
  for static captures). Overlay `CounterGraphView` for `model.activeCounter` and its
  `model.histories[activeCounter.id]` when open.

### 6. Tests

**File**: `Tests/AppCoreTests/ModelTests.swift`

- Increment/subtract append events with the correct signed delta to the current
  history; the no-op subtract clamp appends nothing.
- `reset()` seals the current history and opens a new empty one; the count zeroes.
- The per-counter history list caps at 10, dropping the oldest on the 11th reset.
- `undoReset()` reopens the sealed history and restores the count.
- Relative-offset / cumulative-series helpers produce the expected series for a
  known event sequence (using the injected clock).
- `deleteCounter` clears that counter's histories.

## Reused existing code

- `Counter` / `CounterModel` from `Sources/AppCore/Model.swift` (glossary entry:
  `CounterModel`, tested by `Tests/AppCoreTests/ModelTests.swift`) — event recording
  hangs off the existing `increment`/`subtract`/`reset`/`undoReset` mutations and
  the `ResetUndo` window.
- `ControlButton` from `Sources/AppCore/Views/ControlButton.swift` (glossary entry:
  `ControlButton`) — the GRAPH button reuses it, exactly as SWITCH did.
- `BottomControlRow` / `CounterBottomBar` from `Sources/AppCore/Views/` (glossary
  entries: `BottomControlRow`, `CounterBottomBar`) — the mirrored-row layout and
  the quarter-column sizing are unchanged; only the SWITCH slot swaps to GRAPH.
- `SettingsField` from `Sources/AppCore/Views/SettingsField.swift` and `CounterTheme`
  from `Sources/AppCore/Theme.swift` (glossary entries: `SettingsField`,
  `CounterTheme`) — captions, colors, and the `dotColor` used for up/down markers.
- The overlay pattern from `CounterSettingsPanel` / `AppSettingsPanel` — the graph
  reuses the same floating, `DONE`-to-close presentation.

## Scenarios to Demonstrate

- **Graph button present** — the bottom row shows GRAPH where SWITCH used to be
  (both right- and left-handed layouts).
- **Rich history chart** — a counter with a seeded run of ~8–12 mixed
  increments/decrements; the chart shows the running-count line with up/down markers
  over relative time.
- **Event list** — the same history's scrollable list of `+N`/`−N` rows with
  relative `mm:ss` timestamps.
- **Empty history** — a freshly reset counter: chart placeholder + empty list.
- **Paging past histories** — a counter with several sealed histories (e.g. 3 of the
  10), the selector on a previous history.
- **Ten-history cap** — a counter seeded with 10 histories, showing the oldest has
  been dropped after further resets.
