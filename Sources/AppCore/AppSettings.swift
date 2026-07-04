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
/// This is the single default source that per-counter overrides resolve against
/// in later plans, so it is deliberately UI-agnostic and independently testable.
public final class AppSettings: ObservableObject {
    @Published public var defaultLeftHanded: Bool {
        didSet { defaults.set(defaultLeftHanded, forKey: Self.leftHandedKey) }
    }
    @Published public var soundOption: SoundOption {
        didSet { defaults.set(soundOption.rawValue, forKey: Self.soundOptionKey) }
    }
    @Published public var hapticOption: HapticOption {
        didSet { defaults.set(hapticOption.rawValue, forKey: Self.hapticOptionKey) }
    }

    private let defaults: UserDefaults

    public static let leftHandedKey = "leftHanded"
    public static let soundOptionKey = "soundOption"
    public static let hapticOptionKey = "hapticOption"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultLeftHanded = defaults.bool(forKey: Self.leftHandedKey)
        self.soundOption = SoundOption(rawValue: defaults.string(forKey: Self.soundOptionKey) ?? "") ?? .off
        self.hapticOption = HapticOption(rawValue: defaults.string(forKey: Self.hapticOptionKey) ?? "") ?? .off
    }
}
