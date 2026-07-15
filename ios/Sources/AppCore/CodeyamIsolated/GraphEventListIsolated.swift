import SwiftUI

// Isolation scaffold for GraphEventList — renders the graph overlay's event list
// standalone on the booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=GraphEventList; CODEYAM_ISOLATE_SCENARIO picks the
// case. The history is built in code with fixed dates so relative offsets (and
// the capture) are stable without a live event driver.
struct GraphEventListIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(CounterTheme.panel)
            .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        GraphEventList(history: Self.richRun, accent: CounterTheme.dotColor("lime"))
    }

    // A fixed base instant so relative offsets render deterministically.
    private static let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // A run of mixed up/down changes over a couple of minutes.
    private static var richRun: CounterHistory {
        CounterHistory(startedAt: base, events: [
            CounterEvent(at: base.addingTimeInterval(12), delta: 1),
            CounterEvent(at: base.addingTimeInterval(40), delta: 1),
            CounterEvent(at: base.addingTimeInterval(75), delta: -1),
            CounterEvent(at: base.addingTimeInterval(120), delta: 1),
            CounterEvent(at: base.addingTimeInterval(163), delta: 1),
        ])
    }
}
