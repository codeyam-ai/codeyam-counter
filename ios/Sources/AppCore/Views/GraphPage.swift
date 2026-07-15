import SwiftUI

/// The graph surface as a whole page: the activity chart stacked above its own
/// centered CLOSE button. While this is up `ContentView` hides the count hero
/// and the entire bottom control assembly, so these two are the only things on
/// screen below the header — and the close button is the only way back.
public struct GraphPage: View {
    let counterName: String
    let colorKey: String
    let histories: [CounterHistory]
    let onClose: () -> Void

    public init(counterName: String, colorKey: String, histories: [CounterHistory],
                onClose: @escaping () -> Void) {
        self.counterName = counterName
        self.colorKey = colorKey
        self.histories = histories
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 16) {
            CounterGraphView(counterName: counterName, colorKey: colorKey, histories: histories)
            GraphCloseButton(action: onClose)
        }
    }
}
