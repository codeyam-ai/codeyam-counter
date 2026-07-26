package com.codeyam.android.ui

import com.codeyam.android.model.HapticOption
import com.codeyam.android.model.SoundOption
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the pure option → cue mappings behind the Android feedback bridges
 * ([soundTone] / [hapticSpec]). The real Vibrator / ToneGenerator I/O is device-bound
 * and unverifiable here; these tests pin the *decisions* — every non-`OFF` option
 * produces a cue, `OFF` produces none, and no two options collide onto the same cue.
 */
class AndroidFeedbackTest {

    // OFF is silent: it maps to no tone.
    @Test
    fun testSoundOffMapsToNull() {
        assertNull(soundTone(SoundOption.OFF))
    }

    // Totality: every non-OFF sound resolves to some tone (no un-mapped option).
    @Test
    fun testEveryNonOffSoundMapsToATone() {
        for (option in SoundOption.entries.filter { it != SoundOption.OFF }) {
            assertNotNull("expected a tone for $option", soundTone(option))
        }
    }

    // Distinctness: no two non-OFF sounds share a tone, so each is audibly its own cue.
    @Test
    fun testNonOffSoundsAreDistinct() {
        val tones = SoundOption.entries
            .filter { it != SoundOption.OFF }
            .map { soundTone(it) }
        assertEquals("tones collided: $tones", tones.size, tones.toSet().size)
    }

    // Spot-check a specific mapping so a silent re-wiring of the table is caught.
    @Test
    fun testSoundSpotCheck() {
        assertEquals(android.media.ToneGenerator.TONE_PROP_BEEP, soundTone(SoundOption.TOCK))
    }

    // OFF is silent: it maps to no haptic spec.
    @Test
    fun testHapticOffMapsToNull() {
        assertNull(hapticSpec(HapticOption.OFF))
    }

    // Totality: every non-OFF feel resolves to some spec.
    @Test
    fun testEveryNonOffHapticMapsToASpec() {
        for (option in HapticOption.entries.filter { it != HapticOption.OFF }) {
            assertNotNull("expected a spec for $option", hapticSpec(option))
        }
    }

    // Distinctness: no two non-OFF feels resolve to the same spec.
    @Test
    fun testNonOffHapticsAreDistinct() {
        val specs = HapticOption.entries
            .filter { it != HapticOption.OFF }
            .map { hapticSpec(it) }
        assertEquals("specs collided: $specs", specs.size, specs.toSet().size)
    }

    // SOFT is the gentle feel: a short one-shot at the reduced amplitude.
    @Test
    fun testSoftUsesReducedAmplitude() {
        val spec = hapticSpec(HapticOption.SOFT)
        assertTrue(spec is HapticSpec.OneShot)
        assertEquals(SOFT_AMPLITUDE, (spec as HapticSpec.OneShot).amplitude)
    }

    // DOUBLE is the two-pulse feel: a non-repeating waveform with two on-intervals.
    @Test
    fun testDoubleIsATwoPulseWaveform() {
        val spec = hapticSpec(HapticOption.DOUBLE)
        assertTrue(spec is HapticSpec.Waveform)
        spec as HapticSpec.Waveform
        assertEquals(-1, spec.repeat)
        // Pattern is [wait, on, wait, on] → two vibration pulses.
        assertEquals(4, spec.timings.size)
    }

    // SHARP and BUZZ ride the system default amplitude, distinguished by duration.
    @Test
    fun testSharpAndBuzzUseDefaultAmplitudeButDifferentDurations() {
        val sharp = hapticSpec(HapticOption.SHARP) as HapticSpec.OneShot
        val buzz = hapticSpec(HapticOption.BUZZ) as HapticSpec.OneShot
        assertEquals(DEFAULT_AMPLITUDE, sharp.amplitude)
        assertEquals(DEFAULT_AMPLITUDE, buzz.amplitude)
        assertTrue("buzz should be longer than sharp", buzz.durationMs > sharp.durationMs)
    }
}
