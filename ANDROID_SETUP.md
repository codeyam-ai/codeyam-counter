# Kotlin + Jetpack Compose Android App Setup

The Android app lives under `android/` (`android/app`, Gradle Kotlin DSL),
alongside the SwiftUI iOS app under `ios/`. The
`start-simulator kotlin-android-compose` command below is unchanged — codeyam
reads the app directory from `editor.json`.

For the full toolchain reference — SDK/emulator PATH overrides, cloud-VM nested
virtualization (KVM), and debug-build CA interception — see
[android/MOBILE_SETUP.md](android/MOBILE_SETUP.md). This doc is the top-level
quick start.

## Android verify — pre-flight checklist

Before booting the emulator — which takes minutes — run these checks first.
A missing SDK, platform-tools, or AVD surfaces here in seconds.

Run each step in order. Halt at the first failure and surface what's missing to
the user before kicking off anything expensive.

```bash
# 1. Android SDK & platform-tools are installed and on PATH
adb --version
emulator -version

# 2. At least one Android Virtual Device (AVD) is available
emulator -list-avds
```

If `emulator -list-avds` is empty, open Android Studio → Device Manager and
create a virtual device from an AVD system image (AOSP or Google APIs, ideally
debuggable).

If the SDK is installed but the simulator preflight still reports
`adb`/`emulator` not found, the editor server is launching with a different
`PATH` than your interactive shell. Persist the SDK location with the
per-project, gitignored override (do **not** symlink the binaries into a system
directory):

```sh
codeyam-editor editor config-override env.PATH "<android-sdk>/platform-tools:<android-sdk>/emulator:$PATH"
```

Replace `<android-sdk>` with your SDK path (e.g. `~/Library/Android/sdk`).

## Running the App

```bash
# Start emulator and run app
codeyam-editor editor start-simulator kotlin-android-compose
```

## Building and Testing

```bash
# Compile the Kotlin/Compose sources
android/gradlew -p android compileDebugKotlin

# Run the JVM unit tests (CI runs the same command; codeyam consumes the
# JUnit XML they emit to visualize test results)
android/gradlew -p android testDebugUnitTest
```

The `android/local.properties` file (holding `sdk.dir`) is gitignored. Locally,
Android Studio writes it for you; in CI the Android SDK is resolved from
`ANDROID_SDK_ROOT`, so no `local.properties` is needed there.
