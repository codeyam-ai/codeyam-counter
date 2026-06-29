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
        case "Ghost":
            CounterDot(color: CounterTheme.dotColor("lime"), isActive: false, isGhost: true, onTap: {})
                .frame(width: 64, height: 64)
        default:
            CounterDot(color: CounterTheme.dotColor("lime"), isActive: true, isGhost: false, onTap: {})
                .frame(width: 64, height: 64)
        }
    }
}
