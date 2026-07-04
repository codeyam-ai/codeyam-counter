import SwiftUI

// Hand-authored isolation scaffold for CounterListPanel — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterListPanel; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterListPanelIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        CounterListPanel(counters: sampleCounters, activeId: 1, onSelect: { _ in }, onClose: {})
    }

    private var sampleCounters: [Counter] {
        switch scenario {
        case "WithBlankSlot":
            return [
                Counter(id: 1, name: "PUSH-UPS", count: 7, colorKey: "lime", order: 0),
                Counter(id: 2, name: "COFFEE", count: 3, colorKey: "coffee", order: 1),
                Counter(id: 3, name: "", count: 0, colorKey: Counter.blankColorKey, order: 2),
                Counter(id: 4, name: "BUGS", count: 2, colorKey: "bugs", order: 3),
            ]
        default:
            return [
                Counter(id: 1, name: "PUSH-UPS", count: 7, colorKey: "lime", order: 0),
                Counter(id: 2, name: "COFFEE", count: 3, colorKey: "coffee", order: 1),
                Counter(id: 3, name: "STEPS", count: 8421, colorKey: "steps", order: 2),
                Counter(id: 4, name: "BUGS", count: 2, colorKey: "bugs", order: 3),
            ]
        }
    }
}
