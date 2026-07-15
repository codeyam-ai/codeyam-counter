import SwiftUI

/// The switcher card: the row of selectable counter dots (including any blank
/// slots), the active counter's name and the swipe hint, and the settings gear
/// that toggles the settings panel.
public struct CounterSwitcherCard: View {
    let counters: [Counter]
    let activeId: Int
    let activeName: String
    let onSelect: (Int) -> Void
    let onAdd: () -> Void
    let onGearTap: () -> Void

    public init(counters: [Counter],
                activeId: Int,
                activeName: String,
                onSelect: @escaping (Int) -> Void,
                onAdd: @escaping () -> Void,
                onGearTap: @escaping () -> Void) {
        self.counters = counters
        self.activeId = activeId
        self.activeName = activeName
        self.onSelect = onSelect
        self.onAdd = onAdd
        self.onGearTap = onGearTap
    }

    // Counters (live and blank) rendered in a single order-sorted row.
    private var sortedCounters: [Counter] {
        counters.sorted { $0.order < $1.order }
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                // Horizontal scroll so a large number of counters stays one row
                // and swipes through, instead of overflowing the card width.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(sortedCounters, id: \.id) { counter in
                            CounterDot(
                                color: counter.isBlank ? CounterTheme.inkMuted
                                                       : CounterTheme.dotColor(counter.colorKey),
                                isActive: counter.id == activeId,
                                isBlank: counter.isBlank,
                                isEmpty: counter.isBlank && counter.count == 0,
                                onTap: { onSelect(counter.id) }
                            )
                            .accessibilityIdentifier(
                                counter.isBlank && counter.count == 0
                                    ? "dot-empty-\(counter.id)"
                                    : "dot-\(counter.id)"
                            )
                        }
                        // Trailing "+" dot: appends a new blank counter and
                        // selects it — the tap equivalent of swiping past the end.
                        AddCounterDot(onAdd: onAdd)
                    }
                    // Breathing room so the active dot's ring + glow aren't
                    // clipped by the scroll viewport edges.
                    .padding(.vertical, 5)
                    .padding(.horizontal, 4)
                }
                // A blank active slot has no name — show a muted em-dash
                // placeholder instead of an empty label.
                Text(activeName.isEmpty ? "—" : activeName)
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundColor(activeName.isEmpty ? CounterTheme.inkMuted : CounterTheme.ink)
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
