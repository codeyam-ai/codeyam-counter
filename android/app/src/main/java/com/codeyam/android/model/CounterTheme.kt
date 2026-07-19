package com.codeyam.android.model

/**
 * The three 0..1 color channels parsed from a hex string. A plain holder (rather
 * than a platform `Color`) so the parse is unit-testable without rendering.
 */
data class RgbComponents(val red: Double, val green: Double, val blue: Double)

/**
 * Design tokens lifted from the CodeYam Counter mockup, ported from iOS
 * `CounterTheme`. Kept free of any Compose `Color` type so the pure mappings
 * ([dotHex], [rgbComponents]) stay JVM-unit-testable; the Compose `Color` wrapper
 * is added by the UI layer, which multiplies these tokens into `Color(...)`.
 */
object CounterTheme {
    const val BG = "0C0D08"
    const val SURFACE = "15170F"
    const val PANEL = "10110B"
    const val INK = "EAE8E0"
    const val INK_MUTED = "8D8F80"
    const val LINE = "2A2C20"
    const val LINE_STRONG = "43463A"
    const val ACCENT = "D5F560"
    const val ON_ACCENT = "0B0A08"

    /**
     * The full swatch palette offered in the settings panel, in display order.
     * Each key resolves through [dotHex].
     */
    val palette = listOf(
        "lime", "coffee", "steps", "bugs", "mint", "rose",
        "amber", "teal", "indigo", "magenta", "crimson", "grass",
    )

    /**
     * Pure mapping from a counter `colorKey` to its hex string. Unknown keys fall
     * back to the lime accent.
     */
    fun dotHex(key: String): String = when (key) {
        "lime" -> "D5F560"
        "coffee" -> "FF7A4D"
        "steps" -> "4DB5FF"
        "bugs" -> "C98BFF"
        "mint" -> "5BE3B0"
        "rose" -> "FF6B8A"
        "amber" -> "F5C84B"
        "teal" -> "33C9D6"
        "indigo" -> "8E7BFF"
        "magenta" -> "FF5CC8"
        "crimson" -> "FF4D4D"
        "grass" -> "7BD84B"
        else -> "D5F560"
    }

    /**
     * Pure hex → RGB parse. Accepts an optional leading "#" and is
     * case-insensitive; returns each channel in the 0..1 range.
     */
    fun rgbComponents(hex: String): RgbComponents {
        val cleaned = hex.trim().removePrefix("#")
        val value = cleaned.toLongOrNull(16) ?: 0L
        val r = ((value and 0xFF0000) shr 16).toDouble() / 255.0
        val g = ((value and 0x00FF00) shr 8).toDouble() / 255.0
        val b = (value and 0x0000FF).toDouble() / 255.0
        return RgbComponents(r, g, b)
    }
}
