---
title: "Settings Modal Layout & Single-Open"
mode: ui
createdAt: "2026-07-13T18:03:41Z"
source: manual
---

## Summary

Tidy up the two settings overlays. App Settings should stop hiding its
sound/haptic controls behind a collapsible disclosure and simply show them all
the time. The per-counter settings panel keeps its collapsible FEEDBACK &
HANDEDNESS section (collapsed by default, still auto-expanding only when the
counter already pins an override) and gains a caption under that header reading
"Override application-wide settings" so it's clear the section overrides the
app-wide defaults. Opening App Settings and the per-counter Settings must be
mutually exclusive — only one settings overlay can be open at a time. Finally,
fix the ALLOW NEGATIVE toggle getting visually cut off, and make both panel
cards hug their content while capping at the bottom of the screen.

## Key Decisions

- **App Settings: remove the disclosure, always show sound/haptics.** The
  `FeedbackDisclosureToggle` in `AppSettingsPanel` exists only to hide three
  option pickers; App Settings has no per-counter override state to justify a
  collapsed resting state, so the toggle and its `showFeedback` gating go away
  and the SOUND/HAPTIC rows render unconditionally.
- **Per-counter panel: keep the disclosure as-is (collapsed by default, expand
  when overridden).** Per the clarification, leave the existing
  `_showFeedback = State(initialValue: counter.hasFeedbackOverride)` seed
  untouched — it's already collapsed by default and only auto-expands for a
  counter that pins an override, which is the desired behavior. The only new
  thing in this section is the caption.
- **Caption is always visible**, sitting directly beneath the
  FEEDBACK & HANDEDNESS disclosure row (shown whether collapsed or expanded), so
  the user understands the section's purpose before opening it.
- **Single settings overlay.** Toggling one settings panel open force-closes the
  other. Scoped to the two settings overlays (`showSettings`,
  `showAppSettings`) — the counter list and graph overlays are out of scope.
- **Sizing:** the panel cards already use `BoundedScroll` to content-hug up to a
  cap; the fix is to make the cap land exactly at the bottom of the screen and
  ensure short content truly shrinks the card rather than reserving extra
  height, so the modal is only as tall as it needs to be but never runs off the
  bottom.

## Implementation

### 1. Remove the collapsible section from App Settings

**File**: `Sources/AppCore/Views/AppSettingsPanel.swift`

- Delete the `FeedbackDisclosureToggle(... "SOUND & HAPTICS" ...)` row and the
  `if showFeedback { ... }` wrapper so the SOUND ON CHANGE, INCREMENT HAPTIC,
  and DECREMENT HAPTIC `SettingsField`s always render.
- Remove the `showFeedback` `@State` and the `initiallyExpandedFeedback` init
  parameter (and the doc comment referencing the default-collapsed behavior).
- Keep HANDEDNESS, the option pickers, and the ALL COUNTERS button exactly as
  they are.

### 2. Drop the now-unused App Settings feedback-seed wiring

**File**: `Sources/AppCore/ContentView.swift`

- Remove the `appSettingsFeedbackOpen` `@State`, its `init` seed read
  (`UserDefaults ... "appSettingsFeedbackOpen"`), and the
  `initiallyExpandedFeedback: appSettingsFeedbackOpen` argument at the
  `AppSettingsPanel(...)` call site (lines ~28, ~40, ~101).

**File**: `Sources/AppCore/CodeyamIsolated/AppSettingsPanelIsolated.swift`

- Remove the `expandFeedback` computation and the `initiallyExpandedFeedback:`
  argument. The `SoundAndHapticOn` / `BothHapticsOff` / `CustomPairing`
  scenarios still demonstrate their distinct sound/haptic states — those rows
  are now always visible, so the scenarios read correctly without the seed.

### 3. Enforce a single open settings overlay

**File**: `Sources/AppCore/ContentView.swift`

- In `headerBar` (`onSettingsTap`), when opening App Settings also clear
  `showSettings`. In `switcherCard` (`onGearTap`), when opening the per-counter
  panel also clear `showAppSettings`. Guard on the toggle so closing the already-
  open panel still just closes it. Sketch:
  - `onSettingsTap`: `withAnimation { showAppSettings.toggle(); if showAppSettings { showSettings = false } }`
  - `onGearTap`: `withAnimation { showSettings.toggle(); if showSettings { showAppSettings = false } }`

### 4. Add the override caption to the counter panel's feedback section

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

- Directly after the `FeedbackDisclosureToggle(... "FEEDBACK & HANDEDNESS" ...)`
  row (and before the `if showFeedback` block), add an always-visible caption
  `Text("Override application-wide settings")` styled as a muted mono caption
  consistent with existing panel captions (e.g. `CounterTheme.inkMuted`, small
  monospaced weight, matching the `SettingsField` label treatment). Give it an
  accessibility identifier such as `settings-feedback-override-caption`.
- Leave the `_showFeedback` seed unchanged (collapsed by default, auto-expands
  when the counter pins an override).

### 5. Fix the ALLOW NEGATIVE toggle being cut off

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

The current `Toggle(isOn:) { Text("ALLOW NEGATIVE") }` places SwiftUI's trailing
switch flush against the card's inner edge, where it visually clips. Restructure
the row into an explicit full-width layout so the label and the switch each get
guaranteed room:

- Use `HStack { Text("ALLOW NEGATIVE")...; Spacer(); Toggle("", isOn: $allowNegative).labelsHidden() }`
  with `.frame(maxWidth: .infinity)`, keeping `.tint(CounterTheme.accent)` and
  the `settings-allow-negative` accessibility identifier on the control.
- Verify at edit time on the live simulator that the switch no longer clips at
  the right edge in both the resting and expanded panel states.

### 6. Size the panel cards to content, capped at the screen bottom

**Files**: `Sources/AppCore/Views/CounterSettingsPanel.swift`,
`Sources/AppCore/Views/AppSettingsPanel.swift` (and, if needed,
`Sources/AppCore/Views/PanelScrollSupport.swift` for `BoundedScroll`)

- Both panels compute `maxCardHeight = max(160, availableHeight - 12 - 40 - 24)`
  and apply `.frame(maxHeight: maxCardHeight, alignment: .top)`. Confirm the
  card genuinely shrinks to its content when short (it should, via
  `BoundedScroll`'s content-hugging cap) and only reaches `maxCardHeight` when
  content overflows — so the bottom edge sits just above the screen bottom
  rather than the card reserving unused height.
- Re-check the subtracted insets (`12` top pad, `40` DONE row, `24` breathing
  margin) so the fully-expanded card's bottom border lands at/above the screen
  bottom with a small margin, not off-screen. Adjust the breathing constant if
  the always-expanded App Settings now overflows.
- This is a visual/layout tuning step — validate on the live preview across the
  short (resting) and tall (expanded / always-expanded App Settings) states.

## Reused existing code

- `AppSettingsPanel` from `Sources/AppCore/Views/AppSettingsPanel.swift`
  (glossary entry: `AppSettingsPanel`)
- `CounterSettingsPanel` from `Sources/AppCore/Views/CounterSettingsPanel.swift`
  (glossary entry: `CounterSettingsPanel`)
- `FeedbackDisclosureToggle` from `Sources/AppCore/Views/PanelScrollSupport.swift`
  (glossary entry: `FeedbackDisclosureToggle`) — retained for the counter panel
- `BoundedScroll` from `Sources/AppCore/Views/PanelScrollSupport.swift`
  (glossary entry: `BoundedScroll`) — the content-hugging scroll cap
- `SettingsField` from `Sources/AppCore/Views/SettingsField.swift`
  (glossary entry: `SettingsField`) — caption/label styling reference
- `hasFeedbackOverride` from `Sources/AppCore/Model.swift` — the per-counter
  auto-expand seed, left unchanged

## Reproduction Test

Visual/layout changes (disclosure removal, caption, single-open toggle wiring,
toggle clipping, card sizing) with no isolatable unit-level repro — these are
SwiftUI view-composition and geometry behaviors that only manifest on the
rendered simulator. Demonstrate via the scenarios below (the App Settings
isolated scenarios show the always-visible sound/haptic rows; the counter
settings scenarios show the caption and un-clipped toggle).

## Scenarios to Demonstrate

- App Settings open — sound/haptic rows visible with no disclosure toggle
  (previously `appsettingspanel-default`, now always showing the rows)
- App Settings with a distinct sound/haptic pairing — rows visible without any
  expand step (`appsettingspanel-sound-and-haptic-on`)
- Per-counter settings, no overrides — FEEDBACK & HANDEDNESS collapsed with the
  "Override application-wide settings" caption visible under the header
- Per-counter settings, overrides pinned — section auto-expanded, caption still
  visible above the override rows (`countersettingspanel-overrides-pinned`)
- Per-counter settings — ALLOW NEGATIVE toggle fully visible, switch not clipped
- Single-open behavior — opening App Settings while the per-counter panel is
  open closes the per-counter panel (and vice versa)
- Tall/expanded panel — card caps at the bottom of the screen and scrolls; short
  panel hugs its content
