# Contributing

Thanks for your interest in contributing! This is a native iOS app built with
SwiftUI and a shared SwiftPM `AppCore` library.

## Prerequisites

- macOS with a recent Xcode (Swift 5.9+ toolchain)
- For the on-device/simulator app: an iOS 15+ simulator or device

## Building

```bash
swift build
```

The app target lives in `App/` (Xcode project `App.xcodeproj`); the testable
logic lives in the `AppCore` SwiftPM library under `Sources/AppCore`.

## Testing

Tests use **XCTest** and live in `Tests/AppCoreTests/`. Run them with:

```bash
swift test --parallel --disable-swift-testing --xunit-output .codeyam/swift-tests.xml
```

- `--parallel` is required — modern SwiftPM only writes the XCTest xunit
  report when run in parallel.
- `--disable-swift-testing` keeps the xunit output deterministic (it stops the
  swift-testing harness from racing the XCTest writer).

Put each test in `Tests/AppCoreTests/` with a `//` comment directly above each
`func testX()` describing what it verifies and why it matters.

## Pull requests

1. Fork and create a topic branch off `main`.
2. Make your change with tests covering the new behavior.
3. Ensure `swift build` and the test command above both pass.
4. Open a PR describing what changed and why. Fill in the PR template.

## Working with codeyam-editor (optional)

This project is developed with [codeyam-editor](https://codeyam.com), where
code and runnable data scenarios are authored side by side. After adding
tests you can register them with:

```bash
codeyam-editor editor reconcile-registry --auto-apply
```

This is optional — a standard `swift build` + `swift test` workflow is fully
supported.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By
participating you agree to uphold it.
