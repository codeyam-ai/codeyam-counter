package com.codeyam.android.model

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * A single named tally the user increments, subtracts, and resets. Ported from iOS
 * `Counter`. `step` is always at least 1; legacy persisted counters written before
 * a field existed decode to the same defaults as the constructor.
 */
data class Counter(
    var id: Int,
    var name: String,
    var count: Int,
    /** One of "lime", "coffee", "steps", "bugs" — drives the switcher dot color. */
    var colorKey: String,
    /**
     * When false, `subtract` clamps at zero. Defaults to true (subtract may go
     * negative) per the product decision; the settings panel toggles it.
     */
    var allowNegative: Boolean = true,
    /**
     * How much each increment/subtract changes the count (the "count by" amount).
     * Always at least 1; the `init` block clamps whatever is constructed or copied,
     * mirroring Swift's `max(1, step)` in `init`. Direct reassignment does not
     * re-clamp (matching the plain Swift stored property); the mutation sites in
     * [CounterModel] clamp at the call site.
     */
    var step: Int = 1,
    var order: Int,
    /**
     * Per-counter override of the app-wide handedness default. `null` follows
     * `AppSettings.defaultLeftHanded`; `true` pins the mirrored left-handed layout
     * while this counter is active, `false` pins right-handed.
     */
    var handednessOverride: Boolean? = null,
    /**
     * Per-counter override of the app-wide sound-on-change default. `null` follows
     * `AppSettings.soundOption`; any value (including an explicit `OFF`) pins that
     * sound for this counter. Persisted as its `rawValue` string.
     */
    var soundOverride: SoundOption? = null,
    /**
     * Per-counter override of the app-wide increment haptic default. `null` follows
     * `AppSettings.incrementHapticOption`; any value (including `OFF`) pins that
     * haptic for increments. Persisted as its `rawValue` string.
     */
    var incrementHapticOverride: HapticOption? = null,
    /**
     * Per-counter override of the app-wide decrement haptic default. `null` follows
     * `AppSettings.decrementHapticOption`; any value (including `OFF`) pins that
     * haptic for subtracts. Persisted as its `rawValue` string.
     */
    var decrementHapticOverride: HapticOption? = null,
) {
    init {
        // Clamp step to at least 1 on construction and on every `copy()` (which
        // re-invokes the primary constructor), matching Swift's `max(1, step)`.
        step = maxOf(1, step)
    }

    /**
     * True when this counter is a blank slot: a deleted counter left in place with
     * an empty name, awaiting revival. Drives the dashed/solid-blank dot rendering
     * and the "—" placeholder name. Giving it a name clears blankness; incrementing
     * does not.
     */
    val isBlank: Boolean get() = name.trim().isEmpty()

    // MARK: - Effective settings

    /** The handedness this counter renders with: its override when set, else [appDefault]. */
    fun effectiveLeftHanded(appDefault: Boolean): Boolean = handednessOverride ?: appDefault

    /** The sound this counter emits on a change: its override when set (incl. `OFF`), else [appDefault]. */
    fun effectiveSound(appDefault: SoundOption): SoundOption = soundOverride ?: appDefault

    /** The haptic fired on an increment: its override when set (incl. `OFF`), else [appDefault]. */
    fun effectiveIncrementHaptic(appDefault: HapticOption): HapticOption = incrementHapticOverride ?: appDefault

    /** The haptic fired on a subtract: its override when set (incl. `OFF`), else [appDefault]. */
    fun effectiveDecrementHaptic(appDefault: HapticOption): HapticOption = decrementHapticOverride ?: appDefault

    /**
     * Whether this counter pins ANY per-counter feedback/handedness override. Drives
     * the settings panel's FEEDBACK & HANDEDNESS section: a counter that already
     * carries an override opens the section; one on pure defaults leaves it collapsed.
     */
    val hasFeedbackOverride: Boolean
        get() = handednessOverride != null ||
            soundOverride != null ||
            incrementHapticOverride != null ||
            decrementHapticOverride != null

    /**
     * Encode to a JSON object with the current stored keys. Nullable overrides are
     * omitted when null (mirroring Swift's `encodeIfPresent` for optionals), and the
     * enum overrides are written as their `rawValue` string.
     */
    fun toJson(): JsonObject = buildJsonObject {
        put("id", id)
        put("name", name)
        put("count", count)
        put("colorKey", colorKey)
        put("allowNegative", allowNegative)
        put("step", step)
        put("order", order)
        handednessOverride?.let { put("handednessOverride", it) }
        soundOverride?.let { put("soundOverride", it.rawValue) }
        incrementHapticOverride?.let { put("incrementHapticOverride", it.rawValue) }
        decrementHapticOverride?.let { put("decrementHapticOverride", it.rawValue) }
    }

    companion object {
        /**
         * The sentinel `colorKey` a counter carries while blank — an empty string,
         * which `CounterTheme.dotColor` never needs to resolve because a blank slot is
         * drawn with the neutral muted fill instead of a palette color.
         */
        const val BLANK_COLOR_KEY = ""

        /**
         * Decode a counter from its JSON object, replicating the Swift custom
         * decoder: counters persisted before `step`/`allowNegative` fall back to the
         * same defaults as the constructor; the override fields decode as null when
         * absent; the enum overrides decode from their `rawValue` string via
         * `resolve` (migrating removed amplitude values), staying null on any
         * unrecognized value. A counter written before the haptic split carries a
         * single `hapticOverride`; when the new per-direction keys are absent it
         * migrates into *both* directions.
         *
         * Throws when a required field (`id`, `name`, `count`, `colorKey`, `order`)
         * is missing, so a malformed blob invalidates the whole load (as Swift's
         * `try? decode([Counter])` does).
         */
        fun fromJson(obj: JsonObject): Counter {
            val id = obj["id"]?.jsonPrimitive?.int ?: error("Counter.id missing")
            val name = obj["name"]?.jsonPrimitive?.contentOrNull ?: error("Counter.name missing")
            val count = obj["count"]?.jsonPrimitive?.int ?: error("Counter.count missing")
            val colorKey = obj["colorKey"]?.jsonPrimitive?.contentOrNull ?: error("Counter.colorKey missing")
            val order = obj["order"]?.jsonPrimitive?.int ?: error("Counter.order missing")

            val allowNegative = obj["allowNegative"]?.jsonPrimitive?.booleanOrNull ?: true
            val step = obj["step"]?.jsonPrimitive?.intOrNull ?: 1
            val handednessOverride = obj["handednessOverride"]?.jsonPrimitive?.booleanOrNull
            val soundOverride = SoundOption.fromRawValue(obj["soundOverride"]?.jsonPrimitive?.contentOrNull)

            // Route each override through `resolve(...)` so a persisted amplitude/
            // `rigid` rawValue migrates to its nearest surviving feel instead of
            // decoding to null (which would silently drop the override).
            val increment = HapticOption.resolve(obj["incrementHapticOverride"]?.jsonPrimitive?.contentOrNull)
            val decrement = HapticOption.resolve(obj["decrementHapticOverride"]?.jsonPrimitive?.contentOrNull)
            // Migration: when neither new key decoded, adopt the legacy single
            // override for both directions (a stray/unrecognized legacy value stays null).
            val legacy = HapticOption.resolve(obj["hapticOverride"]?.jsonPrimitive?.contentOrNull)
            val (incrementResolved, decrementResolved) =
                if (increment == null && decrement == null && legacy != null) legacy to legacy
                else increment to decrement

            return Counter(
                id = id,
                name = name,
                count = count,
                colorKey = colorKey,
                allowNegative = allowNegative,
                step = step,
                order = order,
                handednessOverride = handednessOverride,
                soundOverride = soundOverride,
                incrementHapticOverride = incrementResolved,
                decrementHapticOverride = decrementResolved,
            )
        }
    }
}

/**
 * A pending undo for a single reset: the counter that was zeroed and the value it
 * held just before. Scoped to a counter id so the offer only applies while that
 * same counter is active. Ported from iOS `ResetUndo`.
 */
data class ResetUndo(
    val counterId: Int,
    val previousCount: Int,
)
