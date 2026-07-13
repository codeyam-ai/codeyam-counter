---
title: "Graph as its own page with a centered close button"
mode: ui
createdAt: "2026-07-13T00:00:00Z"
source: manual
---

## Summary

When the activity graph is open it currently floats as an overlay while the
whole `CounterBottomBar` (increment bar + SUBTRACT / RESET / GRAPH→CLOSE row)
stays visible and interactive beneath it. Make the graph read as its own page:
hide the bottom control assembly entirely while the graph is open, and give the
graph a dedicated CLOSE affordance — a centered button rendered directly below
the chart panel — instead of relying on the bottom row's CLOSE state.

## Key Decisions

- **Hide the whole bottom assembly, don't just dim it** — In `ContentView`'s
  base `VStack`, swap `CounterBottomBar` for a `Spacer()` when `showGraph` is
  true. The graph overlay already draws on top from just below the header, so
  collapsing the bottom bar to empty space is all that's needed for the region
  below the graph to read as blank page. This keeps the increment/subtract/reset
  controls from being reachable (or visible) while the graph is up.
- **New centered CLOSE button below the graph, inside the overlay content** —
  Add the button to the graph overlay's `content` closure in `ContentView` so it
  sits directly beneath `CounterGraphView`, horizontally centered. It calls
  `withAnimation { showGraph = false }` — the same dismissal the bottom row's
  CLOSE used to trigger via `onGraph`.
- **Extract the button as its own `GraphCloseButton` view** — Matches the
  project's one-component-per-file convention (every graph section is its own
  file with an isolated scaffold) and lets it get a codeyam isolated scenario.
  Styled with the app's monospaced type and panel/stroke treatment so it reads
  as part of the graph surface.
- **Keep `graphOpen` plumbing on the bottom bar intact** — `CounterBottomBar` /
  `BottomControlRow` keep their `graphOpen` param and the GRAPH→CLOSE toggle.
  In the real app the bottom bar is now hidden whenever the graph is open, so
  that CLOSE state is dormant in production, but the param still drives the
  existing `BottomControlRow`/`CounterBottomBar` isolated scaffolds and their
  scenarios. Removing it would churn those scaffolds and scenarios for no user
  benefit. `onGraph` still opens the graph from the visible GRAPH slot.

## Implementation

### 1. Hide the bottom bar while the graph is open

**File**: `Sources/AppCore/ContentView.swift`

In the base-layer `VStack` (currently header → switcher → `CountHero` →
`CounterBottomBar`), render the `CounterBottomBar` only when `!showGraph`,
substituting a `Spacer()` when `showGraph` is true so the layout still fills the
screen:

```swift
CountHero(count: model.activeCounter.count)
if showGraph {
    Spacer()
} else {
    CounterBottomBar( … existing arguments unchanged … )
}
```

The `CounterBottomBar` arguments (including `graphOpen: showGraph`) stay exactly
as they are — the bar simply isn't built while the graph is up.

### 2. Add the centered CLOSE button to the graph overlay

**File**: `Sources/AppCore/ContentView.swift`

In the `if showGraph { HeaderAnchoredOverlay { … } content: { … } }` block, wrap
the existing `CounterGraphView(…)` in a `VStack` and place the new
`GraphCloseButton` below it, centered:

```swift
content: {
    VStack(spacing: 16) {
        CounterGraphView(
            counterName: model.activeCounter.isBlank ? "—" : model.activeCounter.name,
            colorKey: model.activeCounter.colorKey,
            histories: model.activeHistories
        )
        .id(model.activeCounter.id)

        GraphCloseButton(action: { withAnimation { showGraph = false } })
    }
}
```

`CounterGraphView` keeps its own internal horizontal padding; `GraphCloseButton`
should center itself within the overlay width (see below).

### 3. New `GraphCloseButton` component

**New file**: `Sources/AppCore/Views/GraphCloseButton.swift`

A small, self-contained button that dismisses the graph. Centered, app-themed:

- An `xmark` SF Symbol + `CLOSE` monospaced label (mirrors the glyph/label pair
  the bottom row's CLOSE used, so the affordance stays familiar), or a simple
  `CLOSE` text pill — keep it minimal and consistent with `ControlButton`'s
  monospaced treatment.
- Styled with `CounterTheme` (`panel` background, `lineStrong`/`line` stroke,
  `ink` foreground) so it reads as part of the graph surface.
- `buttonStyle(.plain)`, `frame(maxWidth: .infinity)` with the button content
  centered (e.g. wrap the label in an `HStack { Spacer(); … ; Spacer() }` or fix
  the pill width and center it) and matching horizontal padding to
  `CounterGraphView` (22) so it aligns under the chart panel.
- `accessibilityIdentifier("graph-close")` so scenarios/tests can target it.
- `init(action: @escaping () -> Void)`.

### 4. Isolated scaffold for the new component

**New file**: `Sources/AppCore/CodeyamIsolated/GraphCloseButtonIsolated.swift`

Follow the sibling pattern (e.g. `CounterGraphViewIsolated.swift`,
`ControlButtonIsolated.swift`): a DEBUG-gated isolation host entry that renders
`GraphCloseButton` with a no-op action so it can be captured as an isolated
scenario. Match whatever registration mechanism `CodeyamIsolationHost.swift`
uses for the other isolated views.

## Reused existing code

- `CounterGraphView` from `Sources/AppCore/Views/CounterGraphView.swift`
  (glossary entry: `CounterGraphView`) — unchanged; now wrapped with the close
  button in the overlay.
- `HeaderAnchoredOverlay` from
  `Sources/AppCore/Views/HeaderAnchoredOverlay.swift` — the graph overlay
  scaffold whose `content` closure now also holds the close button.
- `CounterBottomBar` from `Sources/AppCore/Views/CounterBottomBar.swift`
  (glossary entry: `CounterBottomBar`) — now conditionally rendered; its
  `graphOpen` param retained for isolated scaffolds.
- `ControlButton` from `Sources/AppCore/Views/ControlButton.swift` (glossary
  entry: `ControlButton`) — reference for the new button's monospaced
  glyph+label styling and `.plain` button style.
- `CounterTheme` (`Sources/AppCore/Theme.swift`) — `panel`, `line`,
  `lineStrong`, `ink` for the button's surface and stroke.
- `CodeyamIsolationHost.swift` and the `CodeyamIsolated/` scaffolds — pattern
  the new `GraphCloseButtonIsolated.swift` follows.

## Reproduction Test

Not a bug fix — this is a UI enhancement, so no reproduction test. The behavior
change is visual/structural (which chrome is shown when the graph is open) and
is demonstrated by the scenarios below rather than a unit assertion.

## Scenarios to Demonstrate

- **Graph open, rich history** — update the existing `counter-graph-open`
  application scenario (`graphOpen: true`) to confirm the bottom bar is gone and
  the centered CLOSE button sits below the chart.
- **Graph open, empty history** — a counter with no activity: NO ACTIVITY YET
  panel plus the centered CLOSE button, still no bottom bar.
- **Graph closed (default counter screen)** — unchanged: bottom bar with the
  GRAPH slot visible, no close button — confirms the bottom controls return when
  the graph is dismissed.
- **`GraphCloseButton` isolated** — the new component on its own via the
  isolated scaffold.
- **Left-handed, graph open** — confirms hiding the bottom bar and centering the
  close button is handedness-agnostic (the mirrored bottom row simply isn't
  shown).
