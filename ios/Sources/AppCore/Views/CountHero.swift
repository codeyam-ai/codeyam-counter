import SwiftUI

/// The giant numeral showing the active counter's current value.
public struct CountHero: View {
    let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        HStack {
            Text("\(count)")
                .font(.system(size: 280, weight: .heavy))
                .tracking(-6)
                .foregroundColor(CounterTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("count-value")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(maxHeight: .infinity)
    }
}
