import SwiftUI

/// The counter screen. Owns the model and the system-wide app settings, wires
/// the swipe-to-switch gesture, and composes the section components.
public struct ContentView: View {
    @StateObject private var model = CounterModel(feedback: SystemCounterFeedback())

    /// System-wide defaults (handedness, sound, haptic). Replaces the former lone
    /// `@AppStorage("leftHanded")`; `defaultLeftHanded` still reads/writes that
    /// same key so the on-device preference and existing scenarios carry over.
    @StateObject private var settings = AppSettings()

    /// When true the inline per-counter settings panel expands over the count
    /// numeral. Production starts closed; the initial value is read once from the
    /// `settingsOpen` preference so a scenario can seed the panel open for a
    /// static simulator capture (there is no live tap driver to open it).
    @State private var showSettings: Bool
    /// The system-wide App Settings panel. Seedable via `appSettingsOpen`.
    @State private var showAppSettings: Bool
    /// The all-counters list overlay. Seedable via `counterListOpen`.
    @State private var showCounterList: Bool

    public init() {
        _showSettings = State(initialValue: UserDefaults.standard.bool(forKey: "settingsOpen"))
        _showAppSettings = State(initialValue: UserDefaults.standard.bool(forKey: "appSettingsOpen"))
        _showCounterList = State(initialValue: UserDefaults.standard.bool(forKey: "counterListOpen"))
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                CounterTheme.bg.ignoresSafeArea()

                // Base layer: the full screen always laid out normally.
                VStack(spacing: 0) {
                    headerBar
                    switcherCard
                    CountHero(count: model.activeCounter.count)
                    CounterBottomBar(
                        leftHanded: model.activeCounter.effectiveLeftHanded(default: settings.defaultLeftHanded),
                        screenHeight: geo.size.height,
                        screenWidth: geo.size.width,
                        resetIsUndo: model.canUndoReset,
                        onIncrement: { model.increment() },
                        onSubtract: { model.subtract() },
                        onReset: { withAnimation { model.canUndoReset ? model.undoReset() : model.reset() } },
                        onSwitch: { withAnimation { settings.defaultLeftHanded.toggle() } }
                    )
                }

                // Floating per-counter settings panel: anchored directly under the
                // switcher (hidden, non-interactive header+card act as exact-height
                // spacers), drawn on top so it overlays the count and increment bar.
                if showSettings {
                    VStack(spacing: 0) {
                        headerBar.hidden().allowsHitTesting(false)
                        switcherCard.hidden().allowsHitTesting(false)
                        CounterSettingsPanel(
                            counter: model.activeCounter,
                            onSave: { name, colorKey, allowNegative, step, handedness, sound, haptic in
                                model.updateActiveCounter(name: name, colorKey: colorKey,
                                                          allowNegative: allowNegative, step: step,
                                                          handednessOverride: handedness,
                                                          soundOverride: sound,
                                                          hapticOverride: haptic)
                            },
                            onDelete: { withAnimation { model.deleteCounter(id: model.activeCounter.id) } },
                            onClose: { withAnimation { showSettings = false } }
                        )
                        .id(model.activeCounter.id)
                        Spacer(minLength: 0)
                    }
                    .allowsHitTesting(true)
                    .transition(.opacity)
                }

                // Floating App Settings panel: anchored under the header (hidden
                // header acts as the exact-height spacer), drawn on top.
                if showAppSettings {
                    VStack(spacing: 0) {
                        headerBar.hidden().allowsHitTesting(false)
                        AppSettingsPanel(
                            settings: settings,
                            onOpenList: { withAnimation { showCounterList = true } },
                            onClose: { withAnimation { showAppSettings = false } }
                        )
                        Spacer(minLength: 0)
                    }
                    .allowsHitTesting(true)
                    .transition(.opacity)
                }

                // All-counters list overlay: also anchored under the header. Drawn
                // last so it sits above the App Settings panel that opened it.
                if showCounterList {
                    VStack(spacing: 0) {
                        headerBar.hidden().allowsHitTesting(false)
                        CounterListPanel(
                            counters: model.counters,
                            activeId: model.activeCounter.id,
                            onSelect: { id in
                                withAnimation {
                                    model.select(id: id)
                                    showCounterList = false
                                    showAppSettings = false
                                }
                            },
                            onClose: { withAnimation { showCounterList = false } }
                        )
                        Spacer(minLength: 0)
                    }
                    .allowsHitTesting(true)
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Resolve the effective feedback through the active counter: its
            // per-counter override wins, otherwise the shared app default. Read
            // at emit time so switching counters re-resolves without re-wiring.
            model.effectiveFeedback = {
                let c = model.activeCounter
                return (c.effectiveSound(default: settings.soundOption),
                        c.effectiveHaptic(default: settings.hapticOption))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40 {
                        withAnimation { model.selectNext() }
                    } else if value.translation.width > 40 {
                        withAnimation { model.selectPrevious() }
                    }
                }
        )
    }

    private var headerBar: some View {
        HeaderBar(onSettingsTap: { withAnimation { showAppSettings.toggle() } })
    }

    private var switcherCard: some View {
        CounterSwitcherCard(
            counters: model.counters,
            activeId: model.activeCounter.id,
            activeName: model.activeCounter.name,
            onSelect: { id in withAnimation { model.select(id: id); showSettings = false } },
            onGearTap: { withAnimation { showSettings.toggle() } }
        )
    }
}
