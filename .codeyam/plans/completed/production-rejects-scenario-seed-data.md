---
title: "Production Rejects Scenario Seed Data"
mode: ui
createdAt: "2026-07-09T23:48:37Z"
source: manual
---

## Summary

The TestFlight build launched showing codeyam scenario seed data (e.g. the
`counter-active-count` scenario's `PUSH-UPS 7 / COFFEE 3 / STEPS 8421 / BUGS 2`).
Codeyam scenarios seed state by writing a scenario's `deviceState.preferences`
into `UserDefaults.standard` **using the exact same keys the app uses for real
persistence** — `counters`, `selectedCounterId`, `deletedDefaultIds`,
`counterHistories`, `resetUndoPreviousCount` — plus pure-UI seed flags
(`settingsOpen`, `appSettingsOpen`, `counterListOpen`, `graphOpen`, `leftHanded`,
`soundOption`, `hapticOption`). `CounterModel.init`, `AppSettings.init`, and
`ContentView.init` read those keys at launch with **no build-configuration
guard** (there is not a single `#if DEBUG` in `Sources/` or `App/`). The comment
at `Model.swift:119` claims *"Production ships with none of these keys set"* —
but the moment those keys exist in the container (a stale dev/simulator install
that a TestFlight build was layered over, or any reuse of a seeded container), a
Release build adopts them identically to a debug build. Because seeding and real
persistence share the same keys, the app currently **cannot distinguish
test-injected state from genuine user state**, so nothing rejects it in a
distribution build.

The fix introduces a build-configuration-aware `SeedPolicy`: debug builds (what
codeyam captures run) keep adopting injected state exactly as today, while
distribution builds only trust store state that carries the app's own provenance
marker — a marker codeyam seeding never writes. A distribution launch therefore
ignores any bare injected/stale scenario keys and starts from the clean default
starter set, while a real user's own persisted data (stamped by the app when it
persists) survives across launches.

## Key Decisions

- **Provenance marker over "ignore the keys in production."** Seeding reuses the
  real persistence keys, so a Release build can't just ignore `counters` — that
  is also where genuine user data lives. Instead the app stamps a provenance
  marker whenever *it* persists; codeyam seeding writes the data keys but never
  the marker, so "data present without marker" is a reliable signal of
  injected/stale state that a distribution build can safely discard.
- **Inject the policy, don't rely on `#if DEBUG` alone.** Unit tests compile in
  DEBUG, so a bare `#if DEBUG` release guard would be untestable. `SeedPolicy`
  defaults to `.current` (DEBUG → `.trustInjected`, else `.requireProvenance`)
  but is an injectable init parameter, so tests can exercise the
  `.requireProvenance` path explicitly and pin both behaviors.
- **One shared marker for both stores.** `CounterModel` and `AppSettings` share
  `UserDefaults.standard`; a single provenance key ("this app instance owns this
  container") written by whichever store persists first covers both, keeping the
  guard consistent and cheap.
- **Pure-UI seed flags are gated too.** `settingsOpen` / `appSettingsOpen` /
  `counterListOpen` / `graphOpen` are never persisted by the real app, so a
  distribution build should never honor them — gate them on the same policy so a
  stray `appSettingsOpen=true` can't boot production into a panel.
- **Defense-in-depth on the isolation host.** `CodeyamIsolationHost.root()` is
  env-var driven and harmless in TestFlight (no env vars set), but guarding its
  call site keeps a Release build from ever booting a component in isolation.
  The guard goes at the call site in `App/App.swift`, not in the generated
  `CodeyamIsolationHost.swift` (marked "do not edit by hand").
- **Safe for a first release.** The app is going to TestFlight for the first
  time, so there are no existing Release users whose unstamped data could be
  wiped by requiring the marker — discarding unstamped state is exactly the
  desired behavior here.

## Implementation

### 1. Add the `SeedPolicy` abstraction

**New file**: `Sources/AppCore/SeedPolicy.swift`

Define a small public enum that centralizes the trust decision and the shared
provenance marker so all three read sites agree:

```swift
public enum SeedPolicy {
    /// Adopt any injected/persisted state as-is — debug builds (codeyam captures).
    case trustInjected
    /// Only adopt store state carrying the app's own provenance marker; ignore
    /// bare injected/stale state — distribution builds.
    case requireProvenance

    /// The default for the running build: debug trusts injected state so codeyam
    /// captures keep working; release requires provenance so a distribution
    /// launch never adopts scenario seed data.
    public static var current: SeedPolicy {
        #if DEBUG
        return .trustInjected
        #else
        return .requireProvenance
        #endif
    }

    public static let provenanceKey = "counterStoreProvenance"

    /// True when this policy should honor externally-supplied state in `defaults`.
    /// `.requireProvenance` honors it only once the app's own marker is present.
    public func trustsStore(in defaults: UserDefaults) -> Bool {
        switch self {
        case .trustInjected: return true
        case .requireProvenance: return defaults.object(forKey: Self.provenanceKey) != nil
        }
    }

    /// Stamp the marker so a real user's own persisted data is trusted on the
    /// next launch. Called by each store when it writes to `defaults`.
    public static func stampProvenance(in defaults: UserDefaults) {
        defaults.set(true, forKey: provenanceKey)
    }
}
```

### 2. Gate `CounterModel` on the policy and stamp on persist

**File**: `Sources/AppCore/Model.swift`

- Add a `policy: SeedPolicy = .current` parameter to
  `init(defaults:feedback:policy:)`.
- Compute `let trusted = policy.trustsStore(in: defaults)` once at the top of
  `init`. When `!trusted`, treat the container as empty for *all* injection
  keys: use `Self.defaultCounters()` (ignore `loaded` and the
  `deletedDefaultIds` migration), skip `loadHistories` (empty), force
  `resolvedIndex = 0` (ignore `selectedKey`), and leave `resetUndo = nil`
  (ignore `resetUndoKey`). When `trusted`, behavior is exactly as today.
- In `persistCounters()` (and it is sufficient to do it there, since every
  mutation path already calls it), call `SeedPolicy.stampProvenance(in:
  defaults)` so a real user's data is trusted on the next launch.
- Update the now-inaccurate seeding-contract comment at `Model.swift:106-120`:
  replace the "Production ships with none of these keys set" claim with a note
  that a distribution build requires the provenance marker
  (`SeedPolicy.requireProvenance`) before adopting any of these keys, so stray
  injected/stale state is ignored and the default starter set is used.

### 3. Gate `AppSettings` on the same policy

**File**: `Sources/AppCore/AppSettings.swift`

- Add a `policy: SeedPolicy = .current` parameter to `init(defaults:policy:)`.
- When `!policy.trustsStore(in: defaults)`, initialize `defaultLeftHanded =
  false`, `soundOption = .off`, `hapticOption = .off` (ignore the seeded keys)
  rather than reading them from `defaults`.
- In each `didSet` (or a shared `persist`), call
  `SeedPolicy.stampProvenance(in: defaults)` so a real user's changed settings
  are trusted on the next launch (mirrors `CounterModel`, one shared marker).
- Update the seeding-contract comment (lines 23-34) the same way as `Model.swift`.

### 4. Gate the pure-UI seed flags in `ContentView`

**File**: `Sources/AppCore/ContentView.swift`

In `init` (lines 27-30), only honor the panel-open seed flags when the policy
trusts injected state:

```swift
let trusted = SeedPolicy.current.trustsStore(in: .standard)
_showSettings = State(initialValue: trusted && UserDefaults.standard.bool(forKey: "settingsOpen"))
_showAppSettings = State(initialValue: trusted && UserDefaults.standard.bool(forKey: "appSettingsOpen"))
_showCounterList = State(initialValue: trusted && UserDefaults.standard.bool(forKey: "counterListOpen"))
_showGraph = State(initialValue: trusted && UserDefaults.standard.bool(forKey: "graphOpen"))
```

### 5. Guard the isolation host call site for Release

**File**: `App/App.swift`

Wrap the isolation host so a distribution build always renders `ContentView`:

```swift
WindowGroup {
    #if DEBUG
    CodeyamIsolationHost.root() ?? AnyView(ContentView())
    #else
    ContentView()
    #endif
}
```

Do **not** edit `Sources/AppCore/CodeyamIsolated/CodeyamIsolationHost.swift`
(generated, "do not edit by hand").

## Reused existing code

- `CounterModel` from `Sources/AppCore/Model.swift` (glossary entry:
  `CounterModel`) — the seed-reading init and `persistCounters()`/`defaultCounters()`
  are where the policy gate and provenance stamp attach.
- `AppSettings` from `Sources/AppCore/AppSettings.swift` (glossary entry:
  `AppSettings`) — same seed-reading pattern, gated by the shared policy.
- Existing isolated-suite test pattern in
  `Tests/AppCoreTests/ModelTests.swift` (`UserDefaults(suiteName: "test-\(UUID())")`,
  `suite.set(json, forKey: CounterModel.countersKey)`, reload-from-same-suite)
  — the reproduction and coverage tests follow it exactly.

## Reproduction Test

Pins that a distribution-policy launch ignores codeyam-injected counter state
(present without the app's provenance marker) and starts from the default
starter set.

**Target**: `Tests/AppCoreTests/ModelTests.swift` — run with
`codeyam-editor editor refresh-tests --test testReleasePolicyIgnoresSeededCountersWithoutProvenance`.

```swift
// A distribution-policy launch ignores injected counter state that lacks the
// app's provenance marker (codeyam seeding never writes it), falling back to the
// four default starter counters instead of adopting the seed.
func testReleasePolicyIgnoresSeededCountersWithoutProvenance() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let seeded = #"[{"id":1,"name":"PUSH-UPS","count":7,"colorKey":"lime","allowNegative":true,"step":1,"order":0},{"id":2,"name":"COFFEE","count":3,"colorKey":"coffee","allowNegative":true,"step":1,"order":1}]"#
    suite.set(seeded, forKey: CounterModel.countersKey)
    let model = CounterModel(defaults: suite, policy: .requireProvenance)
    XCTAssertEqual(model.counters.map(\.name), ["PUSH-UPS", "COFFEE", "STEPS", "BUGS"])
    XCTAssertEqual(model.counters.map(\.count), [0, 0, 0, 0])
}
```

Companion coverage to add alongside it (protects the capture workflow and the
real-user round-trip; not the red-first repro):

```swift
// The default (debug) trust policy still adopts injected state, so codeyam
// captures keep seeding the app as before.
func testTrustInjectedPolicyAdoptsSeededCounters() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let seeded = #"[{"id":1,"name":"PUSH-UPS","count":7,"colorKey":"lime","allowNegative":true,"step":1,"order":0}]"#
    suite.set(seeded, forKey: CounterModel.countersKey)
    let model = CounterModel(defaults: suite, policy: .trustInjected)
    XCTAssertEqual(model.activeCounter.count, 7)
}

// Under the distribution policy, a real user's own persisted data survives:
// once the app persists (stamping the provenance marker), a reload trusts it.
func testReleasePolicyTrustsOwnPersistedDataAfterStamp() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let model = CounterModel(defaults: suite, policy: .requireProvenance)
    model.increment() // persists + stamps provenance
    let reloaded = CounterModel(defaults: suite, policy: .requireProvenance)
    XCTAssertEqual(reloaded.activeCounter.count, 1)
}
```

Status: PROPOSED — confirm red at execution. Expected failure: today
`CounterModel.init` has no `policy:` parameter and no `.requireProvenance`
behavior, so the reproduction test fails to compile (unknown argument `policy`);
after the fix it compiles and the seeded counters are rejected in favor of the
default starter set.

## Scenarios to Demonstrate

- **Distribution launch, stale seeded container** — counters key seeded (as in
  `counter-active-count`) but no provenance marker → app shows the clean
  four-at-zero starter set (the production-correct state).
- **Distribution launch, real user data present** — counters + provenance marker
  present → app restores the user's own counts.
- **Debug/capture launch** — existing `counter-active-count` scenario still
  renders `PUSH-UPS 7 / COFFEE 3 / STEPS 8421 / BUGS 2` unchanged (capture
  workflow intact).
- **Stray panel-open flag in a distribution build** — `appSettingsOpen=true`
  seeded but no provenance → app boots to the normal counter screen, no panel.
- **Truly fresh install** — empty container → clean starter set, unchanged.
