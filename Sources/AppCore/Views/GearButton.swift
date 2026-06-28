import SwiftUI

/// The settings gear on the switcher card. Settings are deferred, so the gear is
/// shown but inert for now.
public struct GearButton: View {
    public init() {}

    public var body: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 15))
            .foregroundColor(CounterTheme.ink)
            .frame(width: 36, height: 36)
            .background(CounterTheme.surface)
            .clipShape(Circle())
            .overlay(Circle().stroke(CounterTheme.lineStrong, lineWidth: 1))
            .accessibilityIdentifier("gear")
    }
}
