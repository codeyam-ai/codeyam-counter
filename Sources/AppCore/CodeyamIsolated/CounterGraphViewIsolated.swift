import SwiftUI

// Hand-authored isolation scaffold for CounterGraphView — renders the overlay
// standalone on the booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterGraphView; CODEYAM_ISOLATE_SCENARIO picks the
// case. Histories are built in code (with fixed dates) so each state — rich
// chart, empty run, and multi-run paging — captures deterministically without a
// live event driver.
struct CounterGraphViewIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            // Keep the top safe-area inset (unlike the other isolated hosts) so the
            // panel sits BELOW the status bar, mirroring how the real app anchors
            // it under the header — otherwise the DONE button bleeds into the
            // status bar in the isolated capture.
            .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "empty":
            CounterGraphView(counterName: "COFFEE", colorKey: "coffee",
                             histories: [Self.emptyRun], onClose: {})
        case "paging":
            CounterGraphView(counterName: "STEPS", colorKey: "steps",
                             histories: Self.threeRuns, onClose: {})
        default:
            CounterGraphView(counterName: "PUSH-UPS", colorKey: "lime",
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

    /// A freshly reset run with no events yet — drives the placeholder.
    private static var emptyRun: CounterHistory {
        CounterHistory(startedAt: base, events: [])
    }

    /// Three stored runs so the selector can page (CURRENT / −1 / −2).
    private static var threeRuns: [CounterHistory] {
        [
            run(start: 0, deltas: [(20, 1), (55, 1), (90, -1)]),
            run(start: 400, deltas: [(15, 1), (40, 1), (70, 1), (110, 1)]),
            run(start: 900, deltas: [(25, 1), (60, -1), (95, 1)]),
        ]
    }
}
