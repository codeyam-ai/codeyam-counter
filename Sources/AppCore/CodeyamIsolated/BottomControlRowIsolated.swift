import SwiftUI

// Hand-authored isolation scaffold for BottomControlRow — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=BottomControlRow; CODEYAM_ISOLATE_SCENARIO picks the case.
struct BottomControlRowIsolated: View {
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
        case "UndoPending":
            BottomControlRow(leftHanded: false, continuationWidth: 98, resetIsUndo: true,
                             graphOpen: false,
                             onSubtract: {}, onReset: {}, onGraph: {}, onIncrement: {})
                .frame(height: 96)
        case "GraphOpen":
            BottomControlRow(leftHanded: false, continuationWidth: 98, resetIsUndo: false,
                             graphOpen: true,
                             onSubtract: {}, onReset: {}, onGraph: {}, onIncrement: {})
                .frame(height: 96)
        default:
            BottomControlRow(leftHanded: false, continuationWidth: 98, resetIsUndo: false,
                             graphOpen: false,
                             onSubtract: {}, onReset: {}, onGraph: {}, onIncrement: {})
                .frame(height: 96)
        }
    }
}
