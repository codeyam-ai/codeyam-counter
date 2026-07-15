import SwiftUI

/// A labeled on/off row in a settings panel: a mono label on the left, the switch
/// pinned right. Used for ALLOW NEGATIVE.
///
/// The trailing inset is load-bearing, not decoration. iOS draws the switch knob
/// slightly past the control's layout bounds, so a switch sitting flush against
/// the enclosing scroll region's edge gets its knob sliced by the scroll's clip.
/// The inset keeps it clear of that boundary.
public struct SettingsToggleRow: View {
    let label: String
    let identifier: String
    @Binding var isOn: Bool

    public init(_ label: String, isOn: Binding<Bool>, identifier: String) {
        self.label = label
        self.identifier = identifier
        _isOn = isOn
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(CounterTheme.ink)
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(CounterTheme.accent)
                .accessibilityIdentifier(identifier)
                .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
