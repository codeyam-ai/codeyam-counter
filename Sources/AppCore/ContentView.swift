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
    /// The activity graph overlay for the active counter. Seedable via `graphOpen`
    /// so a static capture can show the chart without a live tap on GRAPH.
    @State private var showGraph: Bool

    public init() {
        _showSettings = State(initialValue: UserDefaults.standard.bool(forKey: "settingsOpen"))
        _showAppSettings = State(initialValue: UserDefaults.standard.bool(forKey: "appSettingsOpen"))
        _showCounterList = State(initialValue: UserDefaults.standard.bool(forKey: "counterListOpen"))
        _showGraph = State(initialValue: UserDefaults.standard.bool(forKey: "graphOpen"))
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
                        graphOpen: showGraph,
                        onIncrement: { model.increment() },
                        onSubtract: { model.subtract() },
                        onReset: { withAnimation { model.canUndoReset ? model.undoReset() : model.reset() } },
                        onGraph: { withAnimation { showGraph.toggle() } }
                    )
                }

                // Floating per-counter settings panel: anchored directly under the
                // switcher (hidden, non-interactive header+card act as exact-height
                // spacers), drawn on top so it overlays the count and increment bar.
                if showSettings {
                    HeaderAnchoredOverlay {
                        headerBar.hidden().allowsHitTesting(false)
                        switcherCard.hidden().allowsHitTesting(false)
                    } content: {
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
                    }
                }

                // Floating App Settings panel: anchored under the header (hidden
                // header acts as the exact-height spacer), drawn on top.
                if showAppSettings {
                    HeaderAnchoredOverlay {
                        headerBar.hidden().allowsHitTesting(false)
                    } content: {
                        AppSettingsPanel(
                            settings: settings,
                            onOpenList: { withAnimation { showCounterList = true } },
                            onClose: { withAnimation { showAppSettings = false } }
                        )
                    }
                }

                // All-counters list overlay: also anchored under the header. Drawn
                // last so it sits above the App Settings panel that opened it.
                if showCounterList {
                    HeaderAnchoredOverlay {
                        headerBar.hidden().allowsHitTesting(false)
                    } content: {
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
                    }
                }

                // Activity graph overlay: anchored under the header (hidden header
                // acts as the exact-height spacer), drawn on top of the screen.
                // `.id` re-seeds the view's selected-history state when switching
                // counters so it always opens on the new counter's current run.
                if showGraph {
                    HeaderAnchoredOverlay {
                        headerBar.hidden().allowsHitTesting(false)
                    } content: {
                        CounterGraphView(
                            counterName: model.activeCounter.isBlank ? "—" : model.activeCounter.name,
                            colorKey: model.activeCounter.colorKey,
                            histories: model.activeHistories
                        )
                        .id(model.activeCounter.id)
                    }
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
            onAdd: { withAnimation { model.addCounter(); showSettings = false } },
            onGearTap: { withAnimation { showSettings.toggle() } }
        )
    }
}
