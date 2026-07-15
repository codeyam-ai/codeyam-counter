import SwiftUI

/// The graph overlay's header: the small "GRAPH" caption above the active
/// counter's name. Extracted from `CounterGraphView` so the overlay body is pure
/// composition of its distinct sections.
public struct GraphHeader: View {
    let counterName: String

    public init(counterName: String) {
        self.counterName = counterName
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GRAPH")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(CounterTheme.inkMuted)
                Text(counterName)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(CounterTheme.ink)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}
