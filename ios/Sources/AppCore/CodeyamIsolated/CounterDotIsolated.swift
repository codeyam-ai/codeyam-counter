import SwiftUI

// Hand-authored isolation scaffold for CounterDot — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterDot; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterDotIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "Ghost", "Blank":
            // Blank + empty → the dashed outline slot.
            CounterDot(color: .clear, isActive: false, isBlank: true, isEmpty: true, onTap: {})
                .frame(width: 64, height: 64)
        case "SolidBlank":
            // Blank + incremented → the solid neutral dot.
            CounterDot(color: .clear, isActive: false, isBlank: true, isEmpty: false, onTap: {})
                .frame(width: 64, height: 64)
        default:
            CounterDot(color: CounterTheme.dotColor("lime"), isActive: true, onTap: {})
                .frame(width: 64, height: 64)
        }
    }
}
