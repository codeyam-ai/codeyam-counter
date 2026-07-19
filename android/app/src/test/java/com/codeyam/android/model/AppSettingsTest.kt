package com.codeyam.android.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ported from iOS `AppSettingsTests` — defaults, seeding, legacy migration, persistence. */
class AppSettingsTest {

    private fun makeStore() = InMemoryKeyValueStore()

    // A fresh store with nothing seeded is right-handed, silent, and carries the
    // distinct default haptic pairing: increment Sharp, decrement Soft.
    @Test
    fun testDefaultsAreRightHandedSilentWithDistinctHaptics() {
        val settings = AppSettings(makeStore())
        assertFalse(settings.defaultLeftHanded)
        assertEquals(SoundOption.OFF, settings.soundOption)
        assertEquals(HapticOption.SHARP, settings.incrementHapticOption)
        assertEquals(HapticOption.SOFT, settings.decrementHapticOption)
    }

    // The "must feel different" guarantee, pinned: the two default haptics are
    // qualitatively distinct, not the same tap.
    @Test
    fun testDefaultHapticsAreDistinct() {
        val settings = AppSettings(makeStore())
        assertNotEquals(settings.incrementHapticOption, settings.decrementHapticOption)
    }

    // The store reads seeded preferences, including the string-injected form the
    // seeder writes (enum rawValue via string), including the soft/sharp values.
    @Test
    fun testReadsSeededStringPreferences() {
        val store = makeStore()
        store.putString(AppSettings.LEFT_HANDED_KEY, "1")
        store.putString(AppSettings.SOUND_OPTION_KEY, "ding")
        store.putString(AppSettings.INCREMENT_HAPTIC_OPTION_KEY, "soft")
        store.putString(AppSettings.DECREMENT_HAPTIC_OPTION_KEY, "sharp")
        val settings = AppSettings(store)
        assertTrue(settings.defaultLeftHanded)
        assertEquals(SoundOption.DING, settings.soundOption)
        assertEquals(HapticOption.SOFT, settings.incrementHapticOption)
        assertEquals(HapticOption.SHARP, settings.decrementHapticOption)
    }

    // An unrecognized option rawValue falls back to the built-in default; a missing
    // haptic key likewise falls back (to its direction's default).
    @Test
    fun testUnknownOptionFallsBackToDefault() {
        val store = makeStore()
        store.putString(AppSettings.SOUND_OPTION_KEY, "kazoo")
        store.putString(AppSettings.INCREMENT_HAPTIC_OPTION_KEY, "wobble")
        // decrement key left unset entirely
        val settings = AppSettings(store)
        assertEquals(SoundOption.OFF, settings.soundOption)
        assertEquals(HapticOption.SHARP, settings.incrementHapticOption)
        assertEquals(HapticOption.SOFT, settings.decrementHapticOption)
    }

    // Legacy migration: a user who tuned the pre-split single hapticOption key (and
    // has neither new key) adopts that value for BOTH directions. A stored amplitude
    // value (heavy) migrates to its nearest surviving feel (sharp).
    @Test
    fun testLegacyHapticKeyMigratesToBothDirections() {
        val store = makeStore()
        store.putString(AppSettings.LEGACY_HAPTIC_OPTION_KEY, "heavy")
        val settings = AppSettings(store)
        assertEquals(HapticOption.SHARP, settings.incrementHapticOption)
        assertEquals(HapticOption.SHARP, settings.decrementHapticOption)
    }

    // A legacy "off" is respected — both directions stay silent, not reset to the
    // new Sharp/Soft defaults.
    @Test
    fun testLegacyHapticOffMigratesToBothOff() {
        val store = makeStore()
        store.putString(AppSettings.LEGACY_HAPTIC_OPTION_KEY, "off")
        val settings = AppSettings(store)
        assertEquals(HapticOption.OFF, settings.incrementHapticOption)
        assertEquals(HapticOption.OFF, settings.decrementHapticOption)
    }

    // A new per-direction key wins over the legacy key when both are present. The
    // legacy amplitude value (heavy) still migrates to sharp.
    @Test
    fun testNewHapticKeyWinsOverLegacy() {
        val store = makeStore()
        store.putString(AppSettings.LEGACY_HAPTIC_OPTION_KEY, "heavy")
        store.putString(AppSettings.INCREMENT_HAPTIC_OPTION_KEY, "double")
        val settings = AppSettings(store)
        assertEquals(HapticOption.DOUBLE, settings.incrementHapticOption)  // new key
        assertEquals(HapticOption.SHARP, settings.decrementHapticOption)   // migrated legacy
    }

    // Changing a setting persists it: a second store over the same backing reads the
    // written values back.
    @Test
    fun testPersistsChangesAcrossReload() {
        val store = makeStore()
        val settings = AppSettings(store)
        settings.defaultLeftHanded = true
        settings.soundOption = SoundOption.POP
        settings.incrementHapticOption = HapticOption.DOUBLE
        settings.decrementHapticOption = HapticOption.BUZZ

        val reloaded = AppSettings(store)
        assertTrue(reloaded.defaultLeftHanded)
        assertEquals(SoundOption.POP, reloaded.soundOption)
        assertEquals(HapticOption.DOUBLE, reloaded.incrementHapticOption)
        assertEquals(HapticOption.BUZZ, reloaded.decrementHapticOption)
    }

    // Each key is independent — changing one does not disturb the others.
    @Test
    fun testOptionsAreIndependent() {
        val store = makeStore()
        val settings = AppSettings(store)
        settings.incrementHapticOption = HapticOption.DOUBLE
        assertEquals(SoundOption.OFF, settings.soundOption)
        assertFalse(settings.defaultLeftHanded)
        assertEquals(HapticOption.DOUBLE, settings.incrementHapticOption)
        assertEquals(HapticOption.SOFT, settings.decrementHapticOption)  // untouched default
    }

    // A release-policy launch over an unstamped store ignores injected keys
    // (including the legacy key) and starts from the Sharp/Soft defaults.
    @Test
    fun testReleasePolicyIgnoresSeededHapticsWithoutProvenance() {
        val store = makeStore()
        store.putString(AppSettings.INCREMENT_HAPTIC_OPTION_KEY, "double")
        store.putString(AppSettings.LEGACY_HAPTIC_OPTION_KEY, "off")
        val settings = AppSettings(store, policy = SeedPolicy.REQUIRE_PROVENANCE)
        assertEquals(HapticOption.SHARP, settings.incrementHapticOption)
        assertEquals(HapticOption.SOFT, settings.decrementHapticOption)
    }

    // resolve(...) migrates removed amplitude/rigid rawValues to their nearest
    // surviving feel, passes current cases through, and rejects unknown tokens.
    @Test
    fun testResolveMigratesRemovedRawValues() {
        assertEquals(HapticOption.SHARP, HapticOption.resolve("rigid"))
        assertEquals(HapticOption.SHARP, HapticOption.resolve("heavy"))
        assertEquals(HapticOption.SHARP, HapticOption.resolve("medium"))
        assertEquals(HapticOption.SOFT, HapticOption.resolve("light"))
        assertEquals(HapticOption.SOFT, HapticOption.resolve("soft"))
        assertEquals(HapticOption.SHARP, HapticOption.resolve("sharp"))
        assertEquals(HapticOption.DOUBLE, HapticOption.resolve("double"))
        assertEquals(HapticOption.BUZZ, HapticOption.resolve("buzz"))
        assertNull(HapticOption.resolve("nonsense"))
        assertNull(HapticOption.resolve(null))
    }

    // The option enums expose the full choice sets the settings picker renders.
    @Test
    fun testOptionCasesCoverTheChoiceSets() {
        assertEquals(
            listOf(SoundOption.OFF, SoundOption.TOCK, SoundOption.POP, SoundOption.CLICK, SoundOption.BLOOP, SoundOption.DING),
            SoundOption.entries.toList(),
        )
        assertEquals(
            listOf(HapticOption.OFF, HapticOption.SOFT, HapticOption.SHARP, HapticOption.DOUBLE, HapticOption.BUZZ),
            HapticOption.entries.toList(),
        )
        assertEquals("DING", SoundOption.DING.label)
        assertEquals("SOFT", HapticOption.SOFT.label)
        assertEquals("SHARP", HapticOption.SHARP.label)
        assertEquals("DOUBLE", HapticOption.DOUBLE.label)
        assertEquals("BUZZ", HapticOption.BUZZ.label)
    }
}
