import SwiftUI

/// The full-width top of the increment button. The "+" sits on this higher row,
/// vertically aligned with the label and on the opposite side of the screen from
/// it. Both flip with `leftHanded` so the "+" stays above the side the button
/// extends down on, and the "+" is centered in a column the same width as that
/// extension.
public struct IncrementBar: View {
    let leftHanded: Bool
    let plusColumnWidth: CGFloat
    let onIncrement: () -> Void

    public init(leftHanded: Bool, plusColumnWidth: CGFloat, onIncrement: @escaping () -> Void) {
        self.leftHanded = leftHanded
        self.plusColumnWidth = plusColumnWidth
        self.onIncrement = onIncrement
    }

    public var body: some View {
        Button(action: onIncrement) {
            HStack(spacing: 0) {
                if leftHanded {
                    plusColumn
                    labelArea
                } else {
                    labelArea
                    plusColumn
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("increment")
    }

    private var labelArea: some View {
        HStack(spacing: 0) {
            if leftHanded { Spacer(minLength: 0) }
            tapLabel
            if !leftHanded { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var plusColumn: some View {
        plusSign
            .frame(width: plusColumnWidth)
            .frame(maxHeight: .infinity)
    }

    private var tapLabel: some View {
        Text("TAP TO\nINCREMENT")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .multilineTextAlignment(leftHanded ? .trailing : .leading)
            .foregroundColor(CounterTheme.onAccent)
    }

    private var plusSign: some View {
        Text("+")
            .font(.system(size: 52, weight: .heavy))
            .foregroundColor(CounterTheme.onAccent)
    }
}
