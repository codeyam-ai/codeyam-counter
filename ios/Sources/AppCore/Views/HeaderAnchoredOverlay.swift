import SwiftUI

/// A floating panel anchored below the screen's fixed top chrome. The `anchor`
/// is a hidden, non-interactive copy of the header (and optionally the switcher)
/// that reserves exact-height space so the panel lands directly under it; the
/// panel content is drawn beneath the anchor, with a trailing spacer pushing
/// everything to the top. Extracted from `ContentView`, which repeated this same
/// VStack / hidden-spacer / hit-testing / fade-transition scaffold for each of
/// its overlays (settings, app settings, counter list, graph).
public struct HeaderAnchoredOverlay<Anchor: View, Content: View>: View {
    private let anchor: Anchor
    private let content: (CGFloat) -> Content

    /// Height-agnostic overlays (counter list, graph) that content-hug under the
    /// anchor and ignore how much room is left below it.
    public init(@ViewBuilder anchor: () -> Anchor, @ViewBuilder content: () -> Content) {
        self.anchor = anchor()
        let built = content()
        self.content = { _ in built }
    }

    /// Height-aware overlays (the settings panels) that need the room available
    /// below the anchor so they can cap a scrollable body against it. `content`
    /// receives the space between the anchor and the screen bottom.
    public init(@ViewBuilder anchor: () -> Anchor,
                @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.anchor = anchor()
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            anchor
            // The single flexible region below the anchor. Measuring it here (one
            // GeometryReader, with the top-align spacer inside) hands panels an
            // exact available height without a greedy reader competing with a
            // sibling Spacer in this VStack.
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    content(proxy.size.height)
                    Spacer(minLength: 0)
                }
            }
        }
        .allowsHitTesting(true)
        .transition(.opacity)
    }
}
