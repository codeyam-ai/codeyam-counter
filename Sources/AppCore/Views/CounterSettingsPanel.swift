import SwiftUI

/// Inline settings panel that expands over the count numeral. Composes the
/// labeled name field, the color picker, the step stepper, an allow-negative
/// toggle, and a destructive Delete. Local @State holds the in-progress edits;
/// "DONE" saves.
public struct CounterSettingsPanel: View {
    let counter: Counter
    /// Room available below the anchoring header, supplied by `HeaderAnchoredOverlay`.
    /// The field body scrolls within this bound so a fully expanded panel can never
    /// run off the bottom of the screen and the pinned DONE stays reachable.
    let availableHeight: CGFloat
    let onSave: (String, String, Bool, Int, Bool?, SoundOption?, HapticOption?, HapticOption?) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var name: String
    @State private var colorKey: String
    @State private var allowNegative: Bool
    @State private var step: Int
    /// The per-counter overrides, each `nil` while the counter follows the app
    /// default. The two haptic directions are independent. Seeded from the counter
    /// and passed back on DONE.
    @State private var handednessOverride: Bool?
    @State private var soundOverride: SoundOption?
    @State private var incrementHapticOverride: HapticOption?
    @State private var decrementHapticOverride: HapticOption?
    /// Whether the FEEDBACK & HANDEDNESS section is expanded. Seeded open when the
    /// counter already pins any override so a user who set them sees them right
    /// away; collapsed otherwise so the resting panel stays short.
    @State private var showFeedback: Bool
    /// Two-tap delete guard: the first tap arms the button, a second tap within
    /// ~3s deletes; it auto-disarms so an accidental single tap never wipes a
    /// counter.
    @State private var confirmingDelete = false

    public init(counter: Counter,
                availableHeight: CGFloat,
                onSave: @escaping (String, String, Bool, Int, Bool?, SoundOption?, HapticOption?, HapticOption?) -> Void,
                onDelete: @escaping () -> Void,
                onClose: @escaping () -> Void) {
        self.counter = counter
        self.availableHeight = availableHeight
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _name = State(initialValue: counter.name)
        // A blank slot has no color yet — default the picker to the first palette
        // swatch so saving with a name produces a normal colored counter. The
        // name stays empty, so saving without one leaves the slot blank.
        _colorKey = State(initialValue: counter.isBlank
            ? (CounterTheme.palette.first ?? "lime")
            : counter.colorKey)
        _allowNegative = State(initialValue: counter.allowNegative)
        _step = State(initialValue: counter.step)
        _handednessOverride = State(initialValue: counter.handednessOverride)
        _soundOverride = State(initialValue: counter.soundOverride)
        _incrementHapticOverride = State(initialValue: counter.incrementHapticOverride)
        _decrementHapticOverride = State(initialValue: counter.decrementHapticOverride)
        _showFeedback = State(initialValue: counter.hasFeedbackOverride)
    }

    public var body: some View {
        // Cap the panel card to the room below the anchor, less the top inset,
        // the card's own vertical padding, and a bottom breathing margin — so the
        // whole panel (chrome included) fits on screen and the body scrolls.
        let maxCardHeight = max(160, availableHeight - 12 - 40 - 24)

        return VStack(alignment: .leading, spacing: 18) {
            header

            BoundedScroll {
                VStack(alignment: .leading, spacing: 18) {
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

                    FeedbackDisclosureToggle(expanded: $showFeedback,
                                             title: "FEEDBACK & HANDEDNESS",
                                             identifier: "settings-feedback-toggle")

                    if showFeedback {
                        SettingsField("HANDEDNESS") {
                            OverridePicker(options: [true, false],
                                           selection: $handednessOverride,
                                           idPrefix: "settings-handedness",
                                           optionLabel: { $0 ? "LEFT" : "RIGHT" })
                        }

                        SettingsField("SOUND") {
                            OverridePicker(options: SoundOption.allCases,
                                           selection: $soundOverride,
                                           idPrefix: "settings-sound",
                                           optionLabel: { $0.label })
                        }

                        SettingsField("INCREMENT HAPTIC") {
                            OverridePicker(options: HapticOption.allCases,
                                           selection: $incrementHapticOverride,
                                           idPrefix: "settings-increment-haptic",
                                           optionLabel: { $0.label })
                        }

                        SettingsField("DECREMENT HAPTIC") {
                            OverridePicker(options: HapticOption.allCases,
                                           selection: $decrementHapticOverride,
                                           idPrefix: "settings-decrement-haptic",
                                           optionLabel: { $0.label })
                        }
                    }

                    deleteButton
                }
            }
        }
        .frame(maxHeight: maxCardHeight, alignment: .top)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(CounterTheme.panel)
        .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    // The delete control. Disarmed: an outlined coffee-colored "DELETE COUNTER".
    // First tap arms it into a filled "TAP AGAIN TO CONFIRM" state that
    // auto-disarms after ~3s; a second tap while armed performs the delete. The
    // `settings-delete` identifier stays on the button in both states so the
    // armed state is a label/style swap rather than a new control.
    private var deleteButton: some View {
        let coffee = CounterTheme.dotColor("coffee")
        return Button(action: {
            if confirmingDelete {
                onDelete()
                onClose()
            } else {
                confirmingDelete = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    confirmingDelete = false
                }
            }
        }) {
            Text(confirmingDelete ? "TAP AGAIN TO CONFIRM" : "DELETE COUNTER")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundColor(confirmingDelete ? CounterTheme.onAccent : coffee)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(confirmingDelete ? coffee : Color.clear)
                .overlay(Rectangle().stroke(coffee.opacity(confirmingDelete ? 1 : 0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-delete")
    }

    private var header: some View {
        HStack {
            Text("SETTINGS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(CounterTheme.inkMuted)
            Spacer()
            Button(action: {
                onSave(name, colorKey, allowNegative, step,
                       handednessOverride, soundOverride,
                       incrementHapticOverride, decrementHapticOverride)
                onClose()
            }) {
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
