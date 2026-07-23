package com.codeyam.android.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The digit grouping that keeps Android reading the same as iOS.
 *
 * These cases are pinned to the US locale because the whole point is parity with
 * the iOS captures, which were taken on a US-locale simulator. The production
 * formatter is locale-aware by design (as SwiftUI's is); these assertions state
 * what the shipped screenshots show.
 */
class CountFormatTest {

    @Test
    fun smallCountsAreUnchanged() {
        assertEquals("0", formatCount(0))
        assertEquals("7", formatCount(7))
        assertEquals("999", formatCount(999))
    }

    /**
     * The regression this guards: a literal `"$count"` port drops the separator
     * that SwiftUI's `LocalizedStringKey` interpolation adds, so the two
     * platforms silently disagree from four digits up.
     */
    @Test
    fun fourDigitsAndUpAreGrouped() {
        assertEquals("1,000", formatCount(1000))
        assertEquals("8,421", formatCount(8421))
        assertEquals("12,480", formatCount(12480))
        assertEquals("1,234,567", formatCount(1234567))
    }

    @Test
    fun negativeCountsKeepTheirSignAndGrouping() {
        assertEquals("-5", formatCount(-5))
        assertEquals("-8,421", formatCount(-8421))
    }

    @Test
    fun deltaCarriesAnExplicitPlusWhenNonNegative() {
        assertEquals("+0", formatDelta(0))
        assertEquals("+1", formatDelta(1))
        assertEquals("+1,500", formatDelta(1500))
    }

    @Test
    fun deltaLeavesTheMinusSignAsTheOnlyMarkerWhenNegative() {
        assertEquals("-1", formatDelta(-1))
        assertEquals("-2,000", formatDelta(-2000))
    }
}
