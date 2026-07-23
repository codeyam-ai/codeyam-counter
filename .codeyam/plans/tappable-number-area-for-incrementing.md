---
title: "Tappable Number Area for Incrementing"
mode: ui
createdAt: "2026-07-23T10:21:53Z"
source: manual
---

## Summary

Make the large flexible number area — the whole region below the counter
switcher and above the increment bar, where the giant numeral sits — an
increment tap target, so tapping anywhere in that space bumps the count just
like the existing L-shaped increment button. Today only the bottom L-shape
(the full-width "TAP TO INCREMENT" bar plus its quarter-width continuation
column) increments; the entire upper half of the screen — the numeral and the
empty space around it — is dead. This turns that dead space into a giant
secondary tap target, giving an even larger, easier-to-hit increment surface.
Applies to both iOS and Android to keep the two targets in parity. The number
area itself shows **no** press dim — only the existing +/continuation faces
keep their dim; the number increments silently on tap.

## Key Decisions

- **Attach the tap at the screen-composition level, not inside `CountHero`.**
  `CountHero` stays a pure display component (it renders in isolated component
  scenarios like `counthero-default` / `counthero-large`; adding interaction
  would pollute those snapshots). The tap goes on the flexible container that
  already sizes the hero region — the `CountHero(...)` call site on iOS and the
  weighted `Box` on Android.
- **Hit the whole flexible frame, not just the numeral.** The numeral is
  left-aligned and only occupies part of the region. Using `contentShape`
  (iOS) / a modifier on the weighted `Box` (Android) makes the entire area —
  including the empty space to the right of the number — tappable, which is the
  point of the request.
- **No visual feedback on the number area** (per product decision). We do
  **not** wire the number into the shared `IncrementFaceButtonStyle` pressed
  state, so pressing the existing + button looks exactly as it does today and
  the numeral never dims. This keeps the change minimal and avoids a
  full-screen dim flash on every tap.
- **Reuse the existing increment action.** Both platforms already expose the
  exact one-line action we need (`model.increment()` / `state.increment()`) —
  the same closure the increment bar fires — so behavior (count bump, haptics,
  sound, graph history) is identical no matter where you tap.
- **Only active when the counter is visible.** The hero region is not rendered
  while the graph is open (both platforms render a `Spacer` instead), so the
  new tap target automatically disappears with it — no extra guarding needed.
  When the settings panel is open it overlays the hero exactly as it overlays
  the increment bar today, so the new target inherits the same
  behind-the-overlay behavior as the existing button.

## Implementation

### 1. iOS — make the hero region tappable

**File**: `ios/Sources/AppCore/ContentView.swift`

At the `CountHero(count: model.activeCounter.count)` call (currently line 58,
inside the `else` branch of the `showGraph` check), attach a full-area tap
gesture that fires the same increment action already wired into
`CounterBottomBar` on line 65:

```swift
CountHero(count: model.activeCounter.count)
    .contentShape(Rectangle())
    .onTapGesture { model.increment() }
    .accessibilityIdentifier("count-hero-increment")
```

- `.contentShape(Rectangle())` makes the entire `.frame(maxHeight: .infinity)`
  hero frame (defined inside `CountHero`) hit-testable, not just the glyph.
- `.onTapGesture { model.increment() }` reuses the exact closure passed as
  `onIncrement:` to the bottom bar — no new model method.
- The accessibility identifier gives UI tests / scenario tooling a handle to
  tap the region (the existing faces use `increment` and
  `increment-continuation`; this is the third face).
- Leave `CountHero.swift` untouched so `counthero-default` / `counthero-large`
  component scenarios are unaffected.

### 2. Android — make the hero region tappable

**File**: `android/app/src/main/java/com/codeyam/android/ui/CounterScreen.kt`

At the weighted `Box` that centers `CountHero` (currently line 78, inside the
`else` branch of the `state.showGraph` check), add a tap gesture that fires the
same `state.increment()` already wired into `CounterBottomBar` on line 87. Use
the app's existing `detectTapGestures` idiom (the same primitive
`Modifier.incrementFace` uses in `CounterBottomBar.kt`), with no press-state
change so there is no dim:

```kotlin
Box(
    modifier = Modifier
        .weight(1f)
        .pointerInput(Unit) { detectTapGestures { state.increment() } }
        .semantics { contentDescription = "count-hero-increment" },
    contentAlignment = Alignment.Center,
) {
    CountHero(count = state.activeCounter.count)
}
```

- The `pointerInput`/`detectTapGestures` modifier makes the full weighted `Box`
  (the flexible region between switcher and bottom bar) tappable.
- `contentDescription` mirrors the iOS accessibility identifier for test
  targeting; add the `androidx.compose.ui.semantics.semantics` /
  `contentDescription` imports if not already present (they are already used by
  `IncrementBar` in `CounterBottomBar.kt`).
- No shared pressed state is touched, so the numeral shows no dim — matching
  iOS and the product decision.
- Leave `CountHero.kt` untouched.

## Reused existing code

- `model.increment()` → `CounterModel.increment()` in
  `ios/Sources/AppCore/Model.swift` — the exact increment action already passed
  as `onIncrement:` to `CounterBottomBar` (`ContentView.swift:65`).
- `state.increment()` in
  `android/app/src/main/java/com/codeyam/android/ui/CounterScreenState.kt` — the
  Android increment action already passed as `onIncrement` to `CounterBottomBar`
  (`CounterScreen.kt:87`).
- `CountHero` (glossary entry: `CountHero`) —
  `ios/Sources/AppCore/Views/CountHero.swift` and
  `android/app/src/main/java/com/codeyam/android/ui/CountHero.kt`. Rendered
  unchanged; the tap wraps its container so its `.frame(maxHeight: .infinity)`
  (iOS) / weighted `Box` (Android) supplies the tappable bounds.
- `detectTapGestures` inside `Modifier.incrementFace` in
  `android/app/src/main/java/com/codeyam/android/ui/CounterBottomBar.kt` — the
  same pointer-input tap idiom, reused (without its press-alpha animation) for
  the hero region.
- Existing-implementation survey: the increment "button" is today the L-shape
  built from `IncrementBar` (glossary: `IncrementBar`) + the
  `increment-continuation` face, styled by `IncrementFaceButtonStyle` (glossary:
  `IncrementFaceButtonStyle`). Nothing today makes the hero/number region
  tappable — verified by reading `ContentView.swift` (no gesture on the
  `CountHero` call) and `CounterScreen.kt` (the weighted `Box` has only
  `weight`/`contentAlignment`, no `clickable`/`pointerInput`). This plan adds a
  net-new tap surface; it does not duplicate an existing one.

## Scenarios to Demonstrate

The change is behavioral (the numeral looks identical before and after a tap),
so demonstrations center on the tap wiring rather than a new visual state:

- **Active count, hero region increments** — from a counter showing a non-zero
  value, a tap anywhere in the number region (including the empty space beside
  the numeral) bumps the count by one, identical to tapping the + bar. Covered
  visually by the existing `counter-active-count` / `android-counter-active-count`
  scenarios (the resting appearance is unchanged); the new behavior is the tap
  target.
- **Fresh install / zero state** — tapping the number region on a counter at 0
  increments to 1 (parity with the + button on first use).
- **Graph open** — the hero region is not rendered, so there is no increment
  target while the graph is open (regression guard: the new tap must not appear
  or fire behind the graph).
- **Settings panel open** — the settings overlay sits over the hero exactly as
  it does over the increment bar; the new target inherits the same
  behind-overlay behavior (no new tap leaking through the panel).
- **Left-handed layout** — the hero region is full-width and layout-agnostic,
  so the enlarged target behaves the same regardless of handedness.