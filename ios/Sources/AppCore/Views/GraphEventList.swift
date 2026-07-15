import SwiftUI

/// The graph overlay's most-recent-first list of a run's events: each row a
/// signed delta and the relative time since the run began. Extracted from
/// `CounterGraphView`; renders nothing when the run has no events.
public struct GraphEventList: View {
    /// The run whose events are listed.
    let history: CounterHistory
    /// The accent color used for positive deltas (the counter's dot color).
    let accent: Color

    public init(history: CounterHistory, accent: Color) {
        self.history = history
        self.accent = accent
    }

    @ViewBuilder public var body: some View {
        if !history.events.isEmpty {
            SettingsField("EVENTS") {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(history.events.enumerated()).reversed(), id: \.offset) { pair in
                            eventRow(index: pair.offset, event: pair.element)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func eventRow(index i: Int, event: CounterEvent) -> some View {
        let up = event.delta >= 0
        return HStack {
            Text(up ? "+\(event.delta)" : "\(event.delta)")
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundColor(up ? accent : CounterTheme.dotColor("coffee"))
            Spacer()
            Text(CounterGraphChart.relativeTime(history.relativeOffset(of: event)))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CounterTheme.inkMuted)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .overlay(Rectangle().fill(CounterTheme.line).frame(height: 1), alignment: .bottom)
        .accessibilityIdentifier("graph-event-row-\(i)")
    }
}
