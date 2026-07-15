import SwiftUI

/// A floating overlay showing a counter's activity: a step-line chart of the
/// running count over relative time plus a scrollable list of each event, with a
/// selector to page between the up-to-10 stored histories (runs between resets).
/// Reuses the same panel presentation as the settings panels; the overlay is
/// dismissed by reclicking the bottom row's CLOSE control (formerly GRAPH).
public struct CounterGraphView: View {
    let counterName: String
    let colorKey: String
    /// The counter's runs, oldest first. Empty when the counter has no activity.
    let histories: [CounterHistory]

    /// Index into `histories` of the run on screen; defaults to the current
    /// (last) run. Clamped on every read so it stays valid if the list is empty.
    @State private var index: Int

    public init(counterName: String, colorKey: String, histories: [CounterHistory]) {
        self.counterName = counterName
        self.colorKey = colorKey
        self.histories = histories
        _index = State(initialValue: max(0, histories.count - 1))
    }

    private var accent: Color {
        colorKey.isEmpty ? CounterTheme.accent : CounterTheme.dotColor(colorKey)
    }

    /// The run currently shown, or nil when the counter has never been changed.
    private var selected: CounterHistory? {
        guard histories.indices.contains(index) else { return histories.last }
        return histories[index]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GraphHeader(counterName: counterName)
            if histories.count > 1 {
                GraphHistorySelector(index: $index, count: histories.count)
            }
            chartSection
            if let history = selected {
                GraphEventList(history: history, accent: accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(CounterTheme.panel)
        .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    @ViewBuilder private var chartSection: some View {
        if let history = selected, !history.events.isEmpty {
            CounterGraphChart(history: history, accent: accent)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .background(CounterTheme.surface)
                .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
                .accessibilityIdentifier("graph-chart")
        } else {
            Text("NO ACTIVITY YET")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(CounterTheme.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(CounterTheme.surface)
                .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
                .accessibilityIdentifier("graph-empty")
        }
    }
}
