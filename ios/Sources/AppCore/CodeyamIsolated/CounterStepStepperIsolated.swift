import SwiftUI

// Hand-authored isolation scaffold for CounterStepStepper — renders the View standalone on the
// booted simulator against the app's dark theme. Selected by
// CODEYAM_ISOLATE_COMPONENT=CounterStepStepper; CODEYAM_ISOLATE_SCENARIO picks the case.
struct CounterStepStepperIsolated: View {
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
        case "StepFive":
            CounterStepStepper(step: .constant(5))
        default:
            CounterStepStepper(step: .constant(1))
        }
    }
}
