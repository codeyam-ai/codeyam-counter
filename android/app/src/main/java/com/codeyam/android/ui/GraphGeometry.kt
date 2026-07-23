package com.codeyam.android.ui

import com.codeyam.android.model.CumulativePoint
import kotlin.math.max
import kotlin.math.roundToInt

/** A point in plot space. A plain holder so the geometry stays Compose-free. */
data class PlotPoint(val x: Float, val y: Float)

/** The plot area within the gutters that hold the axis labels and titles. */
data class PlotRect(val left: Float, val top: Float, val width: Float, val height: Float) {
    val right: Float get() = left + width
    val bottom: Float get() = top + height
    val centerX: Float get() = left + width / 2f
    val centerY: Float get() = top + height / 2f
}

/**
 * The result of mapping a series into a plot rect: the plotted points, the y of
 * the zero line, and the data-derived domain the axes label against.
 */
data class PlotResult(
    val points: List<PlotPoint>,
    val zeroY: Float,
    val minCount: Int,
    val maxCount: Int,
    val maxTime: Double,
)

/**
 * The pure geometry behind [CounterGraphChart] — x = seconds since the history's
 * start, y = running count. Ported from the static members of iOS
 * `CounterGraphChart`, and kept free of any Compose type for the same reason
 * those were kept view-free: the mapping is the part worth unit-testing, and it
 * should be testable without rendering anything.
 */
object GraphGeometry {

    // Gutters reserve room for the axis tick labels and titles around the plot.
    // Expressed in dp, exactly as the iOS values are in points.
    const val LEFT_GUTTER_DP = 52f
    const val BOTTOM_GUTTER_DP = 34f
    const val TOP_INSET_DP = 12f
    const val RIGHT_INSET_DP = 16f

    /**
     * The plot area inside the gutters, for a canvas of [width] x [height] *in
     * pixels*. [density] converts the dp gutters to pixels — passing 1f (the
     * default) keeps the geometry unit-testable in dp-space without a display.
     * Getting this wrong is not cosmetic: raw-pixel gutters collapse to a third
     * of their intended size on a 3x screen and the tick labels collide.
     */
    fun plotRect(width: Float, height: Float, density: Float = 1f): PlotRect {
        val left = LEFT_GUTTER_DP * density
        val top = TOP_INSET_DP * density
        return PlotRect(
            left = left,
            top = top,
            width = max(1f, width - left - RIGHT_INSET_DP * density),
            height = max(1f, height - top - BOTTOM_GUTTER_DP * density),
        )
    }

    /**
     * Maps the cumulative series to plotted points and the domain. The count
     * domain always includes 0 so the baseline is on-chart, and a minimum
     * time/count span avoids a divide-by-zero for a flat or single-point series.
     */
    fun plot(series: List<CumulativePoint>, rect: PlotRect): PlotResult {
        val counts = series.map { it.count }
        val minCount = minOf(0, counts.minOrNull() ?: 0)
        val maxCount = maxOf(0, counts.maxOrNull() ?: 0)
        val countSpan = max(1, maxCount - minCount)
        val maxTime = max(1.0, series.maxOfOrNull { it.time } ?: 1.0)

        fun x(t: Double): Float = rect.left + rect.width * (t / maxTime).toFloat()
        fun y(c: Int): Float =
            rect.bottom - rect.height * ((c - minCount).toDouble() / countSpan).toFloat()

        return PlotResult(
            points = series.map { PlotPoint(x(it.time), y(it.count)) },
            zeroY = y(0),
            minCount = minCount,
            maxCount = maxCount,
            maxTime = maxTime,
        )
    }

    /**
     * A step line: hold the previous count until the next event's time, then jump
     * to the new count — the shape of a discrete tally over time. Returned as the
     * ordered vertices so the caller can stroke them however it likes.
     */
    fun stepVertices(points: List<PlotPoint>): List<PlotPoint> {
        if (points.isEmpty()) return emptyList()
        val out = mutableListOf(points.first())
        var previous = points.first()
        for (point in points.drop(1)) {
            out.add(PlotPoint(point.x, previous.y))
            out.add(point)
            previous = point
        }
        return out
    }

    /**
     * Formats a relative offset in seconds as `mm:ss`, or `h:mm:ss` once it passes
     * an hour. The single source of truth shared by the axis ticks and the event
     * list, so the two always read the same way.
     */
    fun relativeTime(interval: Double): String {
        val total = max(0, interval.roundToInt())
        val hours = total / 3600
        val minutes = (total % 3600) / 60
        val seconds = total % 60
        return if (hours > 0) {
            "%d:%02d:%02d".format(hours, minutes, seconds)
        } else {
            "%02d:%02d".format(minutes, seconds)
        }
    }
}
