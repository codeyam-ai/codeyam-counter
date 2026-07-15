import SwiftUI

// Isolation scaffold for GraphHistorySelector — renders the run pager standalone
// on the booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=GraphHistorySelector; CODEYAM_ISOLATE_SCENARIO picks
// the case. The index is a constant binding since an isolated capture is static.
struct GraphHistorySelectorIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(CounterTheme.panel)
            .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "Older":
            // Paged back to the oldest of three runs: prev disabled, label −2.
            GraphHistorySelector(index: .constant(0), count: 3)
        default:
            // On the current (newest) of three runs: next disabled, label CURRENT.
            GraphHistorySelector(index: .constant(2), count: 3)
        }
    }
}
