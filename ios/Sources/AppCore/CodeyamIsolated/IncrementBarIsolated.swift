import SwiftUI

// Hand-authored isolation scaffold for IncrementBar — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=IncrementBar; CODEYAM_ISOLATE_SCENARIO picks the case.
struct IncrementBarIsolated: View {
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
        case "Pressed":
            // Shared pressed state forced on: the top face renders dimmed, matching
            // what the downward extension shows at the same moment.
            IncrementBar(leftHanded: false, plusColumnWidth: 98,
                         pressed: .constant(true), onIncrement: {})
                .frame(height: 150)
        default:
            IncrementBar(leftHanded: false, plusColumnWidth: 98, onIncrement: {})
                .frame(height: 150)
        }
    }
}
