import SwiftUI

// Hand-authored isolation scaffold for CounterSwitcherCard — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterSwitcherCard; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterSwitcherCardIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        CounterSwitcherCard(
            counters: [
                Counter(id: 1, name: "PUSH-UPS", count: 12, colorKey: "lime", order: 0),
                Counter(id: 2, name: "COFFEE", count: 3, colorKey: "coffee", order: 1),
                Counter(id: 3, name: "STEPS", count: 840, colorKey: "steps", order: 2),
                Counter(id: 4, name: "BUGS", count: 0, colorKey: "bugs", order: 3),
            ],
            ghostSlots: [], activeId: 1, activeName: "PUSH-UPS",
            onSelect: { _ in }, onRestore: { _ in }, onGearTap: {})
    }
}
