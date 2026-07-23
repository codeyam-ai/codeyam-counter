package com.codeyam.android.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/**
 * The two glyphs this app needs that the core Material icon set does not carry:
 * the header's sliders mark and the bottom row's chart mark (iOS draws these as
 * the SF Symbols `slider.horizontal.3` and `chart.xyaxis.line`).
 *
 * Hand-built as small vectors rather than pulling in `material-icons-extended`,
 * which ships thousands of glyphs to supply two — and these trace the SF Symbols
 * more closely than the nearest Material stand-ins would.
 */
object CounterIcons {

    /** Three horizontal rules with offset knobs — the app-settings entry point. */
    val Sliders: ImageVector by lazy {
        strokeIcon("sliders") {
            // Rule 1 with its knob left of center.
            path(stroke = SolidColor(Color.White), strokeLineWidth = 2f, strokeLineCap = StrokeCap.Round) {
                moveTo(3f, 7f); lineTo(21f, 7f)
            }
            path(fill = SolidColor(Color.White)) {
                addCircle(9f, 7f, 2.5f)
            }
            // Rule 2 with its knob right of center.
            path(stroke = SolidColor(Color.White), strokeLineWidth = 2f, strokeLineCap = StrokeCap.Round) {
                moveTo(3f, 12f); lineTo(21f, 12f)
            }
            path(fill = SolidColor(Color.White)) {
                addCircle(16f, 12f, 2.5f)
            }
            // Rule 3 with its knob left again.
            path(stroke = SolidColor(Color.White), strokeLineWidth = 2f, strokeLineCap = StrokeCap.Round) {
                moveTo(3f, 17f); lineTo(21f, 17f)
            }
            path(fill = SolidColor(Color.White)) {
                addCircle(7f, 17f, 2.5f)
            }
        }
    }

    /** An x/y axis pair with a rising polyline — the GRAPH control. */
    val Chart: ImageVector by lazy {
        strokeIcon("chart") {
            // The L-shaped axes.
            path(
                stroke = SolidColor(Color.White),
                strokeLineWidth = 2f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round,
            ) {
                moveTo(4f, 3f); lineTo(4f, 20f); lineTo(21f, 20f)
            }
            // The plotted run.
            path(
                stroke = SolidColor(Color.White),
                strokeLineWidth = 2f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round,
            ) {
                moveTo(7f, 15f); lineTo(11f, 10f); lineTo(14f, 13f); lineTo(19f, 6f)
            }
        }
    }
}

/**
 * A 24x24 icon whose paths are stroked/filled in white, so `Icon`'s `tint` is
 * what actually colors it at each call site.
 */
private fun strokeIcon(
    name: String,
    content: ImageVector.Builder.() -> Unit,
): ImageVector = ImageVector.Builder(
    name = name,
    defaultWidth = 24.dp,
    defaultHeight = 24.dp,
    viewportWidth = 24f,
    viewportHeight = 24f,
).apply(content).build()

/**
 * Approximates a circle with four cubic arcs — `PathBuilder` has no circle
 * primitive, and the knobs on the sliders glyph need one.
 */
private fun androidx.compose.ui.graphics.vector.PathBuilder.addCircle(
    cx: Float,
    cy: Float,
    r: Float,
) {
    // 0.5523 is the standard cubic-Bezier constant for a quarter circle.
    val k = r * 0.5523f
    moveTo(cx, cy - r)
    curveTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy)
    curveTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r)
    curveTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy)
    curveTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r)
    close()
}
