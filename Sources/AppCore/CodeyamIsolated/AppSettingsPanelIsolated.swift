import SwiftUI

// Hand-authored isolation scaffold for AppSettingsPanel — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=AppSettingsPanel; CODEYAM_ISOLATE_SCENARIO picks the case.
struct AppSettingsPanelIsolated: View {
    let scenario: String

    var body: some View {
        GeometryReader { proxy in
            content(availableHeight: proxy.size.height)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(CounterTheme.bg)
        .ignoresSafeArea()
    }

    // The App Settings scenarios exist to demonstrate sound/haptic state, so those
    // cases open SOUND & HAPTICS for the capture; `default`/`LeftHanded`
    // demonstrate the resting/handedness state and stay collapsed.
    @ViewBuilder private func content(availableHeight: CGFloat) -> some View {
        let expandFeedback = ["SoundAndHapticOn", "BothHapticsOff", "CustomPairing"].contains(scenario)
        AppSettingsPanel(settings: sampleSettings,
                         availableHeight: availableHeight,
                         initiallyExpandedFeedback: expandFeedback,
                         onOpenList: {}, onClose: {})
    }

    // A throwaway per-scenario UserDefaults suite so the toggles start in the
    // state the scenario is demonstrating without touching the shared domain.
    private var sampleSettings: AppSettings {
        let suite = UserDefaults(suiteName: "isolated-app-settings-\(scenario)")!
        let settings = AppSettings(defaults: suite)
        switch scenario {
        case "SoundAndHapticOn":
            // Sound on plus the distinct default haptic pairing (Sharp increment /
            // Soft decrement) — the new two-control layout.
            settings.soundOption = .ding
            settings.incrementHapticOption = .sharp
            settings.decrementHapticOption = .soft
        case "BothHapticsOff":
            // A user who wants no haptic feedback in either direction.
            settings.soundOption = .off
            settings.incrementHapticOption = .off
            settings.decrementHapticOption = .off
        case "CustomPairing":
            // The two directions freely and independently retuned to a custom
            // distinct pair (increment Double / decrement Buzz).
            settings.soundOption = .off
            settings.incrementHapticOption = .double
            settings.decrementHapticOption = .buzz
        case "LeftHanded":
            settings.defaultLeftHanded = true
        default:
            // The out-of-box defaults: sound off, haptics at the built-in Sharp /
            // Soft pairing (left untouched so the panel shows the real default).
            settings.soundOption = .off
            settings.defaultLeftHanded = false
        }
        return settings
    }
}
