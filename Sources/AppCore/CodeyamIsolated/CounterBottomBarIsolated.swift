import SwiftUI

// Hand-authored isolation scaffold for CounterBottomBar — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterBottomBar; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterBottomBarIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        CounterBottomBar(leftHanded: false, screenHeight: 852, screenWidth: 393, resetIsUndo: false,
                         onIncrement: {}, onSubtract: {}, onReset: {}, onSwitch: {})
    }
}
