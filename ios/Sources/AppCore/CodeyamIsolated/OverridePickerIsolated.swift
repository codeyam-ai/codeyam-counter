import SwiftUI

// Hand-authored isolation scaffold for OverridePicker — renders the generic
// "default-or-value" chip row standalone on the booted simulator against the
// app's dark theme. `editor isolate` can't auto-seed its generic `[Option]`
// prop, so the cases are pinned by hand. Selected by
// CODEYAM_ISOLATE_COMPONENT=OverridePicker; CODEYAM_ISOLATE_SCENARIO picks the case.
struct OverridePickerIsolated: View {
    let scenario: String

    var body: some View {
        content
            .padding(.horizontal, 24)
            .padding(.top, 80)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CounterTheme.bg)
            .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        // A pinned case selects a concrete value on each row; the default case
        // leaves every row on DEFAULT (nil). Shown across all three option types
        // (Bool handedness, SoundOption, HapticOption) to exercise the generic.
        let pinned = scenario == "Pinned"
        VStack(alignment: .leading, spacing: 18) {
            row("HANDEDNESS",
                OverridePicker(options: [true, false],
                               selection: .constant(pinned ? Bool?.some(true) : Bool?.none),
                               idPrefix: "iso-handedness",
                               optionLabel: { $0 ? "LEFT" : "RIGHT" }))
            row("SOUND",
                OverridePicker(options: SoundOption.allCases,
                               selection: .constant(pinned ? SoundOption?.some(.off) : SoundOption?.none),
                               idPrefix: "iso-sound",
                               optionLabel: { $0.label }))
            row("HAPTIC",
                OverridePicker(options: HapticOption.allCases,
                               selection: .constant(pinned ? HapticOption?.some(.sharp) : HapticOption?.none),
                               idPrefix: "iso-haptic",
                               optionLabel: { $0.label }))
        }
    }

    private func row(_ title: String, _ picker: some View) -> some View {
        SettingsField(title) { picker }
    }
}
