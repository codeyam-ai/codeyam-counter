import SwiftUI

/// Shared press styling for the two faces of the increment button (the top
/// `IncrementBar` and the `incrementContinuation` in `BottomControlRow`). The
/// button is drawn as two separate hit areas, so each face syncs its own
/// `isPressed` into a shared `pressed` binding and dims from that shared value —
/// pressing either face dims BOTH, so the whole thing reads as one surface.
struct IncrementFaceButtonStyle: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(pressed ? 0.72 : 1)
            .onChange(of: configuration.isPressed) { isPressed in
                pressed = isPressed
            }
    }
}
