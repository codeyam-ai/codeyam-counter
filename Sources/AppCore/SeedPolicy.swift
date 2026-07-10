import Foundation

/// Decides whether the app should trust state already present in a
/// `UserDefaults` container at launch.
///
/// Codeyam scenarios seed state by writing a scenario's
/// `deviceState.preferences` into `UserDefaults` using the *exact same keys the
/// app uses for real persistence* (`counters`, `selectedCounterId`, …). Because
/// seeding and real persistence share those keys, the app cannot distinguish
/// test-injected/stale state from genuine user state by the keys alone. This
/// policy centralizes the trust decision and adds a provenance marker the app
/// stamps when *it* persists — a marker codeyam seeding never writes — so a
/// distribution build can safely discard bare injected/stale state while still
/// honoring a real user's own persisted data.
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

    /// The key the app stamps when it persists. Present ⇒ this container's data
    /// was written by the app itself, not injected by codeyam seeding.
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
