# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Android app.** A native Kotlin + Jetpack Compose port under `android/`,
  built to parity with the SwiftUI app: the counter model, settings, graph
  history, and sound/haptic feedback all ported, with JVM unit tests and its own
  CI job.
- Multiple counters — add, delete, reorder, and switch between named, colored
  tallies, with persistent blank slots for ones you haven't named yet.
- Counter graph and event history: every increment is recorded and charted on
  its own page.
- App settings and per-counter overrides for handedness, sound, and directional
  (increment vs. decrement) haptics.
- Undo for an accidental reset.
- App Store distribution: listing assets, home-screen presentation, and
  TestFlight upload from CI.

### Changed

- Repository restructured into `ios/` and `android/` app directories sharing one
  set of codeyam scenarios.
- The large number area above the increment bar is now a secondary tap target —
  tapping it increments, on both platforms.
- Taller bottom control row and a press-dim synced across the whole increment
  surface, for easier one-handed use.
- Settings panels are scrollable, collapsible, and only one opens at a time.
- Default counter names are neutral rather than preset examples.

### Fixed

- Scenario seed data is rejected in production builds, so injected state can
  never reach a shipped app.
- Minimum iOS deployment target aligned to 15.0.

### Security

- Debug-only network security config on Android confines CA interception for
  mock data to debug builds.

## [0.1.0] — 2026-06-29

### Added

- Initial public release: SwiftUI counter app with a shared `AppCore` SwiftPM
  library, XCTest coverage, and codeyam-editor scenarios.
