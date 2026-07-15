import Foundation
import Combine

/// The sound played on a count change. `off` is silent; the rest map to distinct
/// iOS system sounds (resolved in `SystemCounterFeedback`).
public enum SoundOption: String, CaseIterable, Codable {
    case off, tock, pop, click, bloop, ding

    /// Uppercased label for the settings picker.
    public var label: String { rawValue.uppercased() }
}

/// The haptic fired on a count change. `off` is silent; the rest are
/// *qualitatively distinct* feels (resolved in `SystemCounterFeedback`), all
/// fired strong so none reads as merely "weak":
///   - `soft` — a cushioned impact tap at full intensity
///   - `sharp` — a crisp, hard-edged impact tap at full intensity
///   - `double` — a rising two-tap notification pattern (`.success`)
///   - `buzz` — a three-tap notification rumble (`.error`)
/// The old `light`/`medium`/`heavy` amplitude ladder is gone: those varied only
/// in strength (hard to tell apart) and are migrated to their nearest surviving
/// feel by `resolve(_:)`. The default directional pairing (increment `sharp`,
/// decrement `soft`) keeps the crisp-up / dull-down distinction unchanged.
public enum HapticOption: String, CaseIterable, Codable {
    case off, soft, sharp, double, buzz

    public var label: String { rawValue.uppercased() }

    /// Resolve a persisted rawValue (a per-direction key, the legacy single key,
    /// or a `Counter` override) into a current case, mapping the removed
    /// amplitude/`rigid` values to their nearest surviving feel. Returns `nil`
    /// only for a genuinely unknown token, so callers can fall back to a default.
    public static func resolve(_ raw: String?) -> HapticOption? {
        guard let raw else { return nil }
        if let current = HapticOption(rawValue: raw) { return current }
        switch raw {
        case "rigid", "heavy", "medium": return .sharp
        case "light":                     return .soft
        default:                          return nil
        }
    }
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
///   - `incrementHapticOption` — which haptic (if any) fires on each increment
///   - `decrementHapticOption` — which haptic (if any) fires on each subtract
/// Handedness defaults off; sound defaults to `.off`. The two haptics default to
/// a deliberately *distinct* pairing — **increment `sharp`, decrement `soft`** —
/// so a fresh install feels a crisp tap when adding and a dull tap when
/// subtracting, out of the box. A seeded preference can arrive as a string (the
/// editor injects via `defaults write`): handedness coerces via `bool(forKey:)`,
/// and the option enums decode their `rawValue` from `string(forKey:)`, falling
/// back to the built-in default when absent or unrecognized.
///
/// Legacy migration: a TestFlight user who tuned the pre-split single haptic
/// carries the old `hapticOption` key and neither new key. When a direction's
/// new key is absent but that legacy key is present, both directions seed from
/// the legacy value (so an explicit "off" stays off, and a tuned value becomes a
/// matched pair until retuned). New per-direction keys win once written.
///
/// A distribution build requires the app's own provenance marker
/// (`SeedPolicy.requireProvenance`) before adopting any of these keys — the same
/// gate `CounterModel` applies, sharing the one marker across both stores.
/// Under that policy an unstamped container starts from the built-in defaults
/// (right-handed, sound `.off`, haptics `sharp`/`soft`), so stray injected/stale
/// scenario keys are ignored; a real user's own changed settings are trusted once
/// the app has persisted (and stamped the marker). Debug builds keep trusting
/// injected state.
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
    @Published public var incrementHapticOption: HapticOption {
        didSet {
            defaults.set(incrementHapticOption.rawValue, forKey: Self.incrementHapticOptionKey)
            SeedPolicy.stampProvenance(in: defaults)
        }
    }
    @Published public var decrementHapticOption: HapticOption {
        didSet {
            defaults.set(decrementHapticOption.rawValue, forKey: Self.decrementHapticOptionKey)
            SeedPolicy.stampProvenance(in: defaults)
        }
    }

    private let defaults: UserDefaults

    public static let leftHandedKey = "leftHanded"
    public static let soundOptionKey = "soundOption"
    public static let incrementHapticOptionKey = "incrementHapticOption"
    public static let decrementHapticOptionKey = "decrementHapticOption"
    /// The pre-split single-haptic key. Read only as a migration fallback when a
    /// direction's new key is absent (a user who tuned haptics before the split).
    public static let legacyHapticOptionKey = "hapticOption"

    /// The built-in default increment haptic — a crisp `sharp` tap.
    public static let defaultIncrementHaptic: HapticOption = .sharp
    /// The built-in default decrement haptic — a dull `soft` tap, distinct from
    /// the increment default so up and down feel different out of the box.
    public static let defaultDecrementHaptic: HapticOption = .soft

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
        self.incrementHapticOption = trusted
            ? Self.loadHaptic(from: defaults, key: Self.incrementHapticOptionKey,
                              default: Self.defaultIncrementHaptic)
            : Self.defaultIncrementHaptic
        self.decrementHapticOption = trusted
            ? Self.loadHaptic(from: defaults, key: Self.decrementHapticOptionKey,
                              default: Self.defaultDecrementHaptic)
            : Self.defaultDecrementHaptic
    }

    /// Resolve one direction's haptic at launch: the new per-direction key wins;
    /// otherwise migrate the legacy single `hapticOption` key (both directions
    /// share it) if present; otherwise the built-in default for that direction.
    private static func loadHaptic(from defaults: UserDefaults, key: String,
                                   default fallback: HapticOption) -> HapticOption {
        // Route both keys through `resolve(...)` so a persisted amplitude/`rigid`
        // rawValue migrates to its nearest surviving feel instead of being dropped.
        if let option = HapticOption.resolve(defaults.string(forKey: key)) {
            return option
        }
        if let option = HapticOption.resolve(defaults.string(forKey: legacyHapticOptionKey)) {
            return option
        }
        return fallback
    }
}
