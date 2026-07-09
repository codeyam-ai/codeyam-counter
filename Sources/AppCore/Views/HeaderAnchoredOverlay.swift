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
    private let content: Content

    public init(@ViewBuilder anchor: () -> Anchor, @ViewBuilder content: () -> Content) {
        self.anchor = anchor()
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            anchor
            content
            Spacer(minLength: 0)
        }
        .allowsHitTesting(true)
        .transition(.opacity)
    }
}
