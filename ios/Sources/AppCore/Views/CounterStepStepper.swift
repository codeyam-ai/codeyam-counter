import SwiftUI

/// The "COUNT BY" control: a −/value/+ stepper that sets how much each
/// increment or subtract changes the count. Clamps the lower bound at 1.
public struct CounterStepStepper: View {
    @Binding var step: Int

    public init(step: Binding<Int>) {
        self._step = step
    }

    public var body: some View {
        HStack {
            Text("COUNT BY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(CounterTheme.inkMuted)
            Spacer()
            HStack(spacing: 0) {
                button("\u{2212}") { step = max(1, step - 1) }
                    .accessibilityIdentifier("settings-step-decr")
                Text("\(step)")
                    .font(.system(size: 17, weight: .heavy, design: .monospaced))
                    .foregroundColor(CounterTheme.ink)
                    .frame(width: 48)
                    .accessibilityIdentifier("settings-step")
                button("+") { step += 1 }
                    .accessibilityIdentifier("settings-step-incr")
            }
            .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
        }
    }

    private func button(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(CounterTheme.ink)
                .frame(width: 42, height: 42)
                .background(CounterTheme.surface)
        }
        .buttonStyle(.plain)
    }
}
