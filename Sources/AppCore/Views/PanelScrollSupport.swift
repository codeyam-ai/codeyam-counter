import SwiftUI

/// A vertical scroll region that content-hugs up to `maxHeight`. It is only as
/// tall as its content (no empty scroll space below a short panel) until the
/// content exceeds `maxHeight`, at which point it stops growing and scrolls.
/// Pair it with a pinned header outside the scroll so the primary action stays
/// reachable even when the body scrolls.
///
/// The cap lives HERE, not on the enclosing card: a `.frame(maxHeight:)` on the
/// card is flexible, so it fills the whole proposal up to the max rather than
/// hugging, which is what left the panels reserving a screenful of empty space.
/// Bounding the scroll instead lets the card hug `header + scroll`.
struct BoundedScroll<Content: View>: View {
    /// The tallest the scroll region may grow before it starts scrolling.
    let maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                })
        }
        // Before the first measurement, fall back to the cap so the region is
        // bounded rather than greedily filling everything on the first pass.
        .frame(height: contentHeight == 0 ? maxHeight : min(contentHeight, maxHeight))
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

/// The collapsible disclosure header for a settings panel's feedback rows, plus
/// an optional caption describing what the section does. A chevron rotates from
/// pointing right (collapsed) to down (expanded); the whole row is tappable.
///
/// The caption sits tight under the header and stays visible whether the section
/// is open or closed, so the section's purpose is legible before it is opened.
struct FeedbackDisclosureToggle: View {
    @Binding var expanded: Bool
    let title: String
    let identifier: String
    /// Shown under the header when supplied. `nil` renders the header alone.
    let caption: String?

    init(expanded: Binding<Bool>, title: String, identifier: String, caption: String? = nil) {
        _expanded = expanded
        self.title = title
        self.identifier = identifier
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack {
                    Text(title)
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

            if let caption {
                Text(caption)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(CounterTheme.inkMuted)
                    .accessibilityIdentifier("\(identifier)-caption")
            }
        }
    }
}
