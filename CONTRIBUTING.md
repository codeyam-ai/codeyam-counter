# Contributing

Thanks for your interest in contributing! CodeYam Counter is developed with
[codeyam-editor](https://codeyam.com), where the app's code and its runnable
data **scenarios** are authored side by side against a live preview, and its
test suite is captured and maintained as part of the same workflow.

## The recommended workflow: codeyam-editor

We strongly recommend making your change through codeyam-editor. It keeps the
three things that have to stay in sync — code, tests, and scenarios — aligned
automatically, so your change lands with its scenarios captured and its tests
registered instead of drifting apart over time.

```bash
# Clone the repo
git clone https://github.com/codeyam-ai/codeyam-counter && cd codeyam-counter

# Install codeyam-editor
npm install -g @codeyam-editor/codeyam-editor@latest

# Launch the editor (split-screen terminal + live preview)
codeyam-editor start
```

codeyam-editor requires a subscription to Claude, Gemini, or Codex. Inside the
editor you describe or make a change and it walks you through capturing the
scenarios and tests that cover it, so nothing you contribute goes untested or
unillustrated.

## Prerequisites

The counter ships for two platforms; you only need the toolchain for the one
you're changing.

- **iOS** — macOS with a recent Xcode (Swift 6 toolchain) and an iOS 15+
  simulator or device.
- **Android** — JDK 17 plus the Android SDK (compile SDK 35), and an emulator
  image for the preview. See [ANDROID_SETUP.md](ANDROID_SETUP.md).

## Building and testing by hand — iOS

If you're working without the editor, the standard SwiftPM workflow is fully
supported. The app target lives in `ios/App/` (Xcode project
`ios/App.xcodeproj`); the testable logic lives in the `AppCore` SwiftPM library
under `ios/Sources/AppCore`.

```bash
swift build --package-path ios
swift test --package-path ios --parallel --disable-swift-testing --xunit-output .codeyam/swift-tests.xml
```

- `--parallel` is required — modern SwiftPM only writes the XCTest xunit
  report when run in parallel.
- `--disable-swift-testing` keeps the xunit output deterministic (it stops the
  swift-testing harness from racing the XCTest writer).

Put each test in `ios/Tests/AppCoreTests/` with a `//` comment directly above each
`func testX()` describing what it verifies and why it matters. If you add tests
by hand, register them with the editor so they stay tracked alongside the
scenarios:

```bash
codeyam-editor editor reconcile-registry --auto-apply
```

## Building and testing by hand — Android

The Android port lives under `android/` (Kotlin + Jetpack Compose on Gradle).
See [ANDROID_SETUP.md](ANDROID_SETUP.md) for the SDK/emulator prerequisites; the
build and test commands are:

```bash
android/gradlew -p android compileDebugKotlin
android/gradlew -p android testDebugUnitTest

# Verify the committed Compose snapshots still match
android/gradlew -p android verifyPaparazziDebug
```

[Paparazzi](https://github.com/cashapp/paparazzi) renders the Compose components
off-device on the JVM, so the goldens under
`android/app/src/test/snapshots/` are checked without an emulator. **CI runs
`verifyPaparazziDebug` too**, so a change to a component's rendering fails there
unless you re-record and commit the new goldens:

```bash
android/gradlew -p android recordPaparazziDebug
```

Review the resulting image diff before committing it — a re-record makes the
check pass by definition, so it is only correct when the visual change is
intended.

CI runs these same commands on Ubuntu with JDK 17. Put JVM unit tests under
`android/app/src/test/` and register them with the editor
(`codeyam-editor editor reconcile-registry --auto-apply`) so they stay tracked
alongside the scenarios, exactly as on the iOS side.

## Pull requests

1. Fork and create a topic branch off `main`.
2. Make your change — ideally in codeyam-editor, so its scenarios and tests are
   captured and registered as you go.
3. Ensure the build and tests pass for the platform(s) you touched — the iOS
   `swift build`/`swift test` commands and/or the Android
   `compileDebugKotlin`/`testDebugUnitTest`/`verifyPaparazziDebug` commands
   above. CI runs both platforms.
4. Open a PR describing what changed and why, and fill in the PR template.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By
participating you agree to uphold it. To report a security issue, see
[SECURITY.md](SECURITY.md).
