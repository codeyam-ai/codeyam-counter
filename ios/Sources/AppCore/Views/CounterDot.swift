import SwiftUI

/// A single counter-selector dot. The active dot grows slightly and gains a
/// lime ring + glow. A blank slot (a deleted counter left in place) renders as
/// a dashed outline circle while empty, and as a solid neutral-fill dot once it
/// has been incremented; tapping either only selects it (no resurrection).
public struct CounterDot: View {
    let color: Color
    let isActive: Bool
    /// True for a blank slot: a deleted counter awaiting revival (no name).
    let isBlank: Bool
    /// True for a blank slot that is still at count 0 — drawn as the dashed
    /// outline. A blank slot with a non-zero count is drawn as a solid neutral
    /// dot instead.
    let isEmpty: Bool
    let onTap: () -> Void

    public init(color: Color, isActive: Bool, isBlank: Bool = false, isEmpty: Bool = false, onTap: @escaping () -> Void) {
        self.color = color
        self.isActive = isActive
        self.isBlank = isBlank
        self.isEmpty = isEmpty
        self.onTap = onTap
    }

    public var body: some View {
        if isBlank && isEmpty {
            // Blank + count 0 → the dashed outline circle. Even with no name it
            // still gains the solid accent ring + glow when active, so the user
            // can see which unnamed slot is selected.
            Circle()
                .stroke(CounterTheme.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(isActive ? CounterTheme.accent : Color.clear,
                                lineWidth: isActive ? 2 : 0)
                        .padding(isActive ? -3 : 0)
                )
                .shadow(color: isActive ? CounterTheme.accent.opacity(0.6) : .clear,
                        radius: isActive ? 8 : 0)
                .contentShape(Circle())
                .onTapGesture { onTap() }
        } else {
            // Blank + count ≠ 0 → a solid neutral (nameless) dot; otherwise the
            // counter's own color. Both reuse the active ring/glow overlay.
            Circle()
                .fill(isBlank ? CounterTheme.inkMuted : color)
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
