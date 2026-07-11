---
title: "Neutral Default Counter Names"
mode: ui
createdAt: "2026-07-10T23:26:33Z"
source: manual
---

## Summary

A fresh production install shows the first counter named "PUSH-UPS", which
reads like leaked demo data. Investigation shows it is **not** leaking: the
`SeedPolicy` provenance guard (added in the completed
`production-rejects-scenario-seed-data` plan) is working correctly. The
TestFlight archive builds `-configuration Release`
(`.codeyam/store/appstore/upload-testflight.sh`), so `SeedPolicy.current`
resolves to `.requireProvenance`, which discards any injected/stale scenario
state lacking the app's own marker and falls back to
`CounterModel.defaultCounters()`. The user confirmed the fresh install shows all
counters at **0** — exactly the default-set fallback, not surviving scenario
counts. The problem is simply that `defaultCounters()` hardcodes the same
fitness/demo-flavored names the scenarios use (`PUSH-UPS`, `COFFEE`, `STEPS`,
`BUGS`), so the correct production default *looks* like mock data.

The fix replaces those four hardcoded default names with neutral, generic
starters (`COUNTER 1`…`COUNTER 4`) so a first-time production user sees an
obviously-blank starting slate rather than someone's demo content. Counts,
colors, ids, and order are unchanged, so nothing else about the app's behavior
shifts.

## Key Decisions

- **Rename the defaults; don't touch `SeedPolicy`.** The guard is functioning as
  designed (confirmed: fresh install shows counts of 0). The only change needed
  is the *content* of the fallback starter set, which lives entirely in
  `CounterModel.defaultCounters()`. No policy, provenance, or build-config change
  is warranted.
- **Neutral names, keep the four distinct colors.** Use `COUNTER 1`…`COUNTER 4`
  (uppercase to match how names are stored and rendered — the views display the
  stored string verbatim; there is no `.uppercased()` in `Sources/AppCore/Views`).
  Keep the existing `colorKey`s (`lime`, `coffee`, `steps`, `bugs`) — these are
  palette identifiers in `CounterTheme` (orange/blue/purple/lime hexes), not user
  labels, so the four-color switcher stays visually varied without reading as
  demo data.
- **Keep four starters at 0.** The user chose "neutral generic starters" (not
  blank slots or a single counter), so preserve the count (four) and the
  all-at-zero starting state; only the names change. This keeps ids 1–4 and their
  `order` stable, so the legacy `deletedDefaultIds` migration
  (`migrateDeletedDefaults`) still maps cleanly onto the same id/order templates.
- **Leave the `*Isolated.swift` demo fixtures alone.** The `PUSH-UPS`/`COFFEE`/…
  literals in `Sources/AppCore/CodeyamIsolated/*Isolated.swift` are hand-authored
  debug-only component-isolation scaffolds (`CODEYAM_ISOLATE_COMPONENT`), never
  compiled into the shipped Release binary path. They are capture fixtures, not
  production defaults, so they stay as-is.
- **No scenario re-capture needed.** Every existing `counter-*` scenario seeds its
  own `counters` blob (none rely on `defaultCounters()`), so none of their
  captures change. The genuine fresh-install state is currently *not* demonstrated
  by any scenario — a new scenario is proposed below to close that gap.

## Implementation

### 1. Rename the default starter counters

**File**: `Sources/AppCore/Model.swift`

In `defaultCounters()` (lines 550-557), replace the four demo names with neutral
generic names, keeping every other field (id, count, colorKey, order) identical:

```swift
/// The starter set every fresh install begins with — four counters at zero.
public static func defaultCounters() -> [Counter] {
    [
        Counter(id: 1, name: "COUNTER 1", count: 0, colorKey: "lime", order: 0),
        Counter(id: 2, name: "COUNTER 2", count: 0, colorKey: "coffee", order: 1),
        Counter(id: 3, name: "COUNTER 3", count: 0, colorKey: "steps", order: 2),
        Counter(id: 4, name: "COUNTER 4", count: 0, colorKey: "bugs", order: 3),
    ]
}
```

No other production code references the default names (verified: the only
`defaultCounters()` callers are the seed fallback at lines 183/185 and the legacy
migration at line 542, both name-agnostic).

### 2. Update the tests that pin the default names

**File**: `Tests/AppCoreTests/ModelTests.swift`

Two assertions read back the default names and must move to the new set:

- **`testFreshModelHasFourStarterCountersAtZero`** (line 41): change
  `XCTAssertEqual(model.activeCounter.name, "PUSH-UPS")` to
  `XCTAssertEqual(model.activeCounter.name, "COUNTER 1")`.
- **`testReleasePolicyIgnoresSeededCountersWithoutProvenance`** (line 883):
  change the expected fallback names to
  `["COUNTER 1", "COUNTER 2", "COUNTER 3", "COUNTER 4"]`. The seeded input
  (`PUSH-UPS`, `COFFEE`) and the `[0, 0, 0, 0]` count assertion stay as-is —
  the test's point is that seeded state is *rejected* in favor of the defaults,
  which is exactly what this verifies with the new names.

Optional (accuracy only, not required for passing): the `// PUSH-UPS, COFFEE,
STEPS, BUGS` / `// COFFEE active` / `// blank STEPS` / `// BUGS, the last`
comments at lines 262, 263, 280, 290, 302, 427-431 describe the default set;
update them to the `COUNTER n` names so the tests stay self-documenting. These
tests select by `id`, so they pass regardless — the comments are the only stale
part.

### 3. (Optional) Demonstrate the true fresh-install state

**New scenario** (via the editor's scenario capture, not a hand-written file):
`counter-fresh-install-default` — an empty-container launch (no seeded
`counters`, no provenance marker) that renders the production default: `COUNTER 1`
selected at 0, four counters total. This is the one state no existing scenario
covers, and it is precisely the surface the user was looking at. Capture it so the
production first-launch experience is visible in the scenario gallery.

## Reused existing code

- `CounterModel.defaultCounters()` from `Sources/AppCore/Model.swift` — the sole
  source of the production starter set; the rename lives here.
- `CounterTheme.dotColor` / color-key palette from `Sources/AppCore/Theme.swift`
  — confirms `lime`/`coffee`/`steps`/`bugs` are color identifiers, so the
  counters keep their distinct dot colors after the name change.
- `SeedPolicy` from `Sources/AppCore/SeedPolicy.swift` — unchanged; documented
  here to record that the provenance guard already prevents the actual seed-data
  leak, so this plan only touches default content.
- Existing `ModelTests` fresh-model pattern
  (`testFreshModelHasFourStarterCountersAtZero`,
  `testReleasePolicyIgnoresSeededCountersWithoutProvenance`) — the two updated
  assertions follow the existing suite conventions.

## Scenarios to Demonstrate

- **Fresh production install** — empty container, no provenance → four counters
  named `COUNTER 1`…`COUNTER 4`, all at 0, `COUNTER 1` selected (the corrected
  default; formerly `PUSH-UPS`).
- **Rename a default** — user opens settings on `COUNTER 1`, names it "YOGA" →
  the generic starter becomes a real user counter (revive/edit path unchanged).
- **Seeded scenario still renders demo data** — an existing scenario such as
  `counter-active-count` still shows its injected `PUSH-UPS 7 / COFFEE 3 /
  STEPS 8421 / BUGS 2` in a debug capture, proving the rename touches only the
  default fallback, not seeded scenarios.
- **Distribution launch over stale seeded container** — seeded counters present
  but no provenance marker → app shows `COUNTER 1`…`COUNTER 4` at 0 (guard
  discards the seed, new defaults appear).
