package com.codeyam.android.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Ported from iOS `FeedbackTests` + `CounterFeedbackOverrideTests`. Covers the
 * [SystemCounterFeedback] option gating, the [NoopCounterFeedback] no-op, and
 * `Counter.hasFeedbackOverride`.
 */
class FeedbackTest {

    /** A [SystemCounterFeedback] with spy emitters recording the options they emit. */
    private class Spied {
        val haptics = mutableListOf<HapticOption>()
        val sounds = mutableListOf<SoundOption>()
        val feedback = SystemCounterFeedback(
            emitHaptic = { haptics.add(it) },
            emitSound = { sounds.add(it) },
        )
    }

    // A non-off haptic with sound off fires only the haptic emitter, carrying the
    // chosen feel.
    @Test
    fun testHapticOnlyFiresHapticWithFeel() {
        val s = Spied()
        s.feedback.changed(sound = SoundOption.OFF, haptic = HapticOption.SHARP)
        assertEquals(listOf(HapticOption.SHARP), s.haptics)
        assertEquals(emptyList<SoundOption>(), s.sounds)
    }

    // A non-off sound with haptic off fires only the sound emitter, carrying the
    // chosen sound.
    @Test
    fun testSoundOnlyFiresSoundWithChoice() {
        val s = Spied()
        s.feedback.changed(sound = SoundOption.BLOOP, haptic = HapticOption.OFF)
        assertEquals(emptyList<HapticOption>(), s.haptics)
        assertEquals(listOf(SoundOption.BLOOP), s.sounds)
    }

    // Both non-off → both emitters fire once with their respective choices.
    @Test
    fun testBothOptionsFireBoth() {
        val s = Spied()
        s.feedback.changed(sound = SoundOption.TOCK, haptic = HapticOption.SOFT)
        assertEquals(listOf(HapticOption.SOFT), s.haptics)
        assertEquals(listOf(SoundOption.TOCK), s.sounds)
    }

    // Both off → nothing fires.
    @Test
    fun testBothOffFiresNothing() {
        val s = Spied()
        s.feedback.changed(sound = SoundOption.OFF, haptic = HapticOption.OFF)
        assertEquals(emptyList<HapticOption>(), s.haptics)
        assertEquals(emptyList<SoundOption>(), s.sounds)
    }

    // Every qualitatively-distinct feel gates the same way: non-OFF, so each fires
    // the haptic emitter once carrying its own choice.
    @Test
    fun testAllDistinctFeelsAreTreatedAsNonOff() {
        val s = Spied()
        s.feedback.changed(sound = SoundOption.OFF, haptic = HapticOption.SOFT)
        s.feedback.changed(sound = SoundOption.OFF, haptic = HapticOption.SHARP)
        s.feedback.changed(sound = SoundOption.OFF, haptic = HapticOption.DOUBLE)
        s.feedback.changed(sound = SoundOption.OFF, haptic = HapticOption.BUZZ)
        assertEquals(
            listOf(HapticOption.SOFT, HapticOption.SHARP, HapticOption.DOUBLE, HapticOption.BUZZ),
            s.haptics,
        )
    }

    // The no-op default implementation never touches its arguments — a smoke check
    // that calling it with any options is safe and silent.
    @Test
    fun testNoopFeedbackDoesNothing() {
        val noop = NoopCounterFeedback()
        noop.changed(sound = SoundOption.DING, haptic = HapticOption.DOUBLE)
        noop.changed(sound = SoundOption.OFF, haptic = HapticOption.OFF)
    }

    // --- Counter.hasFeedbackOverride (from CounterFeedbackOverrideTests) ---

    // A counter left on pure app-wide defaults pins nothing, so the section stays collapsed.
    @Test
    fun testNoOverridesReturnsFalse() {
        val counter = Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0)
        assertFalse(counter.hasFeedbackOverride)
    }

    // A handedness override alone is enough to open the section.
    @Test
    fun testHandednessOverrideAloneReturnsTrue() {
        val counter = Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0, handednessOverride = true)
        assertTrue(counter.hasFeedbackOverride)
    }

    // A sound override alone is enough to open the section.
    @Test
    fun testSoundOverrideAloneReturnsTrue() {
        val counter = Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0, soundOverride = SoundOption.DING)
        assertTrue(counter.hasFeedbackOverride)
    }

    // An increment-haptic override alone is enough to open the section.
    @Test
    fun testIncrementHapticOverrideAloneReturnsTrue() {
        val counter = Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0, incrementHapticOverride = HapticOption.SHARP)
        assertTrue(counter.hasFeedbackOverride)
    }

    // A decrement-haptic override alone is enough to open the section.
    @Test
    fun testDecrementHapticOverrideAloneReturnsTrue() {
        val counter = Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0, decrementHapticOverride = HapticOption.SOFT)
        assertTrue(counter.hasFeedbackOverride)
    }

    // An explicit OFF sound is a deliberate pin, not the absence of one, so it still
    // counts as an override — a non-null value, not the default fall-through.
    @Test
    fun testExplicitOffSoundOverrideReturnsTrue() {
        val counter = Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0, soundOverride = SoundOption.OFF)
        assertTrue(counter.hasFeedbackOverride)
    }

    // Every override pinned at once still reads true.
    @Test
    fun testAllOverridesSetReturnsTrue() {
        val counter = Counter(
            id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0,
            handednessOverride = false, soundOverride = SoundOption.OFF,
            incrementHapticOverride = HapticOption.DOUBLE, decrementHapticOverride = HapticOption.BUZZ,
        )
        assertTrue(counter.hasFeedbackOverride)
    }

    // A blank slot (no name, no overrides) leaves the section collapsed.
    @Test
    fun testBlankSlotReturnsFalse() {
        val counter = Counter(id = 1, name = "", count = 0, colorKey = "", order = 0)
        assertFalse(counter.hasFeedbackOverride)
    }
}
