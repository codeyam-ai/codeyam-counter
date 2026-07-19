package com.codeyam.android.model

/**
 * The sound played on a count change. `OFF` is silent; the rest map to distinct
 * system sounds (resolved in [SystemCounterFeedback]). `rawValue` is the
 * persisted/seeded token; [label] is the uppercased picker label.
 */
enum class SoundOption {
    OFF, TOCK, POP, CLICK, BLOOP, DING;

    val rawValue: String get() = name.lowercase()
    val label: String get() = rawValue.uppercase()

    companion object {
        /** The case for a persisted rawValue, or null when unrecognized. */
        fun fromRawValue(raw: String?): SoundOption? =
            entries.firstOrNull { it.rawValue == raw }
    }
}

/**
 * The haptic fired on a count change. `OFF` is silent; the rest are *qualitatively
 * distinct* feels (resolved in [SystemCounterFeedback]), all fired strong so none
 * reads as merely "weak":
 *   - `SOFT` — a cushioned impact tap at full intensity
 *   - `SHARP` — a crisp, hard-edged impact tap at full intensity
 *   - `DOUBLE` — a rising two-tap notification pattern
 *   - `BUZZ` — a three-tap notification rumble
 * The old `light`/`medium`/`heavy` amplitude ladder is gone: those varied only in
 * strength (hard to tell apart) and are migrated to their nearest surviving feel
 * by [resolve]. The default directional pairing (increment `SHARP`, decrement
 * `SOFT`) keeps the crisp-up / dull-down distinction unchanged.
 */
enum class HapticOption {
    OFF, SOFT, SHARP, DOUBLE, BUZZ;

    val rawValue: String get() = name.lowercase()
    val label: String get() = rawValue.uppercase()

    companion object {
        /**
         * Resolve a persisted rawValue (a per-direction key, the legacy single key,
         * or a [Counter] override) into a current case, mapping the removed
         * amplitude/`rigid` values to their nearest surviving feel. Returns null only
         * for a genuinely unknown token, so callers can fall back to a default.
         */
        fun resolve(raw: String?): HapticOption? {
            if (raw == null) return null
            entries.firstOrNull { it.rawValue == raw }?.let { return it }
            return when (raw) {
                "rigid", "heavy", "medium" -> SHARP
                "light" -> SOFT
                else -> null
            }
        }
    }
}

/**
 * System-wide app defaults, consolidated into one observable store. Ported from
 * iOS `AppSettings`.
 *
 * Seeding contract (mirrors [CounterModel]): the seeder writes a scenario's
 * preferences into the store before the app starts, so this store reads those same
 * keys in its constructor and each scenario observes its seeded defaults from the
 * first frame:
 *   - `leftHanded` — the mirrored bottom-bar layout
 *   - `soundOption` — which sound (if any) plays on each increment/subtract
 *   - `incrementHapticOption` — which haptic (if any) fires on each increment
 *   - `decrementHapticOption` — which haptic (if any) fires on each subtract
 * Handedness defaults off; sound defaults to `OFF`. The two haptics default to a
 * deliberately *distinct* pairing — **increment `SHARP`, decrement `SOFT`** — so a
 * fresh install feels a crisp tap when adding and a dull tap when subtracting.
 *
 * Legacy migration: a user who tuned the pre-split single haptic carries the old
 * `hapticOption` key and neither new key. When a direction's new key is absent but
 * that legacy key is present, both directions seed from the legacy value. New
 * per-direction keys win once written.
 *
 * A release build requires the app's own provenance marker
 * ([SeedPolicy.REQUIRE_PROVENANCE]) before adopting any of these keys — the same
 * gate [CounterModel] applies, sharing the one marker across both stores. Under
 * that policy an unstamped store starts from the built-in defaults, so stray
 * injected/stale scenario keys are ignored; a real user's own changed settings are
 * trusted once the app has persisted (and stamped the marker). Debug builds keep
 * trusting injected state.
 *
 * Each setter persists its value and stamps the provenance marker, mirroring the
 * Swift `didSet`. The property *initializers* below assign the backing field
 * directly (Kotlin does not route an initializer through the custom setter), so the
 * initial load neither writes back nor stamps — exactly like Swift's `didSet` not
 * firing during `init`.
 */
class AppSettings(
    private val store: KeyValueStore = InMemoryKeyValueStore(),
    policy: SeedPolicy = SeedPolicy.TRUST_INJECTED,
) {
    /** Whether externally-supplied state is trusted; computed once up front. */
    private val trusted: Boolean = policy.trustsStore(store)

    var defaultLeftHanded: Boolean =
        if (trusted) store.getBoolean(LEFT_HANDED_KEY) else false
        set(value) {
            field = value
            store.putBoolean(LEFT_HANDED_KEY, value)
            SeedPolicy.stampProvenance(store)
        }

    var soundOption: SoundOption =
        if (trusted) SoundOption.fromRawValue(store.getString(SOUND_OPTION_KEY)) ?: SoundOption.OFF
        else SoundOption.OFF
        set(value) {
            field = value
            store.putString(SOUND_OPTION_KEY, value.rawValue)
            SeedPolicy.stampProvenance(store)
        }

    var incrementHapticOption: HapticOption =
        if (trusted) loadHaptic(store, INCREMENT_HAPTIC_OPTION_KEY, DEFAULT_INCREMENT_HAPTIC)
        else DEFAULT_INCREMENT_HAPTIC
        set(value) {
            field = value
            store.putString(INCREMENT_HAPTIC_OPTION_KEY, value.rawValue)
            SeedPolicy.stampProvenance(store)
        }

    var decrementHapticOption: HapticOption =
        if (trusted) loadHaptic(store, DECREMENT_HAPTIC_OPTION_KEY, DEFAULT_DECREMENT_HAPTIC)
        else DEFAULT_DECREMENT_HAPTIC
        set(value) {
            field = value
            store.putString(DECREMENT_HAPTIC_OPTION_KEY, value.rawValue)
            SeedPolicy.stampProvenance(store)
        }

    companion object {
        const val LEFT_HANDED_KEY = "leftHanded"
        const val SOUND_OPTION_KEY = "soundOption"
        const val INCREMENT_HAPTIC_OPTION_KEY = "incrementHapticOption"
        const val DECREMENT_HAPTIC_OPTION_KEY = "decrementHapticOption"

        /** The pre-split single-haptic key. Read only as a migration fallback. */
        const val LEGACY_HAPTIC_OPTION_KEY = "hapticOption"

        /** The built-in default increment haptic — a crisp `SHARP` tap. */
        val DEFAULT_INCREMENT_HAPTIC = HapticOption.SHARP

        /** The built-in default decrement haptic — a dull `SOFT` tap, distinct from increment. */
        val DEFAULT_DECREMENT_HAPTIC = HapticOption.SOFT

        /**
         * Resolve one direction's haptic at launch: the new per-direction key wins;
         * otherwise migrate the legacy single `hapticOption` key (both directions
         * share it) if present; otherwise the built-in default for that direction.
         */
        private fun loadHaptic(store: KeyValueStore, key: String, fallback: HapticOption): HapticOption {
            HapticOption.resolve(store.getString(key))?.let { return it }
            HapticOption.resolve(store.getString(LEGACY_HAPTIC_OPTION_KEY))?.let { return it }
            return fallback
        }
    }
}
