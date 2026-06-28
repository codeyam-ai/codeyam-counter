import SwiftUI

/// The counter screen. Owns the model and the handedness preference, wires the
/// swipe-to-switch gesture, and composes the section components.
public struct ContentView: View {
    @StateObject private var model = CounterModel()

    /// When true the bottom-row order is mirrored and the increment button
    /// extends down on the LEFT — a thumb-reachable layout for left-handed use.
    /// Persisted on-device via the "leftHanded" UserDefaults key.
    @AppStorage("leftHanded") private var leftHanded = false

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                CounterTheme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    HeaderBar(positionLabel: model.positionLabel)
                    CounterSwitcherCard(
                        counters: model.counters,
                        activeId: model.activeCounter.id,
                        activeName: model.activeCounter.name,
                        onSelect: { id in withAnimation { model.select(id: id) } }
                    )
                    CountHero(count: model.activeCounter.count)
                    CounterBottomBar(
                        leftHanded: leftHanded,
                        screenHeight: geo.size.height,
                        screenWidth: geo.size.width,
                        onIncrement: { model.increment() },
                        onSubtract: { model.subtract() },
                        onReset: { model.reset() },
                        onSwitch: { withAnimation { leftHanded.toggle() } }
                    )
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
}
