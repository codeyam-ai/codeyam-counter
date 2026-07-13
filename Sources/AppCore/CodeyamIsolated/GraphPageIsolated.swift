import SwiftUI

// Hand-authored isolation scaffold for GraphPage — renders the whole graph surface
// (chart panel + its centered CLOSE button) standalone on the booted simulator.
// Selected by CODEYAM_ISOLATE_COMPONENT=GraphPage; CODEYAM_ISOLATE_SCENARIO picks
// the case. Histories are built in code with fixed dates so each state captures
// deterministically without a live event driver, mirroring CounterGraphViewIsolated.
struct GraphPageIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            // Keep the top safe-area inset so the panel sits BELOW the status bar,
            // mirroring how the real app anchors it under the header.
            .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "empty":
            GraphPage(counterName: "COFFEE", colorKey: "coffee",
                      histories: [Self.emptyRun], onClose: {})
        default:
            GraphPage(counterName: "PUSH-UPS", colorKey: "lime",
                      histories: [Self.richRun], onClose: {})
        }
    }

    // A fixed base instant so relative offsets (and the capture) are stable.
    private static let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func run(start: TimeInterval, deltas: [(TimeInterval, Int)]) -> CounterHistory {
        CounterHistory(startedAt: base.addingTimeInterval(start),
                       events: deltas.map { CounterEvent(at: base.addingTimeInterval(start + $0.0), delta: $0.1) })
    }

    /// A single rich run of mixed up/down changes over a few minutes.
    private static var richRun: CounterHistory {
        run(start: 0, deltas: [
            (12, 1), (30, 1), (47, 1), (65, -1), (88, 1),
            (120, 1), (146, 1), (175, -1), (210, 1), (238, 1), (262, 1),
        ])
    }

    /// A freshly reset run with no events yet — drives the NO ACTIVITY placeholder.
    private static var emptyRun: CounterHistory {
        CounterHistory(startedAt: base, events: [])
    }
}
