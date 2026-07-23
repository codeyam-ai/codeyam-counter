package com.codeyam.android.ui

import com.codeyam.android.model.CumulativePoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The chart's pure geometry. These are the mappings that were kept free of any
 * Compose type precisely so they could be exercised here without rendering.
 */
class GraphGeometryTest {

    private val rect = GraphGeometry.plotRect(400f, 200f)

    // MARK: - plotRect

    @Test
    fun plotRectInsetsByTheGutters() {
        val r = GraphGeometry.plotRect(400f, 200f)
        assertEquals(GraphGeometry.LEFT_GUTTER_DP, r.left, 0.001f)
        assertEquals(GraphGeometry.TOP_INSET_DP, r.top, 0.001f)
        assertEquals(400f - 52f - 16f, r.width, 0.001f)
        assertEquals(200f - 12f - 34f, r.height, 0.001f)
    }

    /**
     * The bug this guards: the gutters are dp, so on a 3x screen they must be 3x
     * as many pixels. Treating them as raw pixels collapsed the plot and made the
     * x tick labels collide with the axis title.
     */
    @Test
    fun plotRectScalesGuttersByDensity() {
        val r = GraphGeometry.plotRect(1200f, 600f, density = 3f)
        assertEquals(52f * 3f, r.left, 0.001f)
        assertEquals(12f * 3f, r.top, 0.001f)
        assertEquals(1200f - 52f * 3f - 16f * 3f, r.width, 0.001f)
        assertEquals(600f - 12f * 3f - 34f * 3f, r.height, 0.001f)
    }

    /** A canvas smaller than its own gutters must still yield a positive rect. */
    @Test
    fun plotRectClampsToAPositiveSizeWhenTheCanvasIsTiny() {
        val r = GraphGeometry.plotRect(10f, 10f)
        assertTrue(r.width >= 1f)
        assertTrue(r.height >= 1f)
    }

    // MARK: - plot

    @Test
    fun plotMapsTimeAcrossTheFullWidthAndCountUpwards() {
        val series = listOf(
            CumulativePoint(0.0, 0),
            CumulativePoint(10.0, 5),
        )
        val r = GraphGeometry.plot(series, rect)

        // First point sits at the origin corner, last at the far right / top.
        assertEquals(rect.left, r.points.first().x, 0.001f)
        assertEquals(rect.bottom, r.points.first().y, 0.001f)
        assertEquals(rect.right, r.points.last().x, 0.001f)
        assertEquals(rect.top, r.points.last().y, 0.001f)
        assertEquals(0, r.minCount)
        assertEquals(5, r.maxCount)
        assertEquals(10.0, r.maxTime, 0.001)
    }

    /** The count domain always includes 0 so the baseline is on-chart. */
    @Test
    fun plotDomainAlwaysIncludesZero() {
        val allPositive = GraphGeometry.plot(
            listOf(CumulativePoint(0.0, 3), CumulativePoint(1.0, 9)),
            rect,
        )
        assertEquals(0, allPositive.minCount)

        val allNegative = GraphGeometry.plot(
            listOf(CumulativePoint(0.0, -3), CumulativePoint(1.0, -9)),
            rect,
        )
        assertEquals(0, allNegative.maxCount)
    }

    @Test
    fun plotPutsZeroLineInsideTheRectWhenTheCountWentNegative() {
        val r = GraphGeometry.plot(
            listOf(CumulativePoint(0.0, 0), CumulativePoint(1.0, -4), CumulativePoint(2.0, 4)),
            rect,
        )
        assertEquals(-4, r.minCount)
        assertEquals(4, r.maxCount)
        // 0 is the midpoint of -4..4, so the zero line is halfway up the plot.
        assertEquals(rect.top + rect.height / 2f, r.zeroY, 0.001f)
    }

    /** A flat series would divide by zero without the minimum-span guards. */
    @Test
    fun plotSurvivesAFlatSeries() {
        val r = GraphGeometry.plot(
            listOf(CumulativePoint(0.0, 0), CumulativePoint(0.0, 0)),
            rect,
        )
        assertTrue(r.points.all { it.x.isFinite() && it.y.isFinite() })
        assertEquals(1.0, r.maxTime, 0.001)
    }

    @Test
    fun plotSurvivesASinglePointSeries() {
        val r = GraphGeometry.plot(listOf(CumulativePoint(0.0, 0)), rect)
        assertEquals(1, r.points.size)
        assertTrue(r.points.single().x.isFinite())
        assertTrue(r.points.single().y.isFinite())
    }

    @Test
    fun plotHandlesAnEmptySeries() {
        val r = GraphGeometry.plot(emptyList(), rect)
        assertTrue(r.points.isEmpty())
        assertEquals(0, r.minCount)
        assertEquals(0, r.maxCount)
    }

    // MARK: - stepVertices

    /**
     * A step line holds the previous count until the next event's time, then
     * jumps — so each input point after the first contributes two vertices.
     */
    @Test
    fun stepVerticesHoldThenJump() {
        val points = listOf(
            PlotPoint(0f, 100f),
            PlotPoint(10f, 50f),
        )
        val vertices = GraphGeometry.stepVertices(points)

        assertEquals(3, vertices.size)
        assertEquals(PlotPoint(0f, 100f), vertices[0])
        // Travel horizontally at the OLD y ...
        assertEquals(PlotPoint(10f, 100f), vertices[1])
        // ... then drop to the new value.
        assertEquals(PlotPoint(10f, 50f), vertices[2])
    }

    @Test
    fun stepVerticesOfEmptyOrSingleInputAreDegenerate() {
        assertTrue(GraphGeometry.stepVertices(emptyList()).isEmpty())
        assertEquals(1, GraphGeometry.stepVertices(listOf(PlotPoint(1f, 2f))).size)
    }

    // MARK: - relativeTime

    @Test
    fun relativeTimeFormatsAsMinutesAndSeconds() {
        assertEquals("00:00", GraphGeometry.relativeTime(0.0))
        assertEquals("00:07", GraphGeometry.relativeTime(7.0))
        assertEquals("01:00", GraphGeometry.relativeTime(60.0))
        assertEquals("04:00", GraphGeometry.relativeTime(240.0))
        assertEquals("59:59", GraphGeometry.relativeTime(3599.0))
    }

    @Test
    fun relativeTimeGrowsAnHoursFieldPastAnHour() {
        assertEquals("1:00:00", GraphGeometry.relativeTime(3600.0))
        assertEquals("2:03:04", GraphGeometry.relativeTime(7384.0))
    }

    @Test
    fun relativeTimeRoundsAndFloorsAtZero() {
        assertEquals("00:08", GraphGeometry.relativeTime(7.6))
        // A negative offset can't happen from real data, but must not produce
        // a negative-looking label if it ever does.
        assertEquals("00:00", GraphGeometry.relativeTime(-5.0))
    }
}
