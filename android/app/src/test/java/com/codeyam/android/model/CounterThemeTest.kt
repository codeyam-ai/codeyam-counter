package com.codeyam.android.model

import org.junit.Assert.assertEquals
import org.junit.Test

/** Ported from iOS `ThemeTests` — the pure `dotHex` / `rgbComponents` mappings. */
class CounterThemeTest {

    private fun assertRgb(hex: String, expected: Triple<Double, Double, Double>) {
        val c = CounterTheme.rgbComponents(hex)
        assertEquals(expected.first, c.red, 0.001)
        assertEquals(expected.second, c.green, 0.001)
        assertEquals(expected.third, c.blue, 0.001)
    }

    // Pure black and white sit at the ends of the 0..1 range.
    @Test
    fun testParsesBlackAndWhite() {
        assertRgb("000000", Triple(0.0, 0.0, 0.0))
        assertRgb("FFFFFF", Triple(1.0, 1.0, 1.0))
    }

    // The lime accent decomposes into its three channels.
    @Test
    fun testParsesAccentLime() {
        assertRgb("D5F560", Triple(213.0 / 255, 245.0 / 255, 96.0 / 255))
    }

    // A leading "#" is tolerated and parses identically.
    @Test
    fun testToleratesLeadingHash() {
        assertRgb("#4DB5FF", Triple(77.0 / 255, 181.0 / 255, 255.0 / 255))
    }

    // Parsing is case-insensitive: lower- and upper-case hex agree.
    @Test
    fun testIsCaseInsensitive() {
        val lower = CounterTheme.rgbComponents("ff7a4d")
        val upper = CounterTheme.rgbComponents("FF7A4D")
        assertEquals(lower.red, upper.red, 0.0001)
        assertEquals(lower.green, upper.green, 0.0001)
        assertEquals(lower.blue, upper.blue, 0.0001)
    }

    // Each isolated channel maps to the expected fraction of 255.
    @Test
    fun testIsolatesIndividualChannels() {
        assertRgb("FF0000", Triple(1.0, 0.0, 0.0))
        assertRgb("00FF00", Triple(0.0, 1.0, 0.0))
        assertRgb("0000FF", Triple(0.0, 0.0, 1.0))
    }

    // Each known colorKey maps to its design-token hex.
    @Test
    fun testDotHexMapsKnownKeys() {
        assertEquals("D5F560", CounterTheme.dotHex("lime"))
        assertEquals("FF7A4D", CounterTheme.dotHex("coffee"))
        assertEquals("4DB5FF", CounterTheme.dotHex("steps"))
        assertEquals("C98BFF", CounterTheme.dotHex("bugs"))
    }

    // An unknown colorKey falls back to the lime accent rather than crashing.
    @Test
    fun testDotHexFallsBackToLimeForUnknownKey() {
        assertEquals("D5F560", CounterTheme.dotHex("chartreuse"))
        assertEquals("D5F560", CounterTheme.dotHex(""))
    }
}
