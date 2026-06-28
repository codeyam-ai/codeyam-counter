import SwiftUI

/// Inline settings panel that expands over the count numeral. Composes the
/// labeled name field, the color picker, the step stepper, an allow-negative
/// toggle, and a destructive Delete. Local @State holds the in-progress edits;
/// "DONE" saves.
public struct CounterSettingsPanel: View {
    let counter: Counter
    let onSave: (String, String, Bool, Int) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var name: String
    @State private var colorKey: String
    @State private var allowNegative: Bool
    @State private var step: Int

    public init(counter: Counter,
                onSave: @escaping (String, String, Bool, Int) -> Void,
                onDelete: @escaping () -> Void,
                onClose: @escaping () -> Void) {
        self.counter = counter
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _name = State(initialValue: counter.name)
        _colorKey = State(initialValue: counter.colorKey)
        _allowNegative = State(initialValue: counter.allowNegative)
        _step = State(initialValue: counter.step)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            SettingsField("NAME") {
                TextField("", text: $name)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(CounterTheme.ink)
                    .autocorrectionDisabled()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(CounterTheme.surface)
                    .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
                    .accessibilityIdentifier("settings-name")
            }

            SettingsField("COLOR") {
                CounterColorPicker(selection: $colorKey)
            }

            CounterStepStepper(step: $step)

            Toggle(isOn: $allowNegative) {
                Text("ALLOW NEGATIVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CounterTheme.ink)
            }
            .tint(CounterTheme.accent)
            .accessibilityIdentifier("settings-allow-negative")

            Button(action: { onDelete(); onClose() }) {
                Text("DELETE COUNTER")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(CounterTheme.dotColor("coffee"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(Rectangle().stroke(CounterTheme.dotColor("coffee").opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-delete")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(CounterTheme.panel)
        .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var header: some View {
        HStack {
            Text("SETTINGS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(CounterTheme.inkMuted)
            Spacer()
            Button(action: { onSave(name, colorKey, allowNegative, step); onClose() }) {
                Text("DONE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(CounterTheme.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CounterTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-close")
        }
    }
}
