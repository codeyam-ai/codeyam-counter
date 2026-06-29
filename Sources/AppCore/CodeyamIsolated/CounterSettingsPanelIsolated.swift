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
            counter: Counter(id: 1, name: "PUSH-UPS", count: 12, colorKey: "lime", order: 0),
            onSave: { _, _, _, _ in }, onDelete: {}, onClose: {})
    }
}
