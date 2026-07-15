import SwiftUI

/// The graph page's dismissal control: a centered CLOSE pill sitting directly
/// below the chart panel. The graph hides the whole bottom bar while it's open,
/// so this is the only way out of the graph — it replaces the bottom row's
/// former GRAPH→CLOSE toggle as the affordance the user actually reaches for.
public struct GraphCloseButton: View {
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                Text("CLOSE")
                    .font(.system(size: 12, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundColor(CounterTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CounterTheme.panel)
            .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        // Matches CounterGraphView's own horizontal inset so the pill aligns
        // flush under the chart panel above it.
        .padding(.horizontal, 22)
        .accessibilityIdentifier("graph-close")
    }
}
