---
title: "Increment Button Press Dim Sync"
mode: ui
createdAt: "2026-07-13T11:55:29Z"
source: manual
---

## Summary

The increment button is drawn as an L-shape from two non-contiguous hit areas —
the full-width top face (`IncrementBar`) and the downward extension
(`incrementContinuation` in `BottomControlRow`) — because the control row sits
between them and they cannot be a single `Button`. Both faces share one
`incrementPressed` state and dim from it via `IncrementFaceButtonStyle`, so the
whole thing is *supposed* to read as one surface. In practice, when you press
the button the two faces do not dim in unison: the face you actually touch fades
smoothly while the other face snaps (or lags), so the L-shape visibly breaks
into two pieces during the press. Fix the shared button style so both faces
animate their dim identically and in the same frame.

## Key Decisions

- **Root cause is animation, not value.** Both faces' opacity is a pure function
  of the shared `pressed` binding, so their *target* opacity is always
  consistent. The de-sync is that the pressed face's opacity change rides
  SwiftUI's implicit button-press animation transaction (the gesture that set
  `configuration.isPressed`), while the other face — which only re-renders
  because the shared `@State` flipped — changes with a different/absent
  transaction. One eases, the other snaps.
- **Fix centrally in `IncrementFaceButtonStyle`, not per-view.** Both faces use
  this one style, so pinning an explicit, identical `.animation(_, value:
  pressed)` there forces both to interpolate opacity with the same curve and
  duration, overriding whatever ambient transaction each face happens to be in.
  This keeps the two faces in lockstep without touching `IncrementBar` or
  `BottomControlRow`.
- **Explicit animation keyed on `pressed`** (rather than removing animation
  entirely) is chosen so the dim still feels responsive, and because scoping the
  animation to `value: pressed` makes it deterministic and identical across both
  style instances — the thing that guarantees sync.

## Implementation

### 1. Pin an identical, explicit dim animation on both faces

**File**: `Sources/AppCore/Views/IncrementFaceButtonStyle.swift`

In `makeBody`, attach an explicit animation to the opacity that is keyed on the
shared `pressed` value, so both style instances animate the dim with the exact
same curve and duration regardless of which face is being pressed:

```swift
func makeBody(configuration: Configuration) -> some View {
    configuration.label
        .opacity(pressed ? 0.72 : 1)
        .animation(.easeOut(duration: 0.12), value: pressed)
        .onChange(of: configuration.isPressed) { isPressed in
            pressed = isPressed
        }
}
```

Because the opacity is driven by the shared `pressed` (not each face's own
`configuration.isPressed`), and the animation is scoped to `value: pressed`,
both faces recompute and animate to the same opacity on the same state change —
overriding the pressed face's implicit press-transaction so it can no longer
run a different (or instantaneous) curve than its partner. Keep the existing
doc comment accurate; extend it briefly to note that the explicit
`.animation(value: pressed)` is what keeps the two faces in sync during the
press, not just the shared binding.

No changes are needed in `IncrementBar.swift`, `BottomControlRow.swift`, or
`CounterBottomBar.swift` — the shared style is the single point that governs both
faces.

## Reused existing code

- `IncrementFaceButtonStyle` from
  `Sources/AppCore/Views/IncrementFaceButtonStyle.swift` (glossary entry:
  `IncrementFaceButtonStyle`) — the single shared style both faces already use;
  the fix lives entirely here.
- `IncrementBar` from `Sources/AppCore/Views/IncrementBar.swift` (glossary entry:
  `IncrementBar`) — top face; unchanged, already binds into the shared `pressed`.
- `BottomControlRow` / `incrementContinuation` from
  `Sources/AppCore/Views/BottomControlRow.swift` — downward extension; unchanged.
- `CounterBottomBar` from `Sources/AppCore/Views/CounterBottomBar.swift` — hoists
  the shared `incrementPressed` state; unchanged.

## Reproduction Test

Pins the bug that the two increment faces dim out of sync while the button is
pressed.

**Target**: No unit-level reproduction is genuinely writable. This is a
frame-timing / animation-curve regression — both faces already resolve to the
same target opacity (0.72), so a value assertion would pass even with the bug
present. The defect is only observable as motion on the simulator (one face
eases, the other snaps), which a unit test cannot see.

Status: NO UNIT REPRO — visual/animation regression. Demonstrate via the
existing pressed-state scenarios rather than a fabricated red:
`counterbottombar-increment-pressed` (both faces dimmed in unison — the target
state), plus `incrementbar-pressed` and `bottomcontrolrow-increment-pressed` for
each face in isolation. Confirm the fix by pressing the live button and watching
both faces fade together.

## Scenarios to Demonstrate

- `counterbottombar-increment-pressed` — the whole L-shape pressed; top bar and
  downward extension dimmed to the same shade, reading as one surface (primary
  proof of the fix).
- `counterbottombar-lefthandedpressed` — mirrored layout pressed; the extension
  and top bar still dim in unison on the opposite side.
- `incrementbar-pressed` — top face alone in its pressed (dimmed) appearance.
- `bottomcontrolrow-increment-pressed` — downward extension dimmed while
  SUBTRACT/RESET/GRAPH stay at full strength.
- Default/un-pressed states (`incrementbar-default`, `counterbottombar` default)
  — both faces at full opacity, confirming the animation doesn't leave a
  residual dim.
