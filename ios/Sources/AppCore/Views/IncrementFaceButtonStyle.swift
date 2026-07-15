import SwiftUI

/// Shared press styling for the two faces of the increment button (the top
/// `IncrementBar` and the `incrementContinuation` in `BottomControlRow`). The
/// button is drawn as two separate hit areas, so each face syncs its own
/// `isPressed` into a shared `pressed` binding and dims from that shared value —
/// pressing either face dims BOTH, so the whole thing reads as one surface.
///
/// The shared binding alone only guarantees both faces reach the same opacity,
/// not that they get there together: the face you actually touch would animate
/// its dim inside SwiftUI's implicit press transaction while the other face,
/// re-rendering purely from the state change, used a different (or no)
/// transaction — so the L-shape visibly broke into two pieces mid-press. The
/// explicit `.animation(_, value: pressed)` below is what keeps them in sync,
/// pinning both faces to one identical curve and duration.
struct IncrementFaceButtonStyle: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(pressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .onChange(of: configuration.isPressed) { isPressed in
                pressed = isPressed
            }
    }
}
