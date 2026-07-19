package com.codeyam.android.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Ported from iOS `SettingsOverlaysTests`. The "only one settings panel open at a
 * time" rule — the exclusivity the two tap sites delegate here.
 */
class SettingsOverlaysTest {

    // Nothing is open out of the box.
    @Test
    fun testNothingIsOpenByDefault() {
        val overlays = SettingsOverlays()
        assertFalse(overlays.counterSettings)
        assertFalse(overlays.appSettings)
    }

    // Opening App Settings from a clean screen just opens it.
    @Test
    fun testOpeningAppSettingsFromClosedOpensIt() {
        val next = SettingsOverlays().togglingAppSettings()
        assertEquals(SettingsOverlays(counterSettings = false, appSettings = true), next)
    }

    // Opening the per-counter panel from a clean screen just opens it.
    @Test
    fun testOpeningCounterSettingsFromClosedOpensIt() {
        val next = SettingsOverlays().togglingCounterSettings()
        assertEquals(SettingsOverlays(counterSettings = true, appSettings = false), next)
    }

    // The core rule: opening App Settings while the per-counter panel is up
    // force-closes the per-counter panel, so the two are never both on screen.
    @Test
    fun testOpeningAppSettingsClosesTheCounterPanel() {
        val next = SettingsOverlays(counterSettings = true, appSettings = false).togglingAppSettings()
        assertEquals(SettingsOverlays(counterSettings = false, appSettings = true), next)
    }

    // The same rule in the other direction.
    @Test
    fun testOpeningCounterSettingsClosesAppSettings() {
        val next = SettingsOverlays(counterSettings = false, appSettings = true).togglingCounterSettings()
        assertEquals(SettingsOverlays(counterSettings = true, appSettings = false), next)
    }

    // Toggling an already-open panel closes it — and does NOT open the other one.
    @Test
    fun testTogglingOpenAppSettingsClosesItAndOpensNothing() {
        val next = SettingsOverlays(counterSettings = false, appSettings = true).togglingAppSettings()
        assertEquals(SettingsOverlays(counterSettings = false, appSettings = false), next)
    }

    // The closing direction for the per-counter panel.
    @Test
    fun testTogglingOpenCounterSettingsClosesItAndOpensNothing() {
        val next = SettingsOverlays(counterSettings = true, appSettings = false).togglingCounterSettings()
        assertEquals(SettingsOverlays(counterSettings = false, appSettings = false), next)
    }

    // Whatever the starting state, neither toggle can ever leave both panels open.
    @Test
    fun testNoToggleEverLeavesBothOpen() {
        for (counter in listOf(true, false)) {
            for (app in listOf(true, false)) {
                val start = SettingsOverlays(counterSettings = counter, appSettings = app)
                for (next in listOf(start.togglingAppSettings(), start.togglingCounterSettings())) {
                    assertFalse("both open after toggling from $start", next.counterSettings && next.appSettings)
                }
            }
        }
    }
}
