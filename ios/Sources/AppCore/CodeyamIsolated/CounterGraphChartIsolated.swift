import SwiftUI

// Hand-authored isolation scaffold for CounterGraphChart — renders the step-line
// chart standalone on the booted simulator against the app's dark theme. Selected
// by CODEYAM_ISOLATE_COMPONENT=CounterGraphChart; CODEYAM_ISOLATE_SCENARIO picks
// the case. Histories are built in code (with fixed dates) so the labeled axes and
// markers capture deterministically without a live event driver.
struct CounterGraphChartIsolated: View {
    let scenario: String

    var body: some View {
        content
            .frame(height: 200)
            .padding(20)
            .background(CounterTheme.surface)
            .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "negative":
            CounterGraphChart(history: Self.negativeRun, accent: CounterTheme.dotColor("steps"))
        default:
            CounterGraphChart(history: Self.mixedRun, accent: CounterTheme.dotColor("lime"))
        }
    }

    private static let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func run(_ deltas: [(TimeInterval, Int)]) -> CounterHistory {
        CounterHistory(startedAt: base,
                       events: deltas.map { CounterEvent(at: base.addingTimeInterval($0.0), delta: $0.1) })
    }

    /// A run that only climbs and dips slightly — y axis spans 0…max.
    private static var mixedRun: CounterHistory {
        run([(12, 1), (30, 1), (47, 1), (65, -1), (88, 1), (120, 1), (146, 1), (175, -1), (210, 1), (238, 1), (262, 1)])
    }

    /// A run that dips below zero — the y axis labels the negative range and the
    /// dashed zero line sits between the extremes.
    private static var negativeRun: CounterHistory {
        run([(15, -1), (40, -1), (70, 1), (100, 1), (130, 1), (165, -1), (200, 1)])
    }
}
