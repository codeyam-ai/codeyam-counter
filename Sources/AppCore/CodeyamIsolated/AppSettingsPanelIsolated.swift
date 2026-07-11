import SwiftUI

// Hand-authored isolation scaffold for AppSettingsPanel — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=AppSettingsPanel; CODEYAM_ISOLATE_SCENARIO picks the case.
struct AppSettingsPanelIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        AppSettingsPanel(settings: sampleSettings, onOpenList: {}, onClose: {})
    }

    // A throwaway per-scenario UserDefaults suite so the toggles start in the
    // state the scenario is demonstrating without touching the shared domain.
    private var sampleSettings: AppSettings {
        let suite = UserDefaults(suiteName: "isolated-app-settings-\(scenario)")!
        let settings = AppSettings(defaults: suite)
        switch scenario {
        case "SoundAndHapticOn":
            // Sound on plus the distinct default haptic pairing (Rigid increment /
            // Soft decrement) — the new two-control layout.
            settings.soundOption = .ding
            settings.incrementHapticOption = .rigid
            settings.decrementHapticOption = .soft
        case "BothHapticsOff":
            // A user who wants no haptic feedback in either direction.
            settings.soundOption = .off
            settings.incrementHapticOption = .off
            settings.decrementHapticOption = .off
        case "CustomPairing":
            // The two directions freely and independently retuned to a custom
            // distinct pair (increment Heavy / decrement Light).
            settings.soundOption = .off
            settings.incrementHapticOption = .heavy
            settings.decrementHapticOption = .light
        case "LeftHanded":
            settings.defaultLeftHanded = true
        default:
            // The out-of-box defaults: sound off, haptics at the built-in Rigid /
            // Soft pairing (left untouched so the panel shows the real default).
            settings.soundOption = .off
            settings.defaultLeftHanded = false
        }
        return settings
    }
}
