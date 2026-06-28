import SwiftUI

/// The switcher card: the row of selectable counter dots (plus any ghost
/// restore slots), the active counter's name and the swipe hint, and the
/// settings gear that toggles the settings panel.
public struct CounterSwitcherCard: View {
    let counters: [Counter]
    let ghostSlots: [Counter]
    let activeId: Int
    let activeName: String
    let onSelect: (Int) -> Void
    let onRestore: (Int) -> Void
    let onGearTap: () -> Void

    public init(counters: [Counter],
                ghostSlots: [Counter],
                activeId: Int,
                activeName: String,
                onSelect: @escaping (Int) -> Void,
                onRestore: @escaping (Int) -> Void,
                onGearTap: @escaping () -> Void) {
        self.counters = counters
        self.ghostSlots = ghostSlots
        self.activeId = activeId
        self.activeName = activeName
        self.onSelect = onSelect
        self.onRestore = onRestore
        self.onGearTap = onGearTap
    }

    // Live counters and ghost slots merged into a single order-sorted row, so a
    // deleted default's empty circle sits where the counter used to be.
    private var slots: [(counter: Counter, isGhost: Bool)] {
        (counters.map { ($0, false) } + ghostSlots.map { ($0, true) })
            .sorted { $0.0.order < $1.0.order }
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                // Horizontal scroll so a large number of counters stays one row
                // and swipes through, instead of overflowing the card width.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(slots, id: \.counter.id) { slot in
                            if slot.isGhost {
                                CounterDot(color: .clear, isActive: false, isGhost: true,
                                           onTap: { onRestore(slot.counter.id) })
                                    .accessibilityIdentifier("dot-empty-\(slot.counter.id)")
                            } else {
                                CounterDot(
                                    color: CounterTheme.dotColor(slot.counter.colorKey),
                                    isActive: slot.counter.id == activeId,
                                    onTap: { onSelect(slot.counter.id) }
                                )
                                .accessibilityIdentifier("dot-\(slot.counter.id)")
                            }
                        }
                    }
                    // Breathing room so the active dot's ring + glow aren't
                    // clipped by the scroll viewport edges.
                    .padding(.vertical, 5)
                    .padding(.horizontal, 4)
                }
                Text(activeName)
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundColor(CounterTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("TAP A DOT OR SWIPE TO SWITCH")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(CounterTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GearButton(action: onGearTap)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .overlay(
            Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1)
        )
        .background(CounterTheme.panel)
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }
}
