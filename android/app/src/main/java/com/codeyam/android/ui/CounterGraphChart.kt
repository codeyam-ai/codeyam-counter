package com.codeyam.android.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import com.codeyam.android.model.CounterHistory

/**
 * A canvas-drawn step-line chart of a history's running count over relative
 * time: x = seconds since the history's `startedAt`, y = running count. Both
 * axes are drawn and labeled with ticks derived from the data itself — the y
 * ticks span the actual count range (and 0), the x ticks span 0…the last event's
 * elapsed time. A step line traces the count; a marker sits at each event,
 * colored by delta sign (up-tick = the counter's accent, down-tick = the
 * coffee/subtract hue). Ports iOS `CounterGraphChart`.
 *
 * All the geometry lives in [GraphGeometry] so it can be unit-tested; this file
 * is only the drawing.
 */
@OptIn(ExperimentalTextApi::class)
@Composable
fun CounterGraphChart(history: CounterHistory, accent: Color, modifier: Modifier = Modifier) {
    val measurer = rememberTextMeasurer()
    val downColor = dotColor("coffee")

    Canvas(modifier = modifier.fillMaxSize()) {
        val rect = GraphGeometry.plotRect(size.width, size.height, density)
        val result = GraphGeometry.plot(history.cumulativeSeries(), rect)

        // The L-shaped axes.
        drawLine(
            color = CounterColors.lineStrong,
            start = Offset(rect.left, rect.top),
            end = Offset(rect.left, rect.bottom),
            strokeWidth = density,
        )
        drawLine(
            color = CounterColors.lineStrong,
            start = Offset(rect.left, rect.bottom),
            end = Offset(rect.right, rect.bottom),
            strokeWidth = density,
        )

        // The zero line is only a separate dashed guide when 0 is *inside* the
        // range (the count went negative); otherwise the x axis already sits at 0.
        if (result.minCount < 0) {
            drawLine(
                color = CounterColors.line,
                start = Offset(rect.left, result.zeroY),
                end = Offset(rect.right, result.zeroY),
                strokeWidth = density,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f * density, 3f * density)),
            )
        }

        // The step line.
        val vertices = GraphGeometry.stepVertices(result.points)
        if (vertices.size > 1) {
            val path = Path().apply {
                moveTo(vertices.first().x, vertices.first().y)
                vertices.drop(1).forEach { lineTo(it.x, it.y) }
            }
            drawPath(path, color = accent, style = Stroke(width = 2f * density, join = StrokeJoin.Round))
        }

        // A marker per event. Index 0 of the series is the synthetic (0,0) origin,
        // so event i maps to point i + 1.
        history.events.forEachIndexed { i, event ->
            result.points.getOrNull(i + 1)?.let { p ->
                drawCircle(
                    color = if (event.delta >= 0) accent else downColor,
                    radius = 4.5f * density,
                    center = Offset(p.x, p.y),
                )
            }
        }

        drawAxisLabels(measurer, rect, result, density)
    }
}

/**
 * The tick labels and axis titles. Y ticks are the max count, the min count, and
 * 0 when it is a distinct interior value; x ticks are start, midpoint and the
 * last event's elapsed time — all pulled from the data's own range.
 */
@OptIn(ExperimentalTextApi::class)
private fun DrawScope.drawAxisLabels(
    measurer: TextMeasurer,
    rect: PlotRect,
    result: PlotResult,
    density: Float,
) {
    val labelStyle = TextStyle(
        fontSize = 9.sp,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Medium,
        color = CounterColors.inkMuted,
    )
    val titleStyle = labelStyle.copy(fontWeight = FontWeight.Bold)

    val span = maxOf(1, result.maxCount - result.minCount)
    setOf(result.maxCount, 0, result.minCount).sortedDescending().forEach { value ->
        val y = rect.bottom - rect.height * ((value - result.minCount).toFloat() / span)
        val laid = measurer.measure(formatCount(value), labelStyle)
        drawText(
            textLayoutResult = laid,
            topLeft = Offset(
                x = rect.left - 8f * density - laid.size.width,
                y = y - laid.size.height / 2f,
            ),
        )
    }

    listOf(
        0.0 to rect.left,
        result.maxTime / 2 to rect.centerX,
        result.maxTime to rect.right,
    ).forEachIndexed { i, (time, x) ->
        val laid = measurer.measure(GraphGeometry.relativeTime(time), labelStyle)
        // Nudge the first and last labels inward so neither runs off the canvas.
        val left = when (i) {
            0 -> x
            2 -> x - laid.size.width
            else -> x - laid.size.width / 2f
        }
        drawText(textLayoutResult = laid, topLeft = Offset(left, rect.bottom + 5f * density))
    }

    val xTitle = measurer.measure("TIME (M:SS)", titleStyle)
    drawText(
        textLayoutResult = xTitle,
        topLeft = Offset(rect.centerX - xTitle.size.width / 2f, rect.bottom + 19f * density),
    )

    // The y-axis title is rotated in place; `nativeCanvas` is the only way to
    // rotate text under `drawText`.
    val yTitle = measurer.measure("COUNT", titleStyle)
    drawContext.canvas.nativeCanvas.save()
    drawContext.canvas.nativeCanvas.rotate(
        -90f,
        9f * density + yTitle.size.height / 2f,
        rect.centerY,
    )
    drawText(
        textLayoutResult = yTitle,
        topLeft = Offset(
            x = 9f * density + yTitle.size.height / 2f - yTitle.size.width / 2f,
            y = rect.centerY - yTitle.size.height / 2f,
        ),
    )
    drawContext.canvas.nativeCanvas.restore()
}
