# Kotlin + Jetpack Compose (Android) Setup

This project is a native Android app built using **Kotlin**, **Jetpack Compose**, **Material 3**, and **Gradle (Kotlin DSL)**.

## Pre-flight Checklist (Android Emulator)

Before running the emulator preview, verify your local Android development toolchain:

1. **Android SDK & Platform-Tools** are installed and added to your `PATH`.
   - `adb --version`
   - `emulator -version`

2. **Android Virtual Device (AVD)** is available.
   - `emulator -list-avds`

If `emulator -list-avds` is empty, open Android Studio, navigate to Device Manager, and create a new virtual device using an AVD system image (AOSP or Google APIs, ideally debuggable).

### `adb` / `emulator` not on the editor's PATH

If the SDK is installed but the simulator preflight still reports `adb`/`emulator` not found, the editor server is launching with a different `PATH` than your interactive shell. Persist the SDK location for the editor with the per-project, gitignored override — **do not symlink the binaries into a system directory** like `/opt/homebrew/bin`:

```sh
codeyam-editor editor config-override env.PATH "<android-sdk>/platform-tools:<android-sdk>/emulator:$PATH"
```

Replace `<android-sdk>` with your SDK path (e.g. `~/Library/Android/sdk`). The `$PATH` is expanded by your shell when you run the command, so the value snapshots your current `PATH` plus the SDK directories into the gitignored `.codeyam/editor.local.json`, which the editor overlays onto every `adb`/`emulator` spawn.

## Cloud VM & Nested Virtualization

When running in a cloud VM (e.g., Google Cloud Engine), nested virtualization must be enabled so KVM works:

```bash
# Check if KVM is available
kvm-ok
# Or check the device node directly
ls -l /dev/kvm
```

Without KVM/nested virtualization, the emulator will fail to boot or run extremely slowly.

## Debug-Build CA Interception

For local API mock-data interception, this scaffold includes a custom `network_security_config.xml` in the `app/src/debug` source set. This config allows user-added Certificates (such as the CodeYam CA) for secure network requests, strictly within debug builds.

The production configuration (`app/src/main`) does not contain these debug settings.

## Building and Testing

To compile and check Kotlin source files:

```bash
./gradlew compileDebugKotlin
```

To run the JVM unit tests and produce JUnit XML reports (which CodeYam consumes to visualize test results):

```bash
./gradlew test
```
