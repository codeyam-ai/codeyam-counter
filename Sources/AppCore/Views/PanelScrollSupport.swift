import SwiftUI

/// A vertical scroll region that content-hugs up to a cap. On its own it is only
/// as tall as its content (no empty scroll space below a short panel); once its
/// parent bounds it to less than that — via a `.frame(maxHeight:)` on the panel —
/// it stops growing and scrolls instead. Pair it with a pinned header outside the
/// scroll so the primary action stays reachable even when the body scrolls.
struct BoundedScroll<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                })
        }
        // Cap the scroll at its own content height so a short panel stays compact
        // instead of the ScrollView greedily filling all offered space. A tall
        // panel is compressed by the parent's maxHeight and scrolls within it.
        .frame(maxHeight: contentHeight == 0 ? nil : contentHeight)
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
    }
}

/// Content height of a `BoundedScroll` body. Lives at file scope because a
/// generic type (`BoundedScroll<Content>`) cannot hold a static stored property.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The shared "FEEDBACK & OVERRIDES" disclosure header used by both settings
/// panels to collapse their sound/haptic/override rows. A chevron rotates from
/// pointing right (collapsed) to down (expanded); the whole row is tappable.
struct FeedbackDisclosureToggle: View {
    @Binding var expanded: Bool
    let identifier: String

    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
            HStack {
                Text("FEEDBACK & OVERRIDES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(CounterTheme.inkMuted)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(CounterTheme.inkMuted)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
