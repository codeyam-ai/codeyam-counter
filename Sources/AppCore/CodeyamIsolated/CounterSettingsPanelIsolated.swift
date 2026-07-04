import SwiftUI

// Hand-authored isolation scaffold for CounterSettingsPanel — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterSettingsPanel; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterSettingsPanelIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        CounterSettingsPanel(
            counter: scenarioCounter,
            onSave: { _, _, _, _, _, _, _ in }, onDelete: {}, onClose: {})
    }

    /// The counter the panel edits, varied by scenario so a static capture can
    /// show the override rows in different states (all `Default`, or a specific
    /// pin) without a live tap.
    private var scenarioCounter: Counter {
        switch scenario {
        case "overrides-pinned":
            return Counter(id: 1, name: "PUSH-UPS", count: 12, colorKey: "lime", order: 0,
                           handednessOverride: true, soundOverride: .off, hapticOverride: .light)
        default:
            return Counter(id: 1, name: "PUSH-UPS", count: 12, colorKey: "lime", order: 0)
        }
    }
}
