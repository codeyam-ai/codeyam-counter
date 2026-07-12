import SwiftUI

// Isolation scaffold for FeedbackDisclosureToggle — codeyam renders this View standalone on the
// booted iOS simulator. CODEYAM_ISOLATE_COMPONENT=FeedbackDisclosureToggle selects this struct in
// CodeyamIsolationHost.swift; CODEYAM_ISOLATE_SCENARIO picks the scenario below.
//
// The toggle is the shared FEEDBACK & OVERRIDES disclosure header; its state is a
// constant binding here (isolated rendering is about appearance, not the tap). The
// Expanded scenario also shows the rows the header reveals in real use, so the two
// states read as distinctly as they do in the panel — a header alone vs. a header
// over its disclosed section.
struct FeedbackDisclosureToggleIsolated: View {
    let scenario: String

    private var expanded: Bool { scenario == "Expanded" }

    var body: some View {
        ZStack(alignment: .top) {
            CounterTheme.panel.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                FeedbackDisclosureToggle(expanded: .constant(expanded),
                                         identifier: "isolated-feedback-toggle")
                if expanded {
                    revealedRows
                }
            }
            .padding(20)
            .padding(.top, 60)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    // A stand-in for the sound/haptic/override rows the header discloses, so the
    // Expanded capture shows the section open rather than a lone chevron flip.
    private var revealedRows: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(["SOUND", "INCREMENT HAPTIC", "DECREMENT HAPTIC"], id: \.self) { label in
                VStack(alignment: .leading, spacing: 7) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(CounterTheme.inkMuted)
                    Text("DEFAULT")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(CounterTheme.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(CounterTheme.accent)
                }
            }
        }
    }
}
