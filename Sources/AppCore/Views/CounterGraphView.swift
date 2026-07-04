import SwiftUI

/// A floating overlay showing a counter's activity: a step-line chart of the
/// running count over relative time plus a scrollable list of each event, with a
/// selector to page between the up-to-10 stored histories (runs between resets).
/// Reuses the same panel presentation as the settings panels (`DONE` closes).
public struct CounterGraphView: View {
    let counterName: String
    let colorKey: String
    /// The counter's runs, oldest first. Empty when the counter has no activity.
    let histories: [CounterHistory]
    let onClose: () -> Void

    /// Index into `histories` of the run on screen; defaults to the current
    /// (last) run. Clamped on every read so it stays valid if the list is empty.
    @State private var index: Int

    public init(counterName: String, colorKey: String, histories: [CounterHistory], onClose: @escaping () -> Void) {
        self.counterName = counterName
        self.colorKey = colorKey
        self.histories = histories
        self.onClose = onClose
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

    /// How recent the shown run is: CURRENT for the newest, then −1, −2, … back
    /// through the stored runs.
    private var recencyLabel: String {
        let offset = histories.count - 1 - index
        return offset <= 0 ? "CURRENT" : "−\(offset)"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if histories.count > 1 { historySelector }
            chartSection
            eventList
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(CounterTheme.panel)
        .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var header: some View {
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
            Button(action: onClose) {
                Text("DONE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(CounterTheme.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CounterTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("graph-close")
        }
    }

    // Prev/next paging across the stored runs, with the recency label between.
    private var historySelector: some View {
        HStack(spacing: 12) {
            pageButton(glyph: "‹", identifier: "graph-history-prev", enabled: index > 0) {
                index = max(0, index - 1)
            }
            Text(recencyLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(CounterTheme.ink)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("graph-history-label")
            pageButton(glyph: "›", identifier: "graph-history-next", enabled: index < histories.count - 1) {
                index = min(histories.count - 1, index + 1)
            }
        }
    }

    private func pageButton(glyph: String, identifier: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(enabled ? CounterTheme.ink : CounterTheme.line)
                .frame(width: 44, height: 32)
                .background(CounterTheme.surface)
                .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
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

    // Most-recent-first list of the selected run's events: a signed delta and the
    // relative time since the run began.
    @ViewBuilder private var eventList: some View {
        let events = selected?.events ?? []
        if !events.isEmpty, let history = selected {
            SettingsField("EVENTS") {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()).reversed(), id: \.offset) { pair in
                            eventRow(index: pair.offset, event: pair.element, history: history)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func eventRow(index i: Int, event: CounterEvent, history: CounterHistory) -> some View {
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
