import SwiftUI

// Hand-authored isolation scaffold for HeaderBar — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=HeaderBar; CODEYAM_ISOLATE_SCENARIO picks the case.
struct HeaderBarIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        HeaderBar(positionLabel: "01 / 04 COUNTERS")
    }
}
