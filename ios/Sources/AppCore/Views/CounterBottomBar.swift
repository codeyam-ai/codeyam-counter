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
    /// Passed straight through to `BottomControlRow`: render the GRAPH slot as
    /// CLOSE when the graph overlay is currently open.
    let graphOpen: Bool
    let onIncrement: () -> Void
    let onSubtract: () -> Void
    let onReset: () -> Void
    let onGraph: () -> Void

    /// One pressed state shared by both increment faces. Hoisted here because the
    /// two faces are non-contiguous in the layout (the control row sits between
    /// them) and cannot be one `Button`; the shared binding makes pressing either
    /// face dim both, so the L-shape reads as a single surface.
    @State private var incrementPressed: Bool

    public init(leftHanded: Bool,
                screenHeight: CGFloat,
                screenWidth: CGFloat,
                resetIsUndo: Bool,
                graphOpen: Bool,
                onIncrement: @escaping () -> Void,
                onSubtract: @escaping () -> Void,
                onReset: @escaping () -> Void,
                onGraph: @escaping () -> Void,
                initiallyPressed: Bool = false) {
        self.leftHanded = leftHanded
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        self.resetIsUndo = resetIsUndo
        self.graphOpen = graphOpen
        // Demo/preview seam: seed the shared pressed state so isolated captures can
        // show the pressed appearance (both faces dimmed in unison). Real call sites
        // omit it and start un-pressed.
        self._incrementPressed = State(initialValue: initiallyPressed)
        self.onIncrement = onIncrement
        self.onSubtract = onSubtract
        self.onReset = onReset
        self.onGraph = onGraph
    }

    public var body: some View {
        let assemblyHeight = screenHeight * 0.20
        let lowerRowHeight: CGFloat = 64
        let topBarHeight = max(assemblyHeight - lowerRowHeight, 64)
        let columnWidth = screenWidth / 4

        return VStack(spacing: 0) {
            IncrementBar(leftHanded: leftHanded,
                         plusColumnWidth: columnWidth,
                         pressed: $incrementPressed,
                         onIncrement: onIncrement)
                .frame(height: topBarHeight)
            BottomControlRow(
                leftHanded: leftHanded,
                continuationWidth: columnWidth,
                resetIsUndo: resetIsUndo,
                graphOpen: graphOpen,
                incrementPressed: $incrementPressed,
                onSubtract: onSubtract,
                onReset: onReset,
                onGraph: onGraph,
                onIncrement: onIncrement
            )
            .frame(height: lowerRowHeight)
        }
    }
}
