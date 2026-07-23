package com.codeyam.android.ui

import com.codeyam.android.model.AppSettings
import com.codeyam.android.model.CounterModel
import com.codeyam.android.model.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The Compose state layer. The domain rules live (and are tested) in
 * `CounterModel` / `SettingsOverlays`; what is worth pinning here is that this
 * layer *delegates* to them correctly and that its own overlay bookkeeping holds.
 */
class CounterScreenStateTest {

    private fun state(
        settingsOpen: Boolean = false,
        appSettingsOpen: Boolean = false,
        counterListOpen: Boolean = false,
        graphOpen: Boolean = false,
    ): CounterScreenState {
        val store = InMemoryKeyValueStore()
        return CounterScreenState(
            model = CounterModel(store),
            settings = AppSettings(store),
            settingsOpen = settingsOpen,
            appSettingsOpen = appSettingsOpen,
            counterListOpen = counterListOpen,
            graphOpen = graphOpen,
        )
    }

    // MARK: - Seeded overlay flags

    @Test
    fun overlayFlagsDefaultClosed() {
        val s = state()
        assertFalse(s.showSettings)
        assertFalse(s.showAppSettings)
        assertFalse(s.showCounterList)
        assertFalse(s.showGraph)
    }

    /** A scenario seeds a panel open so a static capture can show it. */
    @Test
    fun overlayFlagsAdoptTheirSeededValues() {
        val s = state(settingsOpen = true, graphOpen = true)
        assertTrue(s.showSettings)
        assertTrue(s.showGraph)
        assertFalse(s.showAppSettings)
        assertFalse(s.showCounterList)
    }

    // MARK: - Mutual exclusivity (delegated to SettingsOverlays)

    @Test
    fun openingAppSettingsClosesTheCounterPanel() {
        val s = state(settingsOpen = true)
        s.toggleAppSettings()
        assertTrue(s.showAppSettings)
        assertFalse(s.showSettings)
    }

    @Test
    fun openingTheCounterPanelClosesAppSettings() {
        val s = state(appSettingsOpen = true)
        s.toggleCounterSettings()
        assertTrue(s.showSettings)
        assertFalse(s.showAppSettings)
    }

    /** Closing a panel must not reopen the other one. */
    @Test
    fun closingAPanelLeavesTheOtherClosed() {
        val s = state(appSettingsOpen = true)
        s.toggleAppSettings()
        assertFalse(s.showAppSettings)
        assertFalse(s.showSettings)
    }

    // MARK: - Selection dismisses the per-counter panel

    @Test
    fun selectingACounterClosesTheSettingsPanel() {
        val s = state(settingsOpen = true)
        s.select(s.counters[1].id)
        assertEquals(s.counters[1].id, s.activeCounter.id)
        assertFalse(s.showSettings)
    }

    @Test
    fun addingACounterClosesTheSettingsPanel() {
        val s = state(settingsOpen = true)
        val before = s.counters.size
        s.addCounter()
        assertEquals(before + 1, s.counters.size)
        assertFalse(s.showSettings)
    }

    /** Choosing from the list dismisses the list AND the panel that opened it. */
    @Test
    fun selectingFromTheListClosesBothTheListAndAppSettings() {
        val s = state(appSettingsOpen = true, counterListOpen = true)
        s.selectFromList(s.counters[2].id)
        assertEquals(s.counters[2].id, s.activeCounter.id)
        assertFalse(s.showCounterList)
        assertFalse(s.showAppSettings)
    }

    // MARK: - Mutations reach the model

    @Test
    fun incrementAndSubtractReachTheActiveCounter() {
        val s = state()
        val start = s.activeCounter.count
        s.increment()
        assertEquals(start + 1, s.activeCounter.count)
        s.subtract()
        assertEquals(start, s.activeCounter.count)
    }

    /** RESET doubles as UNDO RESET: the second press restores the pre-reset value. */
    @Test
    fun resetOrUndoDispatchesByPendingUndo() {
        val s = state()
        s.increment()
        s.increment()
        assertEquals(2, s.activeCounter.count)

        s.resetOrUndo()
        assertEquals(0, s.activeCounter.count)
        assertTrue(s.canUndoReset)

        s.resetOrUndo()
        assertEquals(2, s.activeCounter.count)
        assertFalse(s.canUndoReset)
    }

    @Test
    fun selectNextAndPreviousMoveThroughTheCounters() {
        val s = state()
        val first = s.activeCounter.id
        s.selectNext()
        val second = s.activeCounter.id
        assertTrue(first != second)
        s.selectPrevious()
        assertEquals(first, s.activeCounter.id)
    }

    // MARK: - Handedness resolution

    @Test
    fun leftHandedFollowsTheAppDefaultWithoutAnOverride() {
        val s = state()
        assertFalse(s.leftHanded)
        s.settings.defaultLeftHanded = true
        assertTrue(s.leftHanded)
    }

    @Test
    fun aPerCounterHandednessOverrideBeatsTheAppDefault() {
        val s = state()
        s.settings.defaultLeftHanded = true
        val active = s.activeCounter
        s.updateActiveCounter(
            name = active.name,
            colorKey = active.colorKey,
            allowNegative = active.allowNegative,
            step = active.step,
            handednessOverride = false,
            soundOverride = null,
            incrementHapticOverride = null,
            decrementHapticOverride = null,
        )
        assertFalse(s.leftHanded)
    }
}
