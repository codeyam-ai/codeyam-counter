# CodeYam Counter — Android

The Kotlin + Jetpack Compose port of [CodeYam Counter](../README.md), built on
Material 3 and Gradle (Kotlin DSL). It is a feature-parity port of the SwiftUI
app under [`../ios`](../ios) — same counters, colors, graph history, and
sound/haptic feedback — driven by the same codeyam scenarios.

## Layout

Single-module Gradle project:

- **`app/`** — the application module. Domain logic lives in
  `app/src/main/java/com/codeyam/android/` (`CounterModel.kt`, `AppSettings.kt`,
  `CounterHistory.kt`, …); Compose UI lives under that package's `ui/`.
- **`app/src/test/`** — JVM unit tests, run in CI on every push and PR.
- **`build.gradle.kts` / `settings.gradle.kts`** — root build configuration and
  the `:app` module listing.

## Build and test

```bash
# From the repo root
android/gradlew -p android compileDebugKotlin
android/gradlew -p android testDebugUnitTest
```

CI runs these same two commands on Ubuntu with JDK 17.

## Setup

[ANDROID_SETUP.md](../ANDROID_SETUP.md) is the quick start (SDK, emulator, AVD).
[MOBILE_SETUP.md](MOBILE_SETUP.md) is the deeper toolchain reference — PATH
overrides for the editor, cloud-VM nested virtualization, and debug-build CA
interception.
