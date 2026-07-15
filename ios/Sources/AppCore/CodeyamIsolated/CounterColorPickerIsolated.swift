import SwiftUI

// Hand-authored isolation scaffold for CounterColorPicker — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterColorPicker; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterColorPickerIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "Coffee":
            CounterColorPicker(selection: .constant("coffee"))
        default:
            CounterColorPicker(selection: .constant("lime"))
        }
    }
}
