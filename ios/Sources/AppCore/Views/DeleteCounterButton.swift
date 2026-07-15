import SwiftUI

/// The destructive delete control in the counter settings panel, guarded by a
/// two-tap confirm. Disarmed it is an outlined coffee-colored "DELETE COUNTER";
/// the first tap arms it into a filled "TAP AGAIN TO CONFIRM" that auto-disarms
/// after ~3s, so an accidental single tap never wipes a counter. A second tap
/// while armed deletes. The `settings-delete` identifier stays on the button in
/// both states, so arming is a label/style swap rather than a new control.
public struct DeleteCounterButton: View {
    let onDelete: () -> Void

    /// Whether the button is armed and a second tap will delete.
    @State private var confirmingDelete: Bool

    /// `confirming` seeds the armed state so a scenario can capture it without a
    /// live tap; the app always starts disarmed.
    public init(onDelete: @escaping () -> Void, confirming: Bool = false) {
        self.onDelete = onDelete
        _confirmingDelete = State(initialValue: confirming)
    }

    public var body: some View {
        let coffee = CounterTheme.dotColor("coffee")
        return Button(action: {
            if confirmingDelete {
                onDelete()
            } else {
                confirmingDelete = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    confirmingDelete = false
                }
            }
        }) {
            Text(confirmingDelete ? "TAP AGAIN TO CONFIRM" : "DELETE COUNTER")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundColor(confirmingDelete ? CounterTheme.onAccent : coffee)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(confirmingDelete ? coffee : Color.clear)
                .overlay(Rectangle().stroke(coffee.opacity(confirmingDelete ? 1 : 0.6), lineWidth: 1))
                // A clear background is not hit-testable, so while disarmed only the
                // glyphs would take taps — claim the whole outlined frame instead.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-delete")
    }
}
