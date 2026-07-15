---
title: "Migrate to ios and android Layout"
mode: ui
createdAt: "2026-07-15T17:52:35Z"
source: manual
---

## Summary

Restructure the repo from a single root-level iOS app into a symmetric
two-platform layout: move the existing Swift/SwiftUI app into `ios/` and reserve
`android/` for the forthcoming Kotlin app. This plan is the foundation for the
Android port — it does **not** add Android yet. Its second, equally important
job is to prove that codeyam-editor still works end to end after the move
(config resolution, `assess`, the iOS simulator preview, scenario capture,
`swift test`, glossary/test-registry paths, and the audit gate).

## Key Decisions

- **Move the iOS app into `ios/`, keep `.codeyam/` and repo-level docs at root.**
  The user chose the symmetric `ios/` + `android/` layout over keeping iOS at
  root. `.codeyam/` stays repo-rooted (it is the shared codeyam workspace for
  both apps); only the Swift app's own source/build files relocate.
- **Move `App.xcodeproj`, `App/`, `Package.swift`, `Sources/`, `Tests/`, and
  `.swiftpm/` together as one unit** so every relative reference inside them
  (Package.swift's `path: "Sources/AppCore"`, the xcodeproj's file/group refs)
  keeps resolving without editing the internals. Relative structure is
  preserved; only the shared prefix changes to `ios/`.
- **Run Swift tooling with `--package-path ios` from the repo root** rather than
  `cd ios && …`, so `--xunit-output .codeyam/swift-tests.xml` still writes to the
  repo-rooted path the runner config expects. This keeps `outputPath` unchanged.
- **Repoint codeyam's derived indexes via reconcile, not by hand.** After the
  move, glossary / test-registry / dependency-graph entries point at the old
  `Sources/…` / `Tests/…` paths. Regenerate them with the existing reconcile
  commands instead of editing the JSON stores manually.
- **`editor.json` is hand-edited for the `apps[].dir` change** — `config-override`
  only writes the gitignored `editor.local.json`, but the new layout must be
  team-visible, so the base `editor.json` is the correct home for it.

## Implementation

### 1. Move the iOS app source into `ios/`

**Files** (git-move to preserve history):

- `App/` → `ios/App/`
- `App.xcodeproj/` → `ios/App.xcodeproj/`
- `.swiftpm/` → `ios/.swiftpm/`
- `Package.swift` → `ios/Package.swift`
- `Sources/` → `ios/Sources/`
- `Tests/` → `ios/Tests/`

Use `git mv` so blame/history follow. `MOBILE_SETUP.md`, `CHANGELOG.md`, and the
other repo-level docs stay at root. `build/` and `.build/` are build output
(gitignored) — do not track them; let them regenerate under the new root.

### 2. Repoint the codeyam app registration

**File**: `.codeyam/editor.json`

- `apps[0].dir`: `"."` → `"ios"`.
- `staticChecks[0].command`: `"swift build"` → `"swift build --package-path ios"`
  (leave `filePatterns: ["**/*.swift"]` — they still match under `ios/`).
- `testRunners[0].command` and `targetedCommand`: add `--package-path ios`
  (e.g. `swift test --package-path ios --parallel --disable-swift-testing
  --xunit-output .codeyam/swift-tests.xml`). Keep `outputPath`,
  `testFilePatterns` (`**/Tests/**/*.swift` still matches), and
  `sourceFilePatterns` as-is.

**File**: `.codeyam/stack.json`

- Confirm `simulator.scheme: "App"` still resolves after the move. If
  `start-simulator` can no longer locate `App.xcodeproj` at the root, add the
  minimal path hint it needs (the xcodeproj now lives at `ios/App.xcodeproj`).
  Verify this empirically in step 6 rather than assuming.

### 3. Update CI and release workflows

**File**: `.github/workflows/ci.yml`

Repoint the Swift build/test steps at the new location — either a
`working-directory: ios` on the relevant steps or `--package-path ios` on the
`swift build` / `swift test` invocations, matching whatever the job currently
runs. Keep the `--xunit-output` path repo-rooted.

**File**: `.github/workflows/testflight.yml`

Update the `xcodebuild` project/workspace path to `ios/App.xcodeproj` (and any
`-scheme App` working directory).

### 4. Update repo-level docs and scripts

**File**: `README.md`

- "Build and run locally" block: `swift build` → `swift build --package-path ios`
  and `swift test …` → `swift test --package-path ios …`.
- "Open `App.xcodeproj` in Xcode" → "Open `ios/App.xcodeproj`".
- Scenario-gallery screenshot paths under `.codeyam/scenarios/screenshots/`
  are repo-rooted and unchanged.

**File**: `MOBILE_SETUP.md`

- Note the app now lives under `ios/`; the `start-simulator swift-ios-swiftui`
  command is unchanged (codeyam reads the app dir from `editor.json`).

**File**: `package.json`

- Update the `description` if it names a path; the `testflight` scripts call
  workflows by name and need no change.

### 5. Repoint codeyam's derived metadata

**Commands** (run from repo root, in order):

- `codeyam-editor editor reconcile-glossary --auto-apply` — re-registers entities
  at their new `ios/Sources/…` paths.
- `codeyam-editor editor reconcile-registry --auto-apply` — repoints test-registry
  entries to `ios/Tests/…`.
- `codeyam-editor editor analyze-imports` (or `post-merge-drift-sweep`, which
  chains all three) — refreshes the dependency graph.

Do not hand-edit `glossary.json` / `test-registry.json` / `dependency-graph.json`.

### 6. Verify codeyam-editor still works after the migration

This is the acceptance bar for the plan. Run and confirm each is green:

- `codeyam-editor editor config-show` — `apps[0].dir` resolves to `ios`.
- `codeyam-editor editor assess` — `sourceFiles` count matches pre-move (~75),
  now discovered under `ios/`.
- `swift build --package-path ios` — compiles.
- `codeyam-editor editor refresh-tests` (or `swift test --package-path ios …`)
  — full suite green, `.codeyam/swift-tests.xml` written.
- `codeyam-editor editor start-simulator swift-ios-swiftui` — boots the iOS
  simulator and launches the app from `ios/`.
- Re-capture (or spot-verify) two existing scenarios — e.g.
  `counter-active-count` and `counter-app-settings-open` — and confirm the
  screenshots render the real app, not a blank frame.
- The audit gate is green (glossary/test-registry consistent after reconcile).

## Reused existing code

- The existing Swift app (`ios/App/`, `ios/Sources/AppCore/`, `ios/Tests/`) is
  moved, not rewritten — every entity keeps its glossary identity
  (`CounterModel`, `Counter`, `CounterHistory`, `AppSettings`, `CounterTheme`,
  …) after the reconcile repoint.
- `codeyam-editor editor reconcile-glossary` / `reconcile-registry` /
  `analyze-imports` / `post-merge-drift-sweep` — the canonical path-repoint
  commands; no manual JSON edits.
- `codeyam-editor editor start-simulator swift-ios-swiftui` — unchanged iOS
  preview path, used here as the migration smoke test.
- **Config-field survey:** this plan adds no new config field, threshold, or
  gate dimension — it only edits existing `apps[].dir`, `staticChecks`, and
  `testRunners` values, so there is nothing equivalent to duplicate.

## Scenarios to Demonstrate

- iOS app still boots and renders `counter-active-count` from `ios/` after the move.
- `counter-app-settings-open` still captures correctly (proves scenario handlers
  survive the path change).
- `codeyam-editor editor assess` reports the same source/test inventory, now
  rooted at `ios/` (proves config + glossary repoint).