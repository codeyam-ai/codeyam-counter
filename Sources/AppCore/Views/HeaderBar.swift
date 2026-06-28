import SwiftUI

/// Top app-chrome row: the brand name and the "NN / 04 COUNTERS" position label.
public struct HeaderBar: View {
    let positionLabel: String

    public init(positionLabel: String) {
        self.positionLabel = positionLabel
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("CODEYAM COUNTER")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CounterTheme.ink)
            Spacer()
            Text("\(positionLabel) COUNTERS")
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.6)
                .foregroundColor(CounterTheme.inkMuted)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }
}
