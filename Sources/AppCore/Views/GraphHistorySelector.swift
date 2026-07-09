import SwiftUI

/// Prev/next paging across a counter's stored runs, with the recency label
/// ("CURRENT", "−1", "−2", …) between the arrows. Extracted from
/// `CounterGraphView`; drives the `index` binding it shares with the overlay.
public struct GraphHistorySelector: View {
    @Binding var index: Int
    /// Total number of stored runs — bounds the paging and the recency label.
    let count: Int

    public init(index: Binding<Int>, count: Int) {
        self._index = index
        self.count = count
    }

    /// How recent the shown run is: CURRENT for the newest, then −1, −2, … back
    /// through the stored runs.
    private var recencyLabel: String {
        let offset = count - 1 - index
        return offset <= 0 ? "CURRENT" : "−\(offset)"
    }

    public var body: some View {
        HStack(spacing: 12) {
            pageButton(glyph: "‹", identifier: "graph-history-prev", enabled: index > 0) {
                index = max(0, index - 1)
            }
            Text(recencyLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(CounterTheme.ink)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("graph-history-label")
            pageButton(glyph: "›", identifier: "graph-history-next", enabled: index < count - 1) {
                index = min(count - 1, index + 1)
            }
        }
    }

    private func pageButton(glyph: String, identifier: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(enabled ? CounterTheme.ink : CounterTheme.line)
                .frame(width: 44, height: 32)
                .background(CounterTheme.surface)
                .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }
}
