import SwiftUI

/// The counter screen. Owns the model and the handedness preference, wires the
/// swipe-to-switch gesture, and composes the section components.
public struct ContentView: View {
    @StateObject private var model = CounterModel()

    /// When true the bottom-row order is mirrored and the increment button
    /// extends down on the LEFT — a thumb-reachable layout for left-handed use.
    /// Persisted on-device via the "leftHanded" UserDefaults key.
    @AppStorage("leftHanded") private var leftHanded = false

    /// When true the inline settings panel expands over the count numeral.
    /// Production starts closed; the initial value is read once from the
    /// `settingsOpen` preference so a scenario can seed the panel open for a
    /// static simulator capture (there is no live tap driver to open it).
    @State private var showSettings: Bool

    public init() {
        _showSettings = State(initialValue: UserDefaults.standard.bool(forKey: "settingsOpen"))
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
                        leftHanded: leftHanded,
                        screenHeight: geo.size.height,
                        screenWidth: geo.size.width,
                        resetIsUndo: model.canUndoReset,
                        onIncrement: { model.increment() },
                        onSubtract: { model.subtract() },
                        onReset: { withAnimation { model.canUndoReset ? model.undoReset() : model.reset() } },
                        onSwitch: { withAnimation { leftHanded.toggle() } }
                    )
                }

                // Floating settings panel: anchored directly under the switcher
                // (hidden, non-interactive header+card act as exact-height
                // spacers), sized to its content, drawn on top so it overlays
                // the count and the increment bar rather than reserving layout.
                if showSettings {
                    VStack(spacing: 0) {
                        headerBar.hidden().allowsHitTesting(false)
                        switcherCard.hidden().allowsHitTesting(false)
                        CounterSettingsPanel(
                            counter: model.activeCounter,
                            onSave: { name, colorKey, allowNegative, step in
                                model.updateActiveCounter(name: name, colorKey: colorKey,
                                                          allowNegative: allowNegative, step: step)
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
            }
        }
        .preferredColorScheme(.dark)
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
        HeaderBar(positionLabel: model.positionLabel)
    }

    private var switcherCard: some View {
        CounterSwitcherCard(
            counters: model.counters,
            ghostSlots: model.ghostSlots,
            activeId: model.activeCounter.id,
            activeName: model.activeCounter.name,
            onSelect: { id in withAnimation { model.select(id: id); showSettings = false } },
            onRestore: { id in withAnimation { model.restoreDefault(id: id); showSettings = false } },
            onGearTap: { withAnimation { showSettings.toggle() } }
        )
    }
}
