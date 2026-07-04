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
            settings.soundOption = .ding
            settings.hapticOption = .medium
        case "LeftHanded":
            settings.defaultLeftHanded = true
        default:
            settings.soundOption = .off
            settings.hapticOption = .off
            settings.defaultLeftHanded = false
        }
        return settings
    }
}
