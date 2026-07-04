import SwiftUI

/// A simple scrollable list of every counter — colored dot + name + current
/// count — opened from the App Settings panel. Tapping a row selects that
/// counter and dismisses the list. Mirrors the panel chrome of
/// `CounterSettingsPanel`, and reuses `CounterTheme.dotColor` plus the blank-slot
/// em-dash / muted treatment from `CounterSwitcherCard`.
public struct CounterListPanel: View {
    let counters: [Counter]
    let activeId: Int
    let onSelect: (Int) -> Void
    let onClose: () -> Void

    public init(counters: [Counter],
                activeId: Int,
                onSelect: @escaping (Int) -> Void,
                onClose: @escaping () -> Void) {
        self.counters = counters
        self.activeId = activeId
        self.onSelect = onSelect
        self.onClose = onClose
    }

    private var sortedCounters: [Counter] {
        counters.sorted { $0.order < $1.order }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sortedCounters, id: \.id) { counter in
                        row(counter)
                        if counter.id != sortedCounters.last?.id {
                            Rectangle()
                                .fill(CounterTheme.line)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(CounterTheme.panel)
        .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private func row(_ counter: Counter) -> some View {
        let isBlank = counter.isBlank
        return Button(action: { onSelect(counter.id) }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isBlank ? CounterTheme.inkMuted : CounterTheme.dotColor(counter.colorKey))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(CounterTheme.accent, lineWidth: counter.id == activeId ? 2 : 0)
                            .padding(-3)
                    )
                Text(isBlank ? "—" : counter.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(isBlank ? CounterTheme.inkMuted : CounterTheme.ink)
                    .lineLimit(1)
                Spacer()
                Text("\(counter.count)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(CounterTheme.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // Leading inset so the active dot's ring (a stroke that overhangs the
            // dot frame) isn't clipped by the scroll viewport's edge.
            .padding(.leading, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("counter-list-row-\(counter.id)")
    }

    private var header: some View {
        HStack {
            Text("ALL COUNTERS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(CounterTheme.inkMuted)
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
            .accessibilityIdentifier("counter-list-close")
        }
    }
}
