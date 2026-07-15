import SwiftUI

// Hand-authored isolation scaffold for CounterSettingsPanel — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterSettingsPanel; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterSettingsPanelIsolated: View {
    let scenario: String

    var body: some View {
        GeometryReader { proxy in
            // Hand the panel the room left AFTER this scaffold's own inset (top +
            // bottom), so its content-hugging card caps inside the padded area
            // rather than overflowing it.
            content(availableHeight: proxy.size.height - 36)
                .padding(.horizontal, 12)
                .padding(.top, 24)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(CounterTheme.bg)
        .ignoresSafeArea()
    }

    @ViewBuilder private func content(availableHeight: CGFloat) -> some View {
        CounterSettingsPanel(
            counter: scenarioCounter,
            availableHeight: availableHeight,
            onSave: { _, _, _, _, _, _, _, _ in }, onDelete: {}, onClose: {})
    }

    /// The counter the panel edits, varied by scenario so a static capture can
    /// show the override rows in different states (all `Default`, or a specific
    /// pin) without a live tap.
    private var scenarioCounter: Counter {
        switch scenario {
        case "overrides-pinned":
            // Increment haptic pinned (Sharp) while the decrement haptic stays on
            // Default — shows the two haptic controls are independently overridable.
            return Counter(id: 1, name: "PUSH-UPS", count: 12, colorKey: "lime", order: 0,
                           handednessOverride: true, soundOverride: .off,
                           incrementHapticOverride: .sharp, decrementHapticOverride: nil)
        default:
            return Counter(id: 1, name: "PUSH-UPS", count: 12, colorKey: "lime", order: 0)
        }
    }
}
