package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.ui.Modifier
import app.cash.paparazzi.DeviceConfig
import app.cash.paparazzi.Paparazzi
import org.junit.Rule
import org.junit.Test

/**
 * Off-device render of [CountHero] via Paparazzi.
 *
 * Paparazzi draws a `@Composable` on the JVM with no emulator, which is what
 * makes a Compose component capturable in isolation the way the SwiftUI side
 * uses its `*Isolated.swift` harness. This test is the worked example that keeps
 * the Paparazzi wiring honest: it runs in CI on every push, so a change that
 * breaks off-device rendering of a component fails here rather than silently
 * making component capture impossible.
 *
 * `autoSizedFontSize` steps the numeral down as digits accumulate, so the two
 * cases below bracket that behaviour — a two-digit count at the full 280sp and a
 * four-digit grouped count at 170sp.
 */
class CountHeroSnapshotTest {

    @get:Rule
    val paparazzi = Paparazzi(deviceConfig = DeviceConfig.PIXEL_5)

    // Renders the hero numeral at its base size — the one- or two-digit case
    // every counter starts in.
    @Test
    fun countHeroRendersATwoDigitCount() {
        paparazzi.snapshot {
            CountHero(
                count = 7,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(CounterColors.bg),
            )
        }
    }

    // Renders a grouped four-digit count, exercising the step-down that keeps a
    // long numeral from clipping instead of shrinking.
    @Test
    fun countHeroRendersAGroupedFourDigitCount() {
        paparazzi.snapshot {
            CountHero(
                count = 8421,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(CounterColors.bg),
            )
        }
    }
}
