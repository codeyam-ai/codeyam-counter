import SwiftUI

/// A single counter-selector dot. The active dot grows slightly and gains a
/// lime ring + glow.
public struct CounterDot: View {
    let color: Color
    let isActive: Bool
    let onTap: () -> Void

    public init(color: Color, isActive: Bool, onTap: @escaping () -> Void) {
        self.color = color
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: isActive ? 18 : 16, height: isActive ? 18 : 16)
            .overlay(
                Circle()
                    .stroke(isActive ? CounterTheme.accent : Color.white.opacity(0.18),
                            lineWidth: isActive ? 2 : 1)
                    .padding(isActive ? -3 : 0)
            )
            .shadow(color: isActive ? CounterTheme.accent.opacity(0.6) : .clear,
                    radius: isActive ? 8 : 0)
            .contentShape(Circle())
            .onTapGesture { onTap() }
    }
}
