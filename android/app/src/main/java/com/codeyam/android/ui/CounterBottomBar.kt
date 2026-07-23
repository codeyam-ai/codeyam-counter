package com.codeyam.android.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The whole bottom assembly: the increment bar starts about one-fifth of the
 * screen height up from the bottom and extends down into the lower control row,
 * forming one L-shaped increment surface. Ports iOS `CounterBottomBar`.
 *
 * The two increment faces are non-contiguous (the control row sits between them)
 * so they cannot be a single button. As on iOS, one shared pressed flag is
 * hoisted here and both faces dim from it, so pressing either reads as pressing
 * one surface. [initiallyPressed] is the demo seam that lets an isolated capture
 * show the pressed appearance.
 */
@Composable
fun CounterBottomBar(
    leftHanded: Boolean,
    screenHeight: Dp,
    screenWidth: Dp,
    resetIsUndo: Boolean,
    graphOpen: Boolean,
    onIncrement: () -> Unit,
    onSubtract: () -> Unit,
    onReset: () -> Unit,
    onGraph: () -> Unit,
    modifier: Modifier = Modifier,
    initiallyPressed: Boolean = false,
) {
    var pressed by remember { mutableStateOf(initiallyPressed) }

    val assemblyHeight = screenHeight * 0.20f
    val lowerRowHeight = 64.dp
    val topBarHeight = maxOf(assemblyHeight - lowerRowHeight, 64.dp)
    val columnWidth = screenWidth / 4

    Column(modifier = modifier.fillMaxWidth()) {
        IncrementBar(
            leftHanded = leftHanded,
            plusColumnWidth = columnWidth,
            pressed = pressed,
            onPressedChange = { pressed = it },
            onIncrement = onIncrement,
            modifier = Modifier.height(topBarHeight),
        )
        BottomControlRow(
            leftHanded = leftHanded,
            continuationWidth = columnWidth,
            resetIsUndo = resetIsUndo,
            graphOpen = graphOpen,
            incrementPressed = pressed,
            onIncrementPressedChange = { pressed = it },
            onSubtract = onSubtract,
            onReset = onReset,
            onGraph = onGraph,
            onIncrement = onIncrement,
            modifier = Modifier.height(lowerRowHeight),
        )
    }
}

/**
 * The full-width top face of the increment button. The "+" sits on this higher
 * row, vertically aligned with the label and on the opposite side of the screen
 * from it; both flip with [leftHanded] so the "+" stays above the side the
 * button extends down on, centered in a column the same width as that extension.
 * Ports iOS `IncrementBar`.
 */
@Composable
fun IncrementBar(
    leftHanded: Boolean,
    plusColumnWidth: Dp,
    onIncrement: () -> Unit,
    modifier: Modifier = Modifier,
    pressed: Boolean = false,
    onPressedChange: (Boolean) -> Unit = {},
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(CounterColors.accent)
            .incrementFace(pressed, onPressedChange, onIncrement)
            .semantics { contentDescription = "increment" },
    ) {
        val label: @Composable () -> Unit = {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .padding(horizontal = 26.dp),
                contentAlignment = if (leftHanded) Alignment.CenterEnd else Alignment.CenterStart,
            ) {
                Text(
                    text = "TAP TO\nINCREMENT",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    textAlign = if (leftHanded) TextAlign.End else TextAlign.Start,
                    color = CounterColors.onAccent,
                )
            }
        }
        val plus: @Composable () -> Unit = {
            Box(
                modifier = Modifier
                    .width(plusColumnWidth)
                    .fillMaxHeight(),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "+",
                    fontSize = 52.sp,
                    fontWeight = FontWeight.Black,
                    color = CounterColors.onAccent,
                )
            }
        }

        if (leftHanded) {
            plus()
            label()
        } else {
            label()
            plus()
        }
    }
}

/**
 * The lower row beneath the increment bar: three smaller controls plus the
 * increment button's downward extension. GRAPH always sits adjacent to the
 * extension, then SUBTRACT, then RESET — and the whole row mirrors with
 * [leftHanded] so the extension (and the "+" above it) lands under whichever
 * thumb holds the phone. All four sections share an equal quarter width.
 * Ports iOS `BottomControlRow`.
 */
@Composable
fun BottomControlRow(
    leftHanded: Boolean,
    continuationWidth: Dp,
    resetIsUndo: Boolean,
    graphOpen: Boolean,
    onSubtract: () -> Unit,
    onReset: () -> Unit,
    onGraph: () -> Unit,
    onIncrement: () -> Unit,
    modifier: Modifier = Modifier,
    incrementPressed: Boolean = false,
    onIncrementPressedChange: (Boolean) -> Unit = {},
) {
    Row(modifier = modifier.fillMaxWidth()) {
        val controls: @Composable () -> Unit = {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .background(CounterColors.panel),
            ) {
                val subtract: @Composable () -> Unit = {
                    ControlButton(label = "SUBTRACT", identifier = "subtract", onClick = onSubtract, glyph = "−")
                }
                val reset: @Composable () -> Unit = {
                    ControlButton(
                        label = if (resetIsUndo) "UNDO RESET" else "RESET",
                        identifier = "reset",
                        onClick = onReset,
                        glyph = if (resetIsUndo) "↶" else "↺",
                    )
                }
                val graph: @Composable () -> Unit = {
                    ControlButton(
                        label = if (graphOpen) "CLOSE" else "GRAPH",
                        identifier = "graph",
                        onClick = onGraph,
                        icon = if (graphOpen) Icons.Filled.Close else CounterIcons.Chart,
                    )
                }
                if (leftHanded) {
                    graph(); VerticalDivider(); subtract(); VerticalDivider(); reset()
                } else {
                    reset(); VerticalDivider(); subtract(); VerticalDivider(); graph()
                }
            }
        }
        val continuation: @Composable () -> Unit = {
            Box(
                modifier = Modifier
                    .width(continuationWidth)
                    .fillMaxHeight()
                    .background(CounterColors.accent)
                    .incrementFace(incrementPressed, onIncrementPressedChange, onIncrement)
                    .semantics { contentDescription = "increment-continuation" },
            )
        }

        if (leftHanded) {
            continuation()
            controls()
        } else {
            controls()
            continuation()
        }
    }
}

/**
 * Shared press behavior for the two faces of the increment button: each face
 * reports its own press into the shared flag and dims from that shared value, so
 * pressing either dims both.
 *
 * The shared flag alone only guarantees both faces reach the same opacity, not
 * that they get there together — the touched face would animate inside its own
 * press transaction while the other re-rendered from the state change on a
 * different curve, visibly breaking the L-shape mid-press. Animating both from
 * one explicit [tween] keyed on the shared value is what keeps them in sync; it
 * is the direct analog of iOS's `.animation(_, value: pressed)`.
 */
private fun Modifier.incrementFace(
    pressed: Boolean,
    onPressedChange: (Boolean) -> Unit,
    onClick: () -> Unit,
): Modifier = composed {
    val faceAlpha by animateFloatAsState(
        targetValue = if (pressed) 0.72f else 1f,
        animationSpec = tween(durationMillis = 120),
        label = "increment-press-dim",
    )
    this
        .alpha(faceAlpha)
        .pointerInput(Unit) {
            detectTapGestures(
                onPress = {
                    onPressedChange(true)
                    tryAwaitRelease()
                    onPressedChange(false)
                },
                onTap = { onClick() },
            )
        }
}

/** A hairline vertical rule between two controls in the bottom row. */
@Composable
private fun VerticalDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .fillMaxHeight()
            .background(CounterColors.line),
    )
}
