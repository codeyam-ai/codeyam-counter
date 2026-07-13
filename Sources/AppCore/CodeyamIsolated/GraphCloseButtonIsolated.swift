import SwiftUI

// Hand-authored isolation scaffold for GraphCloseButton — renders the graph page's
// centered CLOSE pill standalone on the booted simulator against the app's dark
// theme. Selected by CODEYAM_ISOLATE_COMPONENT=GraphCloseButton;
// CODEYAM_ISOLATE_SCENARIO picks the case. The action is a no-op: there is no live
// tap driver in a static capture, so the button is shown, not driven.
struct GraphCloseButtonIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        GraphCloseButton(action: {})
    }
}
