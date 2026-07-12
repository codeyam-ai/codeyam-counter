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
        switch scenario {
        case "IncrementPressed":
            // The whole increment button pressed: both the top bar and the downward
            // extension dim together to the same shade, so the L-shape reads as one
            // surface.
            CounterBottomBar(leftHanded: false, screenHeight: 852, screenWidth: 393, resetIsUndo: false,
                             graphOpen: false,
                             onIncrement: {}, onSubtract: {}, onReset: {}, onGraph: {},
                             initiallyPressed: true)
        case "LeftHandedPressed":
            // Mirrored layout, pressed: the extension and top bar still dim in unison
            // on the opposite side.
            CounterBottomBar(leftHanded: true, screenHeight: 852, screenWidth: 393, resetIsUndo: false,
                             graphOpen: false,
                             onIncrement: {}, onSubtract: {}, onReset: {}, onGraph: {},
                             initiallyPressed: true)
        default:
            CounterBottomBar(leftHanded: false, screenHeight: 852, screenWidth: 393, resetIsUndo: false,
                             graphOpen: false,
                             onIncrement: {}, onSubtract: {}, onReset: {}, onGraph: {})
        }
    }
}
