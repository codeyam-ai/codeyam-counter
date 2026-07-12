---
title: "Scrollable, Collapsible Settings Panels"
mode: ui
createdAt: "2026-07-12T00:00:00Z"
source: manual
---

## Summary

Both floating settings overlays — the per-counter `CounterSettingsPanel` and
the system-wide `AppSettingsPanel` — lay their fields out in a plain
content-hugging `VStack` with no height bound. As the per-counter panel grew to
eight sections (NAME, COLOR, STEP, ALLOW NEGATIVE, HANDEDNESS, SOUND, INCREMENT
HAPTIC, DECREMENT HAPTIC) plus a DELETE button, its intrinsic height now runs
off the bottom of the screen on shorter devices, cutting off the lower rows and
DELETE. This plan makes both panels (a) group their feedback/override rows under
a collapsible **FEEDBACK & OVERRIDES** section that starts collapsed by default,
so the resting panel is short, and (b) wrap the field body in a height-bounded
`ScrollView` with the SETTINGS/DONE header pinned above it, so even a fully
expanded panel scrolls within the available space instead of overflowing — DONE
always stays reachable.

## Key Decisions

- **Scroll + collapse together, not either alone** — collapsing the override
  rows keeps the common case short; the bounded `ScrollView` is the safety net
  that guarantees the panel can never run off-screen even when every section is
  expanded on a small device. Chosen over scroll-only (panel still tall and
  awkward by default) and collapse-only (a fully expanded panel can still
  overflow a very short screen).
- **Pin the header outside the scroll** — SETTINGS + DONE (and the App Settings
  header) stay fixed at the top so the primary save/close action is always
  visible and tappable regardless of scroll position.
- **Content-hug up to a cap, don't always fill** — the panel should be as tall
  as its content but never taller than the space between the anchor and the
  screen bottom (less a small margin). A short (collapsed) panel stays compact;
  only an over-tall panel scrolls. Implement with the standard
  measure-content-height + `min(contentHeight, availableHeight)` frame technique
  (a `GeometryReader` for available height and a `PreferenceKey` for content
  height), rather than a raw greedy `ScrollView` that would leave empty space
  below a short panel.
- **Auto-expand FEEDBACK when it carries meaning** — for the per-counter panel,
  seed the section expanded when the counter already has *any* override pinned
  (`handednessOverride`/`soundOverride`/`incrementHapticOverride`/
  `decrementHapticOverride` non-nil), so a user who set overrides sees them
  immediately; collapsed otherwise. This also keeps the existing
  `countersettingspanel-overrides-pinned` scenario meaningful.
- **App Settings collapses too, for consistency** — even though it's shorter and
  writes through immediately, it gets the same pinned-header + bounded-scroll +
  collapsible-FEEDBACK treatment so both overlays share identical chrome.

## Implementation

### 1. Collapsible FEEDBACK section + pinned-header scroll in the per-counter panel

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

- Add `@State private var showFeedback: Bool`, seeded in `init` to
  `counter.handednessOverride != nil || counter.soundOverride != nil ||
  counter.incrementHapticOverride != nil || counter.decrementHapticOverride != nil`
  (expanded when any override is pinned, collapsed otherwise).
- Restructure `body` so the `header` (SETTINGS + DONE) is pinned at the top,
  outside the scroll. Below it, wrap the field stack in a `ScrollView` whose
  content is the existing NAME / COLOR / `CounterStepStepper` / ALLOW NEGATIVE
  rows, then a new disclosure control, then the DELETE button.
- Move the four override rows (HANDEDNESS, SOUND, INCREMENT HAPTIC, DECREMENT
  HAPTIC — currently `CounterSettingsPanel.swift:82-108`) behind a tappable
  disclosure header labeled **FEEDBACK & OVERRIDES** with a chevron
  (`chevron.right` rotating to `chevron.down` when expanded) that toggles
  `showFeedback` with a `withAnimation`. Render the four rows only when
  `showFeedback` is true. Keep each row's existing `OverridePicker` usage and
  `accessibilityIdentifier`s unchanged so nothing else has to move.
- Give the disclosure header its own `accessibilityIdentifier`
  (e.g. `settings-feedback-toggle`) so a scenario/driver can target it.
- Bound the height: the `ScrollView` body must be capped to the space available
  below the pinned header so it scrolls instead of overflowing (see the
  content-hug-up-to-a-cap technique in Key Decisions). Keep the existing panel
  chrome — `.padding(20)`, `CounterTheme.panel` background, `lineStrong` overlay
  stroke, and the outer `.padding(.horizontal, 22)` / `.padding(.top, 12)`.

### 2. Same treatment for the App Settings panel

**File**: `Sources/AppCore/Views/AppSettingsPanel.swift`

- Add an `initiallyExpandedFeedback: Bool = false` init parameter feeding a
  `@State private var showFeedback` (App Settings has no per-counter
  override/default distinction to key off, so it starts collapsed in production;
  the isolated wrapper opts specific scenarios into expanded — see change 4).
- Pin the `header` (APP SETTINGS + DONE) above a height-bounded `ScrollView`,
  mirroring change 1.
- Keep HANDEDNESS and the ALL COUNTERS button visible; group **SOUND ON CHANGE**,
  **INCREMENT HAPTIC**, and **DECREMENT HAPTIC** (`AppSettingsPanel.swift:31-53`)
  behind the same **FEEDBACK & OVERRIDES** disclosure control toggling
  `showFeedback`. Preserve every control's existing `accessibilityIdentifier`.
- Reuse the identical chrome and the same content-hug-up-to-a-cap height bound.

### 3. Optional shared scaffold: available-height for anchored overlays

**File**: `Sources/AppCore/Views/HeaderAnchoredOverlay.swift`

`HeaderAnchoredOverlay` already reserves the anchor's height and pushes content
to the top with a trailing `Spacer(minLength: 0)`, so the space its `content`
occupies is exactly the room a panel may fill. If it's cleaner than each panel
reading its own geometry, expose the available height to `content` — e.g. wrap
`content` in a `GeometryReader` and hand the proxy height to the panel via a
closure/parameter — so both panels cap their scroll body against a single,
correct measurement. This is a tactical refactor: keep it only if it reads
better than a per-panel `GeometryReader`; the generic overlay must stay usable
by the counter-list and graph overlays unchanged.

### 4. Seed FEEDBACK expanded for feedback-focused isolated scenarios

**File**: `Sources/AppCore/CodeyamIsolated/AppSettingsPanelIsolated.swift`

The App Settings scenarios exist specifically to demonstrate sound/haptic state,
so their captures must show the feedback rows rather than a collapsed header.
Pass `initiallyExpandedFeedback: true` to `AppSettingsPanel` for the
`SoundAndHapticOn`, `BothHapticsOff`, and `CustomPairing` cases; leave `default`
and `LeftHanded` collapsed (they demonstrate the resting/handedness state, and
`default` now honestly shows the new collapsed default).

**File**: `Sources/AppCore/CodeyamIsolated/CounterSettingsPanelIsolated.swift`

No change needed — the `overrides-pinned` counter has overrides set, so the
panel's auto-expand heuristic (change 1) opens FEEDBACK for that capture, while
`default` (no overrides) stays collapsed. Confirm the captures reflect this.

## Reused existing code

- `HeaderAnchoredOverlay` from `Sources/AppCore/Views/HeaderAnchoredOverlay.swift`
  (glossary entry: `HeaderAnchoredOverlay`) — the anchored-panel scaffold both
  overlays already sit in; the bounded-height room comes from its layout.
- `SettingsField` from `Sources/AppCore/Views/SettingsField.swift`
  (glossary entry: `SettingsField`) — keep wrapping each row so headings stay
  consistent inside and outside the collapsible section.
- `OverridePicker` from `Sources/AppCore/Views/OverridePicker.swift`
  (glossary entry: `OverridePicker`) — the per-counter override rows moved into
  the FEEDBACK section are unchanged; only their container changes.
- `CounterColorPicker` / `CounterStepStepper` (glossary entries of the same
  names) — the always-visible core rows, untouched.
- `CounterTheme` tokens (`panel`, `lineStrong`, `line`, `ink`, `inkMuted`,
  `accent`, `onAccent`) — reuse for the disclosure header chevron + label so it
  matches existing panel styling.

## Scenarios to Demonstrate

- Per-counter panel, all defaults — FEEDBACK collapsed, panel short and fully
  on-screen (`countersettingspanel-default`).
- Per-counter panel with overrides pinned — FEEDBACK auto-expanded showing the
  HANDEDNESS/SOUND/HAPTIC pins (`countersettingspanel-overrides-pinned`).
- Per-counter panel, FEEDBACK expanded on a short screen — body scrolls, header
  + DONE pinned and reachable, nothing clipped off the bottom.
- App Settings, default — FEEDBACK collapsed, handedness + ALL COUNTERS visible
  (`appsettingspanel-default`).
- App Settings, sound + distinct haptic pairing — FEEDBACK expanded showing the
  sound and both haptic rows (`appsettingspanel-sound-and-haptic-on`,
  `appsettingspanel-custom-distinct-pairing`, `appsettingspanel-both-haptics-off`).
- Toggling the FEEDBACK disclosure open/closed (expand/collapse animation).
