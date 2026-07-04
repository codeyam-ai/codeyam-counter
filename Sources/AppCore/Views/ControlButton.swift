import SwiftUI

/// A small secondary control in the bottom row (SUBTRACT / RESET / GRAPH):
/// an icon above a mono label. The icon is a text `glyph` by default, or an SF
/// Symbol when `systemImage` is supplied (used by GRAPH's chart icon).
public struct ControlButton: View {
    let glyph: String
    let systemImage: String?
    let label: String
    let identifier: String
    let action: () -> Void

    public init(glyph: String = "", systemImage: String? = nil, label: String, identifier: String, action: @escaping () -> Void) {
        self.glyph = glyph
        self.systemImage = systemImage
        self.label = label
        self.identifier = identifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Group {
                    if let systemImage {
                        Image(systemName: systemImage)
                    } else {
                        Text(glyph)
                    }
                }
                .font(.system(size: 18, weight: .heavy))
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(CounterTheme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
