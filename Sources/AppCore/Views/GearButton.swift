import SwiftUI

/// The settings gear on the switcher card. Tapping it toggles the inline
/// settings panel that expands over the count.
public struct GearButton: View {
    let action: () -> Void

    public init(action: @escaping () -> Void = {}) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15))
                .foregroundColor(CounterTheme.ink)
                .frame(width: 36, height: 36)
                .background(CounterTheme.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("gear")
    }
}
