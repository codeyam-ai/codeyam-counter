import SwiftUI

/// A labeled section in the settings panel: a small mono caption above its
/// content. Used by the name field and the color picker so their headings
/// stay visually consistent.
public struct SettingsField<Content: View>: View {
    let title: String
    let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(CounterTheme.inkMuted)
            content
        }
    }
}
