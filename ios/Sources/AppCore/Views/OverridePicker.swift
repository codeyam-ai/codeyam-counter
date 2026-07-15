import SwiftUI

/// A "default-or-value" chooser for the per-counter settings panel: a leading
/// `DEFAULT` chip (meaning "follow the app-wide setting", i.e. `nil`) followed by
/// one chip per concrete option. The selected chip is filled with the accent so a
/// static simulator capture shows the current choice without a live tap. The chip
/// row scrolls horizontally so the wider SOUND/HAPTIC lists stay on one line while
/// the 3-chip HANDEDNESS row simply doesn't need to scroll.
///
/// Generic over any `Hashable` option; the caller supplies the label and an
/// `idPrefix` used for the row's and each chip's accessibility identifier
/// (`<idPrefix>` on the row, `<idPrefix>-default` and
/// `<idPrefix>-<label lowercased>` on the chips).
public struct OverridePicker<Option: Hashable>: View {
    let options: [Option]
    let optionLabel: (Option) -> String
    @Binding var selection: Option?
    let idPrefix: String

    public init(options: [Option],
                selection: Binding<Option?>,
                idPrefix: String,
                optionLabel: @escaping (Option) -> String) {
        self.options = options
        self._selection = selection
        self.idPrefix = idPrefix
        self.optionLabel = optionLabel
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("DEFAULT", selected: selection == nil, id: "\(idPrefix)-default") {
                    selection = nil
                }
                ForEach(options, id: \.self) { option in
                    chip(optionLabel(option),
                         selected: selection == option,
                         id: "\(idPrefix)-\(optionLabel(option).lowercased())") {
                        selection = option
                    }
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityIdentifier(idPrefix)
    }

    private func chip(_ text: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(selected ? CounterTheme.onAccent : CounterTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? CounterTheme.accent : CounterTheme.surface)
                .overlay(Rectangle().stroke(selected ? CounterTheme.accent : CounterTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
