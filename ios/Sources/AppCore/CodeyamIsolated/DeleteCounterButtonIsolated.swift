import SwiftUI

// Hand-authored isolation scaffold for DeleteCounterButton — renders the View standalone
// on the booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=DeleteCounterButton; CODEYAM_ISOLATE_SCENARIO picks the case.
//
// The two cases are the button's two states: disarmed (outlined "DELETE COUNTER") and
// armed (filled "TAP AGAIN TO CONFIRM"). The armed state is seeded via `confirming`
// because a static capture cannot perform the first tap that arms it.
struct DeleteCounterButtonIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(CounterTheme.panel)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch scenario {
        case "Armed":
            DeleteCounterButton(onDelete: {}, confirming: true)
        default:
            DeleteCounterButton(onDelete: {})
        }
    }
}
