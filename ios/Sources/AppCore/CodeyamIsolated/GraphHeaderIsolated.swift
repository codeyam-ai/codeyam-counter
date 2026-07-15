import SwiftUI

// Isolation scaffold for GraphHeader — renders the graph overlay's header
// standalone on the booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=GraphHeader; CODEYAM_ISOLATE_SCENARIO picks the case.
struct GraphHeaderIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CounterTheme.panel)
            .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "Blank":
            // A blank (unnamed) counter shows the em-dash placeholder name.
            GraphHeader(counterName: "—")
        default:
            GraphHeader(counterName: "PUSH-UPS")
        }
    }
}
