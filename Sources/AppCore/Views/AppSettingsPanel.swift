import SwiftUI

/// The system-wide App Settings panel. Mirrors `CounterSettingsPanel`'s
/// floating-overlay chrome (anchored under the header, drawn on top, `DONE` to
/// close) and reuses `SettingsField` + `CounterTheme` tokens so it feels native.
///
/// Bound directly to the shared `AppSettings` store, so each control writes
/// straight through to the persisted default. Holds no local edit state: unlike
/// the per-counter panel there is no save/cancel — toggling is immediate.
public struct AppSettingsPanel: View {
    @ObservedObject var settings: AppSettings
    /// Room available below the anchoring header, supplied by `HeaderAnchoredOverlay`.
    /// The field body scrolls within this bound so the pinned DONE stays reachable.
    let availableHeight: CGFloat
    let onOpenList: () -> Void
    let onClose: () -> Void
    /// Whether the SOUND & HAPTICS section starts expanded. App Settings has
    /// no per-counter override state to key off, so it collapses by default in
    /// production; feedback-focused isolated scenarios opt specific cases open.
    @State private var showFeedback: Bool

    public init(settings: AppSettings,
                availableHeight: CGFloat,
                initiallyExpandedFeedback: Bool = false,
                onOpenList: @escaping () -> Void,
                onClose: @escaping () -> Void) {
        self.settings = settings
        self.availableHeight = availableHeight
        self.onOpenList = onOpenList
        self.onClose = onClose
        _showFeedback = State(initialValue: initiallyExpandedFeedback)
    }

    public var body: some View {
        // Cap the card to the room below the anchor, less the top inset, the
        // card's own vertical padding, and a bottom breathing margin.
        let maxCardHeight = max(160, availableHeight - 12 - 40 - 24)

        return VStack(alignment: .leading, spacing: 18) {
            header

            BoundedScroll {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsField("HANDEDNESS") {
                        handednessControl
                    }

                    FeedbackDisclosureToggle(expanded: $showFeedback,
                                             title: "SOUND & HAPTICS",
                                             identifier: "app-settings-feedback-toggle")

                    if showFeedback {
                        SettingsField("SOUND ON CHANGE") {
                            optionPicker(options: SoundOption.allCases,
                                         selected: settings.soundOption,
                                         label: { $0.label },
                                         onSelect: { settings.soundOption = $0 },
                                         id: "app-settings-sound")
                        }

                        SettingsField("INCREMENT HAPTIC") {
                            optionPicker(options: HapticOption.allCases,
                                         selected: settings.incrementHapticOption,
                                         label: { $0.label },
                                         onSelect: { settings.incrementHapticOption = $0 },
                                         id: "app-settings-increment-haptic")
                        }

                        SettingsField("DECREMENT HAPTIC") {
                            optionPicker(options: HapticOption.allCases,
                                         selected: settings.decrementHapticOption,
                                         label: { $0.label },
                                         onSelect: { settings.decrementHapticOption = $0 },
                                         id: "app-settings-decrement-haptic")
                        }
                    }

                    allCountersButton
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

    // A horizontally-scrolling row of selectable pills — one per option — with
    // the active one filled in the accent color. Reused for both the sound and
    // haptic choices; scrolls when the options overflow the panel width.
    private func optionPicker<T: Hashable>(options: [T],
                                           selected: T,
                                           label: @escaping (T) -> String,
                                           onSelect: @escaping (T) -> Void,
                                           id: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = option == selected
                        Button(action: { onSelect(option) }) {
                            Text(label(option))
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(isSelected ? CounterTheme.onAccent : CounterTheme.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(isSelected ? CounterTheme.accent : Color.clear)
                                .overlay(Rectangle().stroke(isSelected ? CounterTheme.accent : CounterTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(option)
                        .accessibilityIdentifier("\(id)-\(label(option).lowercased())")
                    }
                }
                .padding(.vertical, 2)
            }
            // Keep the active option visible even when it sits past the fold —
            // otherwise a selection like the last sound reads as "nothing chosen".
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
        .accessibilityIdentifier(id)
    }

    // A two-way segmented Left / Right control writing `defaultLeftHanded`.
    private var handednessControl: some View {
        HStack(spacing: 0) {
            handednessOption(label: "LEFT", isLeft: true)
            handednessOption(label: "RIGHT", isLeft: false)
        }
        .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
        .accessibilityIdentifier("app-settings-handedness")
    }

    private func handednessOption(label: String, isLeft: Bool) -> some View {
        let selected = settings.defaultLeftHanded == isLeft
        return Button(action: { settings.defaultLeftHanded = isLeft }) {
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundColor(selected ? CounterTheme.onAccent : CounterTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? CounterTheme.accent : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var allCountersButton: some View {
        Button(action: onOpenList) {
            HStack {
                Text("ALL COUNTERS")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(CounterTheme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(CounterTheme.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .overlay(Rectangle().stroke(CounterTheme.lineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("app-settings-list")
    }

    private var header: some View {
        HStack {
            Text("APP SETTINGS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(CounterTheme.inkMuted)
            Spacer()
            Button(action: onClose) {
                Text("DONE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(CounterTheme.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CounterTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("app-settings-close")
        }
    }
}
