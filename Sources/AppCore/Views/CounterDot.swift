import SwiftUI

/// A single counter-selector dot. The active dot grows slightly and gains a
/// lime ring + glow. A ghost dot (a deleted default's empty slot) is an
/// outline-only circle that restores the default when tapped.
public struct CounterDot: View {
    let color: Color
    let isActive: Bool
    let isGhost: Bool
    let onTap: () -> Void

    public init(color: Color, isActive: Bool, isGhost: Bool = false, onTap: @escaping () -> Void) {
        self.color = color
        self.isActive = isActive
        self.isGhost = isGhost
        self.onTap = onTap
    }

    public var body: some View {
        if isGhost {
            Circle()
                .stroke(CounterTheme.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                .frame(width: 16, height: 16)
                .contentShape(Circle())
                .onTapGesture { onTap() }
        } else {
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
}
