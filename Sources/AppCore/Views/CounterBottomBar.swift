import SwiftUI

/// The whole bottom assembly: the increment bar starts about one-fifth of the
/// screen height up from the bottom and extends down into the lower control row.
/// Computes the equal-quarter column width shared by the four bottom sections.
public struct CounterBottomBar: View {
    let leftHanded: Bool
    let screenHeight: CGFloat
    let screenWidth: CGFloat
    /// Passed straight through to `BottomControlRow`: render the RESET slot as
    /// UNDO RESET when an undo is pending on the active counter.
    let resetIsUndo: Bool
    let onIncrement: () -> Void
    let onSubtract: () -> Void
    let onReset: () -> Void
    let onSwitch: () -> Void

    public init(leftHanded: Bool,
                screenHeight: CGFloat,
                screenWidth: CGFloat,
                resetIsUndo: Bool,
                onIncrement: @escaping () -> Void,
                onSubtract: @escaping () -> Void,
                onReset: @escaping () -> Void,
                onSwitch: @escaping () -> Void) {
        self.leftHanded = leftHanded
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        self.resetIsUndo = resetIsUndo
        self.onIncrement = onIncrement
        self.onSubtract = onSubtract
        self.onReset = onReset
        self.onSwitch = onSwitch
    }

    public var body: some View {
        let assemblyHeight = screenHeight * 0.20
        let lowerRowHeight: CGFloat = 64
        let topBarHeight = max(assemblyHeight - lowerRowHeight, 64)
        let columnWidth = screenWidth / 4

        return VStack(spacing: 0) {
            IncrementBar(leftHanded: leftHanded, plusColumnWidth: columnWidth, onIncrement: onIncrement)
                .frame(height: topBarHeight)
            BottomControlRow(
                leftHanded: leftHanded,
                continuationWidth: columnWidth,
                resetIsUndo: resetIsUndo,
                onSubtract: onSubtract,
                onReset: onReset,
                onSwitch: onSwitch,
                onIncrement: onIncrement
            )
            .frame(height: lowerRowHeight)
        }
    }
}
