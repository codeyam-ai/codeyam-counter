---
title: "Rename Settings Feedback Section Titles"
mode: ui
createdAt: "2026-07-13T12:22:28Z"
source: manual
---

## Summary

Both the App Settings and Counter Settings panels render a shared collapsible
disclosure section whose header reads `FEEDBACK & OVERRIDES`. In App Settings
this is doubly wrong: those controls set the app-wide *defaults*, not overrides
of anything. Drop "OVERRIDES" from both panels and give each section a title
that describes the controls it reveals: `SOUND & HAPTICS` for App Settings
(sound-on-change + increment/decrement haptic) and `FEEDBACK & HANDEDNESS` for
Counter Settings (which also exposes a per-counter handedness control). This is
a label-only change — no behavior, state, accessibility identifiers, or persisted
data change.

## Key Decisions

- **Parameterize the shared toggle rather than fork it.** `FeedbackDisclosureToggle`
  hardcodes `Text("FEEDBACK & OVERRIDES")` and is used by both panels. Add a
  `title: String` property so each panel passes its own descriptive label,
  keeping the single shared component (chevron, styling, tap behavior) intact.
- **Titles chosen to match the visible controls.** App Settings section →
  `SOUND & HAPTICS` (its three fields are Sound on change, Increment haptic,
  Decrement haptic). Counter Settings section → `FEEDBACK & HANDEDNESS` (adds a
  Handedness field on top of the sound/haptic fields, so "feedback" plus the
  explicit handedness reads accurately).
- **Keep all accessibility identifiers unchanged.** The `app-settings-feedback-toggle`
  and `settings-feedback-toggle` identifiers are referenced by scenarios/tooling;
  only the human-visible `Text` changes. No test asserts the literal
  "FEEDBACK & OVERRIDES" string (it only appears in code comments), so this is
  safe.

## Implementation

### 1. Add a `title` property to the shared disclosure toggle

**File**: `Sources/AppCore/Views/PanelScrollSupport.swift`

`FeedbackDisclosureToggle` currently hardcodes `Text("FEEDBACK & OVERRIDES")`.
Add a `let title: String` stored property and render `Text(title)` in its place.
Update the doc comment (line ~36) that calls it "The shared 'FEEDBACK & OVERRIDES'
disclosure header" to describe it generically as a titled/collapsible feedback
disclosure header whose label is supplied by the caller. Everything else
(font, tracking, chevron rotation, `accessibilityIdentifier(identifier)`,
tap-to-toggle) stays the same.

### 2. Pass the App Settings title

**File**: `Sources/AppCore/Views/AppSettingsPanel.swift`

At the `FeedbackDisclosureToggle(...)` call (line ~48), pass
`title: "SOUND & HAPTICS"` alongside the existing
`identifier: "app-settings-feedback-toggle"`. Update the stale
`showFeedback` doc comment (line ~17, "Whether the FEEDBACK & OVERRIDES section
starts expanded") to reference the section by its new name / role.

### 3. Pass the Counter Settings title

**File**: `Sources/AppCore/Views/CounterSettingsPanel.swift`

At the `FeedbackDisclosureToggle(...)` call (line ~100), pass
`title: "FEEDBACK & HANDEDNESS"` alongside the existing
`identifier: "settings-feedback-toggle"`. Update the stale `showFeedback`
doc comment (line ~28, "Whether the FEEDBACK & OVERRIDES section is expanded")
to reference the section by its new name.

### 4. Refresh remaining stale references to the old section name (comments only)

**File**: `Sources/AppCore/ContentView.swift`, `Sources/AppCore/Model.swift`,
`Sources/AppCore/CodeyamIsolated/FeedbackDisclosureToggleIsolated.swift`,
`Sources/AppCore/CodeyamIsolated/AppSettingsPanelIsolated.swift`,
`Tests/AppCoreTests/CounterFeedbackOverrideTests.swift`

Several doc/inline comments name the section "FEEDBACK & OVERRIDES"
(e.g. `ContentView.swift:25`, `Model.swift:137`). These are comments only — no
functional impact — but should be updated to the panel-appropriate name so the
codebase stays self-consistent. No assertion or identifier depends on the old
string.

## Reused existing code

- `FeedbackDisclosureToggle` from `Sources/AppCore/Views/PanelScrollSupport.swift`
  (glossary entry: `FeedbackDisclosureToggle`) — the single shared header being
  parameterized.
- `AppSettingsPanel` from `Sources/AppCore/Views/AppSettingsPanel.swift`
  (glossary entry: `AppSettingsPanel`) — passes the new App Settings title.
- `CounterSettingsPanel` from `Sources/AppCore/Views/CounterSettingsPanel.swift`
  (glossary entry: `CounterSettingsPanel`) — passes the new Counter Settings title.
- `FeedbackDisclosureToggleIsolated` from
  `Sources/AppCore/CodeyamIsolated/FeedbackDisclosureToggleIsolated.swift`
  (glossary entry: `FeedbackDisclosureToggleIsolated`) — isolated harness that
  instantiates the toggle; must pass a `title` once the property is required.

## Scenarios to Demonstrate

- App Settings panel, feedback section expanded — header reads `SOUND & HAPTICS`,
  showing Sound on change / Increment haptic / Decrement haptic.
- App Settings panel, feedback section collapsed — header reads `SOUND & HAPTICS`
  with the chevron pointing right.
- Counter Settings panel, feedback section expanded on a counter with pinned
  overrides — header reads `FEEDBACK & HANDEDNESS`, showing Handedness / Sound /
  Increment haptic / Decrement haptic.
- Counter Settings panel, feedback section collapsed on a fresh counter — header
  reads `FEEDBACK & HANDEDNESS` with the chevron pointing right.
- `FeedbackDisclosureToggle` isolated component, both expanded and collapsed
  states, verifying the parameterized title renders.
