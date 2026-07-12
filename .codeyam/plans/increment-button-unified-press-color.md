---
title: "Increment Button Presses As One Surface"
mode: ui
createdAt: "2026-07-12T10:43:52Z"
source: manual
---

## Summary

The increment button is drawn as two separate `Button`s: the full-width top
(`IncrementBar`) and the downward extension that drops into the lower control
row (`incrementContinuation` inside `BottomControlRow`). Together they read as a
single L-shaped button, but each uses `.buttonStyle(.plain)`, whose press
feedback dims only the face that was actually touched. So tapping the top bar
dims the top while the downward extension stays at full accent color (and vice
versa), breaking the illusion that the two areas are one button. The fix is to
share a single pressed state across both faces so pressing either one dims
**both** in unison.

## Key Decisions

- **Share one pressed state rather than merge the views.** The two faces are
  non-contiguous in the view tree (the lower control row's SUBTRACT/RESET/GRAPH
  sit between them in the layout), so they cannot cleanly become one `Button`.
  Instead, both faces are children of `CounterBottomBar`, so we hoist a single
  `@State private var incrementPressed` there and pass it as a `Binding` to both
  faces. Each face reports its own press into the shared binding and renders its
  dim from the shared value — so either face pressing dims both.
- **Replace `.buttonStyle(.plain)` on the two increment faces with a small
  custom `ButtonStyle`** (`IncrementFaceButtonStyle`) that (a) syncs its own
  `configuration.isPressed` into the shared `pressed` binding and (b) dims the
  label opacity based on the shared value. This preserves the existing "dims a
  bit on press" look while making it consistent across both faces. The other
  controls (SUBTRACT/RESET/GRAPH) keep `.buttonStyle(.plain)` and are untouched.
- **Default the new binding to `.constant(false)`** in each view's `init`, so the
  isolated capture scaffolds (`IncrementBarIsolated`, `BottomControlRowIsolated`)
  and any other call sites compile unchanged — they simply render the static,
  un-pressed appearance.

## Implementation

### 1. Add a shared-press button style

**New file**: `Sources/AppCore/Views/IncrementFaceButtonStyle.swift`

A `ButtonStyle` that both increment faces use. It takes a `@Binding var pressed:
Bool`, dims its label when `pressed` is true, and writes its own
`configuration.isPressed` back into the binding so the *other* face mirrors it:

```swift
import SwiftUI

/// Shared press styling for the two faces of the increment button (the top
/// `IncrementBar` and the `incrementContinuation` in `BottomControlRow`). The
/// button is drawn as two separate hit areas, so each face syncs its own
/// `isPressed` into a shared `pressed` binding and dims from that shared value —
/// pressing either face dims BOTH, so the whole thing reads as one surface.
struct IncrementFaceButtonStyle: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(pressed ? 0.72 : 1)
            .onChange(of: configuration.isPressed) { _, isPressed in
                pressed = isPressed
            }
    }
}
```

Use the two-parameter `onChange(of:)` closure form matching the project's
deployment target (fall back to the single-parameter deprecated form only if the
target predates iOS 17). The `0.72` dim should be tuned to match the current
`.plain` press feel — pick whatever reads as the same "dims a bit" the button
shows today.

### 2. Drive both faces from one pressed state

**File**: `Sources/AppCore/Views/CounterBottomBar.swift`

Add `@State private var incrementPressed = false`. Pass `$incrementPressed` into
both children:

- `IncrementBar(leftHanded:plusColumnWidth:pressed:onIncrement:)`
- `BottomControlRow(... incrementPressed: $incrementPressed ...)`

### 3. Apply the shared style to the top face

**File**: `Sources/AppCore/Views/IncrementBar.swift`

Add a `@Binding var pressed: Bool` (init param defaulting to `.constant(false)`).
Replace `.buttonStyle(.plain)` on the top `Button` with
`.buttonStyle(IncrementFaceButtonStyle(pressed: $pressed))`. The accent
background and label already live inside the button's label, so they dim together
correctly.

### 4. Apply the shared style to the downward extension

**File**: `Sources/AppCore/Views/BottomControlRow.swift`

Add a `@Binding var incrementPressed: Bool` (init param defaulting to
`.constant(false)`). In `incrementContinuation`, replace `.buttonStyle(.plain)`
with `.buttonStyle(IncrementFaceButtonStyle(pressed: $incrementPressed))`. Leave
`controlsGroup` (SUBTRACT/RESET/GRAPH) and its `.plain` buttons unchanged.

### 5. Isolated scaffolds — no change required

**Files**: `Sources/AppCore/CodeyamIsolated/IncrementBarIsolated.swift`,
`Sources/AppCore/CodeyamIsolated/BottomControlRowIsolated.swift`

The defaulted `.constant(false)` bindings mean these compile without edits and
keep rendering the static, un-pressed appearance. Optionally, a new isolated
scenario could force `pressed`/`incrementPressed` to `true` to capture the
"pressed" look, but that is not required for the fix.

## Reused existing code

- `IncrementBar` from `Sources/AppCore/Views/IncrementBar.swift` (glossary entry:
  `IncrementBar`) — the top face; gains the shared `pressed` binding.
- `BottomControlRow` from `Sources/AppCore/Views/BottomControlRow.swift`
  (glossary entry: `BottomControlRow`) — owns `incrementContinuation`, the
  downward extension; gains the shared `incrementPressed` binding.
- `CounterBottomBar` from `Sources/AppCore/Views/CounterBottomBar.swift` — the
  common parent that already composes both faces; hosts the shared `@State`.
- `CounterTheme.accent` from `Sources/AppCore/Theme.swift` (glossary entry:
  `CounterTheme`) — the lime accent both faces fill with; unchanged.

## Reproduction Test

Pinning this behavior: pressing either increment face should dim both faces
together.

**Target**: no unit-level reproduction test. This is a SwiftUI press-state
rendering regression in view code with no isolatable pure-logic seam — the
faulty behavior is that two `.buttonStyle(.plain)` buttons dim independently,
which is only observable by driving a live press and comparing the two faces'
rendered color. There is no model/helper function whose output changes.

Status: PROPOSED — demonstrate via the "increment pressed" scenario below
(capture the button mid-press and confirm both the top bar and the downward
extension are dimmed to the same shade).

## Scenarios to Demonstrate

- **Increment button at rest** — both faces show full accent; the two areas read
  as one continuous surface.
- **Increment button pressed (top bar tapped)** — both the top bar and the
  downward extension are dimmed together to the same shade.
- **Increment button pressed (extension tapped)** — pressing the downward
  extension dims the top bar too, symmetric with the above.
- **Left-handed layout, pressed** — mirrored layout (`leftHanded: true`); the
  extension and top bar still dim in unison on the opposite side.
- **Other controls unaffected** — pressing SUBTRACT / RESET / GRAPH dims only
  that control, never the increment faces.
