package com.codeyam.android.ui

import androidx.compose.ui.graphics.Color
import com.codeyam.android.model.CounterTheme

/**
 * Compose `Color` wrappers over the pure hex tokens in [CounterTheme].
 *
 * The tokens themselves live in the model layer as plain strings so the mappings
 * stay JVM-unit-testable without a rendering stack; this file is the thin
 * platform layer that multiplies them into Compose `Color`s, mirroring how the
 * iOS `Color(hex:)` extension wraps the same shared tokens.
 */
private fun hex(value: String): Color {
    val c = CounterTheme.rgbComponents(value)
    return Color(c.red.toFloat(), c.green.toFloat(), c.blue.toFloat())
}

/**
 * A named `object` rather than an anonymous one: an anonymous object's type is
 * not denotable outside its own file, so its members would be unreachable from
 * every other composable here.
 */
object CounterColors {
    val bg = hex(CounterTheme.BG)
    val surface = hex(CounterTheme.SURFACE)
    val panel = hex(CounterTheme.PANEL)
    val ink = hex(CounterTheme.INK)
    val inkMuted = hex(CounterTheme.INK_MUTED)
    val line = hex(CounterTheme.LINE)
    val lineStrong = hex(CounterTheme.LINE_STRONG)
    val accent = hex(CounterTheme.ACCENT)
    val onAccent = hex(CounterTheme.ON_ACCENT)
}

/** A counter `colorKey` resolved to its Compose dot color. */
fun dotColor(key: String): Color = hex(CounterTheme.dotHex(key))
