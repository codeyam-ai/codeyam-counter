import SwiftUI

/// A small secondary control in the bottom row (SUBTRACT / RESET / SWITCH):
/// a glyph above a mono label.
public struct ControlButton: View {
    let glyph: String
    let label: String
    let identifier: String
    let action: () -> Void

    public init(glyph: String, label: String, identifier: String, action: @escaping () -> Void) {
        self.glyph = glyph
        self.label = label
        self.identifier = identifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(glyph)
                    .font(.system(size: 18, weight: .heavy))
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(0.4)
            }
            .foregroundColor(CounterTheme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
