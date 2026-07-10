import Foundation
import Combine

/// The sound played on a count change. `off` is silent; the rest map to distinct
/// iOS system sounds (resolved in `SystemCounterFeedback`).
public enum SoundOption: String, CaseIterable, Codable {
    case off, tock, pop, click, bloop, ding

    /// Uppercased label for the settings picker.
    public var label: String { rawValue.uppercased() }
}

/// The haptic fired on a count change. `off` is silent; the rest map to
/// `UIImpactFeedbackGenerator` intensities (resolved in `SystemCounterFeedback`).
public enum HapticOption: String, CaseIterable, Codable {
    case off, light, medium, heavy

    public var label: String { rawValue.uppercased() }
}

/// System-wide app defaults, consolidated into one observable store.
///
/// Seeding contract (mirrors `CounterModel`): at launch the editor injects a
/// scenario's `deviceState.preferences` into `UserDefaults` *before* the app
/// starts, so this store reads those same keys in `init` and each scenario
/// observes its seeded defaults from the first frame:
///   - `leftHanded` — the mirrored bottom-bar layout (reuses the key formerly
///     read by `ContentView`'s `@AppStorage("leftHanded")`)
///   - `soundOption` — which sound (if any) plays on each increment/subtract
///   - `hapticOption` — which haptic (if any) fires on each increment/subtract
/// Handedness defaults off; sound/haptic default to `.off`. A seeded preference
/// can arrive as a string (the editor injects via `defaults write`): handedness
/// coerces via `bool(forKey:)`, and the option enums decode their `rawValue` from
/// `string(forKey:)`, falling back to `.off` when absent or unrecognized.
///
/// A distribution build requires the app's own provenance marker
/// (`SeedPolicy.requireProvenance`) before adopting any of these keys — the same
/// gate `CounterModel` applies, sharing the one marker across both stores.
/// Under that policy an unstamped container starts from the built-in defaults
/// (right-handed, sound/haptic `.off`), so stray injected/stale scenario keys
/// are ignored; a real user's own changed settings are trusted once the app has
/// persisted (and stamped the marker). Debug builds keep trusting injected state.
///
/// This is the single default source that per-counter overrides resolve against
/// in later plans, so it is deliberately UI-agnostic and independently testable.
public final class AppSettings: ObservableObject {
    @Published public var defaultLeftHanded: Bool {
        didSet {
            defaults.set(defaultLeftHanded, forKey: Self.leftHandedKey)
            SeedPolicy.stampProvenance(in: defaults)
        }
    }
    @Published public var soundOption: SoundOption {
        didSet {
            defaults.set(soundOption.rawValue, forKey: Self.soundOptionKey)
            SeedPolicy.stampProvenance(in: defaults)
        }
    }
    @Published public var hapticOption: HapticOption {
        didSet {
            defaults.set(hapticOption.rawValue, forKey: Self.hapticOptionKey)
            SeedPolicy.stampProvenance(in: defaults)
        }
    }

    private let defaults: UserDefaults

    public static let leftHandedKey = "leftHanded"
    public static let soundOptionKey = "soundOption"
    public static let hapticOptionKey = "hapticOption"

    public init(defaults: UserDefaults = .standard, policy: SeedPolicy = .current) {
        self.defaults = defaults
        // Under the distribution policy an unstamped container is untrusted, so
        // start from the built-in defaults and ignore any injected/stale keys.
        // `didSet` does not fire during init, so no marker is stamped here — only
        // a real user change persists and stamps. (Shares the one marker with
        // `CounterModel`.)
        let trusted = policy.trustsStore(in: defaults)
        self.defaultLeftHanded = trusted ? defaults.bool(forKey: Self.leftHandedKey) : false
        self.soundOption = trusted
            ? (SoundOption(rawValue: defaults.string(forKey: Self.soundOptionKey) ?? "") ?? .off)
            : .off
        self.hapticOption = trusted
            ? (HapticOption(rawValue: defaults.string(forKey: Self.hapticOptionKey) ?? "") ?? .off)
            : .off
    }
}
