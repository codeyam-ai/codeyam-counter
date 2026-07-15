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
codeyam-editor editor
```

codeyam-editor requires a subscription to Claude, Gemini, or Codex. Inside the
editor you describe or make a change and it walks you through capturing the
scenarios and tests that cover it, so nothing you contribute goes untested or
unillustrated.

## Prerequisites

- macOS with a recent Xcode (Swift 6 toolchain)
- An iOS 15+ simulator or device

## Building and testing by hand

If you're working without the editor, the standard SwiftPM workflow is fully
supported. The app target lives in `App/` (Xcode project `App.xcodeproj`); the
testable logic lives in the `AppCore` SwiftPM library under `Sources/AppCore`.

```bash
swift build
swift test --parallel --disable-swift-testing --xunit-output .codeyam/swift-tests.xml
```

- `--parallel` is required — modern SwiftPM only writes the XCTest xunit
  report when run in parallel.
- `--disable-swift-testing` keeps the xunit output deterministic (it stops the
  swift-testing harness from racing the XCTest writer).

Put each test in `Tests/AppCoreTests/` with a `//` comment directly above each
`func testX()` describing what it verifies and why it matters. If you add tests
by hand, register them with the editor so they stay tracked alongside the
scenarios:

```bash
codeyam-editor editor reconcile-registry --auto-apply
```

## Pull requests

1. Fork and create a topic branch off `main`.
2. Make your change — ideally in codeyam-editor, so its scenarios and tests are
   captured and registered as you go.
3. Ensure `swift build` and the test command above both pass.
4. Open a PR describing what changed and why, and fill in the PR template.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By
participating you agree to uphold it. To report a security issue, see
[SECURITY.md](SECURITY.md).
