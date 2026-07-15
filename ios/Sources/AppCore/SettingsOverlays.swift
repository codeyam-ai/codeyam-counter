import Foundation

/// The open/closed state of the two settings overlays, which are mutually
/// exclusive: only one settings panel may be on screen at a time. Modeled as one
/// value rather than two independent booleans so the "never both open" rule lives
/// in one testable place instead of being re-derived at each tap site.
///
/// Only the *toggles* enforce exclusivity. Closing a panel never reopens the
/// other, and seeding both open (a scenario writing `settingsOpen` and
/// `appSettingsOpen`) is still representable — the rule governs user taps.
public struct SettingsOverlays: Equatable {
    /// The per-counter settings panel, opened from the switcher's gear.
    public var counterSettings: Bool
    /// The system-wide App Settings panel, opened from the header.
    public var appSettings: Bool

    public init(counterSettings: Bool = false, appSettings: Bool = false) {
        self.counterSettings = counterSettings
        self.appSettings = appSettings
    }

    /// Tapping the header control. Opening App Settings closes the per-counter
    /// panel; closing it just closes it.
    public func togglingAppSettings() -> SettingsOverlays {
        let opening = !appSettings
        return SettingsOverlays(counterSettings: opening ? false : counterSettings,
                                appSettings: opening)
    }

    /// Tapping the switcher's gear. Opening the per-counter panel closes App
    /// Settings; closing it just closes it.
    public func togglingCounterSettings() -> SettingsOverlays {
        let opening = !counterSettings
        return SettingsOverlays(counterSettings: opening,
                                appSettings: opening ? false : appSettings)
    }
}
