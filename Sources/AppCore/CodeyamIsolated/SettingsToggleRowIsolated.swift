import SwiftUI

// Hand-authored isolation scaffold for SettingsToggleRow — renders the labeled
// switch row standalone on the booted simulator against the app's dark theme.
// Selected by CODEYAM_ISOLATE_COMPONENT=SettingsToggleRow;
// CODEYAM_ISOLATE_SCENARIO picks the case.
//
// The row sits inside a height-bounded ScrollView inside a padded card ON PURPOSE:
// that is the exact context that used to slice the switch knob (iOS draws the knob
// past the control's layout bounds, so a switch flush against the scroll's clip
// edge gets cut). Capturing it inside the clip is what makes the scenario prove
// the fix rather than merely show a switch.
struct SettingsToggleRowIsolated: View {
    let scenario: String

    @State private var on = true
    @State private var off = false

    var body: some View {
        card
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    private var card: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
        }
        // Bounded, so the scroll clips exactly as it does inside a settings panel
        // instead of greedily filling the screen.
        .frame(height: 32)
        .padding(20)
        .background(CounterTheme.panel)
        .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "Off":
            SettingsToggleRow("ALLOW NEGATIVE", isOn: $off, identifier: "settings-allow-negative")
        default:
            SettingsToggleRow("ALLOW NEGATIVE", isOn: $on, identifier: "settings-allow-negative")
        }
    }
}
