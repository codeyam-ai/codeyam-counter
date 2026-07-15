import SwiftUI

// Isolation scaffold for AddCounterDot — renders the switcher's trailing "+" dot
// standalone on the booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=AddCounterDot; CODEYAM_ISOLATE_SCENARIO picks the case.
struct AddCounterDotIsolated: View {
    let scenario: String

    var body: some View {
        AddCounterDot(onAdd: {})
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }
}
