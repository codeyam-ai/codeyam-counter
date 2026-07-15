import SwiftUI

/// The lower row beneath the increment bar: three smaller controls and the
/// increment button's downward extension. GRAPH always sits adjacent to the
/// increment extension, then SUBTRACT, then RESET — and the whole row mirrors
/// with `leftHanded` so the extension (and "+" above it) lands under whichever
/// thumb is holding the phone. All four sections share an equal quarter width.
public struct BottomControlRow: View {
    let leftHanded: Bool
    let continuationWidth: CGFloat
    /// When true the RESET slot renders as UNDO RESET (an undo of the last reset
    /// is pending on the active counter). The slot keeps its `"reset"` accessibility
    /// identifier in both modes; `onReset` dispatches by mode upstream.
    let resetIsUndo: Bool
    /// When true the graph overlay is currently open, so the GRAPH slot renders as
    /// a CLOSE affordance (reclicking it dismisses the graph). The slot keeps its
    /// `"graph"` accessibility identifier in both modes; `onGraph` toggles upstream.
    let graphOpen: Bool
    /// Shared pressed state for the whole increment button, driven jointly with
    /// the top `IncrementBar`. The downward extension writes into it and dims from
    /// it, so pressing either face dims both. Defaults to `.constant(false)` so
    /// isolated scaffolds render the static, un-pressed appearance.
    @Binding var incrementPressed: Bool
    let onSubtract: () -> Void
    let onReset: () -> Void
    let onGraph: () -> Void
    let onIncrement: () -> Void

    public init(leftHanded: Bool,
                continuationWidth: CGFloat,
                resetIsUndo: Bool,
                graphOpen: Bool,
                incrementPressed: Binding<Bool> = .constant(false),
                onSubtract: @escaping () -> Void,
                onReset: @escaping () -> Void,
                onGraph: @escaping () -> Void,
                onIncrement: @escaping () -> Void) {
        self.leftHanded = leftHanded
        self.continuationWidth = continuationWidth
        self.resetIsUndo = resetIsUndo
        self.graphOpen = graphOpen
        self._incrementPressed = incrementPressed
        self.onSubtract = onSubtract
        self.onReset = onReset
        self.onGraph = onGraph
        self.onIncrement = onIncrement
    }

    public var body: some View {
        HStack(spacing: 0) {
            if leftHanded {
                incrementContinuation
                controlsGroup
            } else {
                controlsGroup
                incrementContinuation
            }
        }
    }

    private var controlsGroup: some View {
        let subtract = ControlButton(glyph: "−", label: "SUBTRACT", identifier: "subtract", action: onSubtract)
        let reset = ControlButton(glyph: resetIsUndo ? "↶" : "↺",
                                  label: resetIsUndo ? "UNDO RESET" : "RESET",
                                  identifier: "reset", action: onReset)
        let graph = ControlButton(systemImage: graphOpen ? "xmark" : "chart.xyaxis.line",
                                  label: graphOpen ? "CLOSE" : "GRAPH",
                                  identifier: "graph", action: onGraph)
        return HStack(spacing: 0) {
            if leftHanded {
                graph
                divider
                subtract
                divider
                reset
            } else {
                reset
                divider
                subtract
                divider
                graph
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CounterTheme.panel)
        .overlay(Rectangle().fill(CounterTheme.line).frame(height: 1), alignment: .top)
    }

    private var divider: some View {
        Rectangle().fill(CounterTheme.line).frame(width: 1)
    }

    private var incrementContinuation: some View {
        Button(action: onIncrement) {
            Rectangle()
                .fill(CounterTheme.accent)
                .frame(width: continuationWidth)
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(IncrementFaceButtonStyle(pressed: $incrementPressed))
        .accessibilityIdentifier("increment-continuation")
    }
}
