import SwiftUI

/// A grid of selectable color swatches drawn from `CounterTheme.palette`. The
/// selected key gets a lime ring. Binds the chosen `colorKey` back to the
/// settings panel.
public struct CounterColorPicker: View {
    @Binding var selection: String

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    public init(selection: Binding<String>) {
        self._selection = selection
    }

    public var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 14) {
            ForEach(CounterTheme.palette, id: \.self) { key in
                Circle()
                    .fill(CounterTheme.dotColor(key))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(CounterTheme.accent, lineWidth: selection == key ? 2 : 0)
                            .padding(-4)
                    )
                    .frame(maxWidth: .infinity)
                    .contentShape(Circle())
                    .onTapGesture { selection = key }
                    .accessibilityIdentifier("settings-color-\(key)")
            }
        }
    }
}
