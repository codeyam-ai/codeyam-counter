import SwiftUI

/// The lower row beneath the increment bar: three smaller controls and the
/// increment button's downward extension. SWITCH always sits adjacent to the
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
    let onSubtract: () -> Void
    let onReset: () -> Void
    let onSwitch: () -> Void
    let onIncrement: () -> Void

    public init(leftHanded: Bool,
                continuationWidth: CGFloat,
                resetIsUndo: Bool,
                onSubtract: @escaping () -> Void,
                onReset: @escaping () -> Void,
                onSwitch: @escaping () -> Void,
                onIncrement: @escaping () -> Void) {
        self.leftHanded = leftHanded
        self.continuationWidth = continuationWidth
        self.resetIsUndo = resetIsUndo
        self.onSubtract = onSubtract
        self.onReset = onReset
        self.onSwitch = onSwitch
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
        let switchBtn = ControlButton(glyph: "⇆", label: "SWITCH", identifier: "switch", action: onSwitch)
        return HStack(spacing: 0) {
            if leftHanded {
                switchBtn
                divider
                subtract
                divider
                reset
            } else {
                reset
                divider
                subtract
                divider
                switchBtn
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("increment-continuation")
    }
}
