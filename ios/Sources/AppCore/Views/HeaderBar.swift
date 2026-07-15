import SwiftUI

/// Top app-chrome row: the brand name and the app-settings button that opens the
/// system-wide App Settings panel. (The passive "NN / 04 COUNTERS" position
/// label this button replaced lived here previously.)
public struct HeaderBar: View {
    let onSettingsTap: () -> Void

    public init(onSettingsTap: @escaping () -> Void = {}) {
        self.onSettingsTap = onSettingsTap
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text("CODEYAM COUNTER")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CounterTheme.ink)
            Spacer()
            // Distinct from the per-counter gear on the switcher card: a sliders
            // glyph and the `app-settings` identifier so the two entry points
            // don't collide. Styling mirrors `GearButton`.
            Button(action: onSettingsTap) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15))
                    .foregroundColor(CounterTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(CounterTheme.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(CounterTheme.lineStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("app-settings")
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }
}
