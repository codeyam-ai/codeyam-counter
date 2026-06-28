import SwiftUI

/// The switcher card: the row of selectable counter dots, the active counter's
/// name and the swipe hint, plus the (inert) settings gear.
public struct CounterSwitcherCard: View {
    let counters: [Counter]
    let activeId: Int
    let activeName: String
    let onSelect: (Int) -> Void

    public init(counters: [Counter], activeId: Int, activeName: String, onSelect: @escaping (Int) -> Void) {
        self.counters = counters
        self.activeId = activeId
        self.activeName = activeName
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    ForEach(counters) { counter in
                        CounterDot(
                            color: CounterTheme.dotColor(counter.colorKey),
                            isActive: counter.id == activeId,
                            onTap: { onSelect(counter.id) }
                        )
                        .accessibilityIdentifier("dot-\(counter.id)")
                    }
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
            Spacer(minLength: 8)
            GearButton()
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
