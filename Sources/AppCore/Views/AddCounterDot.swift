import SwiftUI

/// A muted "+" circle that sits at the end of the switcher's dot row. Tapping it
/// adds a new blank counter — the tap equivalent of swiping past the last
/// counter. Extracted from `CounterSwitcherCard` so the "add" affordance is its
/// own leaf beside `CounterDot`.
public struct AddCounterDot: View {
    let onAdd: () -> Void

    public init(onAdd: @escaping () -> Void) {
        self.onAdd = onAdd
    }

    public var body: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(CounterTheme.inkMuted)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(CounterTheme.lineStrong, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dot-add")
    }
}
