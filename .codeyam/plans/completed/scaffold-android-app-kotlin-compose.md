---
title: "Scaffold Android App (Kotlin + Compose)"
mode: ui
createdAt: "2026-07-15T17:52:43Z"
source: manual
dependsOn: ["migrate-to-ios-and-android-layout"]
---

## Summary

Add a second, native Android app to the repo using codeyam's shipped
`kotlin-android-compose` stack (Kotlin + Jetpack Compose), scaffolded into
`android/` and registered as a second `apps[]` entry alongside the iOS app.
This plan stands up the empty, runnable Android shell and wires it into
codeyam-editor (preview via the Android emulator, App-tab switching, test
workflow) — it does **not** port the counter logic or UI yet. Those follow in
later plans.

## Key Decisions

- **Use `editor scaffold-app`, not a hand-built Gradle project.** The command
  validates before writing, extracts the official `kotlin-android-compose`
  template into `android/`, and appends the `apps[]` entry without touching the
  iOS entry — the same additive, zero-blast-radius path the new-companion-app
  flow uses. Building the Gradle scaffold by hand would drift from what a fresh
  codeyam Android project gets.
- **No `--share-db`.** The counter app is pure on-device state (observable
  model, no backend), so the Android app owns its own state exactly as the iOS
  app does. Confirmed against `stack.json::data.type = "observable-model"` and
  `editor.json::database = null`.
- **Emulator preview is viable.** `start-simulator` explicitly lists
  `kotlin-android-compose` among its supported stacks, so scenario capture on
  Android uses the same simulator/emulator path the iOS app already relies on —
  no browser-isolation fallback needed.
- **Resolve the single-`stack.json` question during this plan.** The repo has
  one repo-global `.codeyam/stack.json` (currently `swift-ios-swiftui`). Adding
  a second native stack requires confirming how codeyam selects the active
  stack per app (via `stack-from-apps` / the App tab). This is wired and
  verified here so downstream plans can assume both previews work.

## Implementation

### 1. Scaffold the Android app

**Command**:

```bash
codeyam-editor editor scaffold-app \
  --into android \
  --stack kotlin-android-compose \
  --name "CodeYam Counter (Android)"
```

This extracts the template into `android/` and appends a second `apps[]` entry
to `.codeyam/editor.json` (the `ios` entry from the previous plan is preserved
verbatim). Do not pass `--share-db` or `--port` (port is web-only).

If the command reports a collision or an unknown-stack error, surface it
verbatim and stop — do not hand-roll a workaround.

### 2. Wire the active-stack selection for two native apps

**File**: `.codeyam/stack.json` (+ `editor.json` as needed)

- Determine how codeyam resolves the active stack when two native apps exist.
  Options the tooling already exposes: `stack-from-apps --stack-id
  kotlin-android-compose` (re-seeds `stack.json` from an app), and the App tab's
  app switcher. Confirm the mechanism and document it in the plan's follow-up
  notes so switching between the iOS and Android previews is a known, repeatable
  step.
- Ensure `staticChecks` / `testRunners` gain the Android build+test commands
  (Gradle) scoped to `android/**` file patterns, so the audit runs the right
  toolchain per platform. The Android Gradle wrapper (`./gradlew`) ships in the
  template.

### 3. Update `.gitignore` for Android build output

**File**: `.gitignore`

Add the standard Kotlin/Android ignores that aren't already covered:
`android/.gradle/`, `android/build/`, `android/app/build/`, `android/local.properties`,
`.idea/` (if not present). (The existing `staticChecks.excludePatterns` already
anticipate `**/.gradle/**` and `**/build/**`.)

### 4. Document the second app

**File**: `README.md`

Add a short "Android" note under the build section stating the Android app lives
in `android/` and is a Kotlin + Jetpack Compose port (WIP), with the emulator
run command. Full setup docs land in the CI/parity plan.

## Reused existing code

- `codeyam-editor editor scaffold-app` — the canonical companion-app scaffolder
  (see the `codeyam-new-app` skill), used here for a second *native* app.
- `codeyam-editor editor start-simulator kotlin-android-compose` — the Android
  emulator preview path (listed as supported by `start-simulator`).
- `codeyam-editor editor stack-from-apps --stack-id kotlin-android-compose` —
  seeds/switches the active stack for the Android app.
- The iOS `apps[]` entry (`dir: "ios"`) from the migration plan is left
  untouched — the scaffold is purely additive.
- **Config-field survey:** no new config *field* is invented; `scaffold-app`
  appends a standard `apps[]` entry and the plan adds Gradle entries to the
  existing `staticChecks` / `testRunners` arrays. Nothing equivalent is being
  duplicated.

## Scenarios to Demonstrate

- The scaffolded Android app boots in the emulator via
  `start-simulator kotlin-android-compose` and shows the template's starter
  screen (proves the emulator preview path works before any porting).
- `codeyam-editor editor config-show` lists **two** `apps[]` entries — `ios` and
  `android` — and the iOS entry is unchanged.
- Switching the active app to iOS still boots the existing counter app (proves
  the two-app switch is non-destructive).