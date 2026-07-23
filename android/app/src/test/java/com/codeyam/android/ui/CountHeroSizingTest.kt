package com.codeyam.android.ui

import androidx.compose.ui.unit.sp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The hero's auto-shrink rule. iOS gets this from `minimumScaleFactor(0.2)`,
 * which Compose has no equivalent for — so the step table is hand-written and
 * therefore worth pinning.
 */
class CountHeroSizingTest {

    @Test
    fun oneAndTwoDigitCountsUseTheFullSize() {
        assertEquals(280.sp, autoSizedFontSize("0"))
        assertEquals(280.sp, autoSizedFontSize("42"))
    }

    @Test
    fun longerNumeralsStepDown() {
        assertEquals(220.sp, autoSizedFontSize("100"))
        assertEquals(170.sp, autoSizedFontSize("1000"))
        assertEquals(140.sp, autoSizedFontSize("10000"))
    }

    @Test
    fun anythingLongerFallsToTheSmallestStep() {
        assertEquals(110.sp, autoSizedFontSize("123456"))
        assertEquals(110.sp, autoSizedFontSize("1,234,567"))
    }

    /**
     * Measuring the FORMATTED string is the point: the grouping separator makes
     * `8421` render as `8,421`, which is five characters wide, not four.
     */
    @Test
    fun groupingSeparatorsCountTowardTheWidth() {
        assertEquals(autoSizedFontSize("8,421"), autoSizedFontSize(formatCount(8421)))
        assertTrue(autoSizedFontSize(formatCount(8421)).value < autoSizedFontSize("8421").value)
    }

    /** A leading minus is a character too, so a negative shrinks one step earlier. */
    @Test
    fun theMinusSignCountsTowardTheWidth() {
        assertTrue(autoSizedFontSize(formatCount(-100)).value < autoSizedFontSize(formatCount(100)).value)
    }

    @Test
    fun sizeNeverIncreasesAsTheNumeralGrows() {
        val sizes = listOf("1", "12", "123", "1234", "12345", "123456")
            .map { autoSizedFontSize(it).value }
        assertEquals(sizes.sortedDescending(), sizes)
    }
}
