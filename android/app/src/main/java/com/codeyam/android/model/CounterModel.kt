package com.codeyam.android.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * The resolved feedback flags to emit on a single change, evaluated fresh at each
 * increment/subtract. Sound is shared across directions; the haptic is resolved per
 * direction so the model — not the feedback sink — picks which one fires. The Kotlin
 * analog of the Swift named tuple `(sound, incrementHaptic, decrementHaptic)`.
 */
data class EffectiveFeedback(
    val sound: SoundOption,
    val incrementHaptic: HapticOption,
    val decrementHaptic: HapticOption,
)

/**
 * Store backing the counter screen. Ported from iOS `CounterModel`.
 *
 * Seeding contract: at launch the CodeYam seeder injects a scenario's preferences
 * into the [KeyValueStore] *before* the app starts. This model reads those same keys
 * in its constructor, so each scenario observes its seeded state from the first
 * frame:
 *   - `counters` — a JSON-encoded `[Counter]` string
 *   - `selectedCounterId` — the id of the active counter
 *   - `resetUndoPreviousCount` — the pre-reset value of the active counter, which
 *     seeds the bottom row into its UNDO RESET state for a static capture
 *   - `counterHistories` — a JSON object string mapping a counter id (as a string
 *     key) to its ordered `[CounterHistory]`, so a scenario can inject a rich event
 *     history for a static graph capture
 *
 * A release build requires the app's own provenance marker
 * ([SeedPolicy.REQUIRE_PROVENANCE]) before adopting any of these keys: because
 * seeding reuses the real persistence keys, a release build cannot simply ignore
 * them, so instead it trusts store state only once the app has stamped its marker.
 * Stray injected/stale scenario keys therefore land as an untrusted store and the
 * default starter set (four counters at 0, no history) is used. Debug builds (what
 * CodeYam captures run) keep trusting injected state.
 *
 * State is exposed read-only (private setters / unmodifiable views over mutable
 * backing collections), the Kotlin analog of Swift's `@Published private(set)`. A
 * UI layer can wrap this in a `ViewModel` and expose observable streams; the domain
 * core here stays framework-free and unit-testable.
 */
class CounterModel(
    private val store: KeyValueStore = InMemoryKeyValueStore(),
    private val feedback: CounterFeedback = NoopCounterFeedback(),
    policy: SeedPolicy = SeedPolicy.TRUST_INJECTED,
) {
    private val _counters = mutableListOf<Counter>()
    val counters: List<Counter> get() = _counters

    var selectedIndex: Int = 0
        private set

    /**
     * A reset that can still be undone, or null. Set the moment RESET is tapped
     * (capturing the pre-reset value) and cleared as soon as the counter "starts
     * again" — any count change, a selection switch, an edit, or a delete. Transient
     * by design: never persisted on live mutations.
     */
    var resetUndo: ResetUndo? = null
        private set

    /**
     * Per-counter event history, keyed by counter id. Each value is the ordered list
     * of that counter's runs (oldest first); the last is the *current* history that
     * increments/subtracts append to. Capped at [MAX_HISTORIES_PER_COUNTER] per
     * counter (drop-oldest).
     */
    private val _histories = mutableMapOf<Int, MutableList<CounterHistory>>()
    val histories: Map<Int, List<CounterHistory>> get() = _histories

    /**
     * The clock used to timestamp events and history starts, as epoch milliseconds.
     * Injectable so tests drive deterministic event times without the wall clock.
     */
    var now: () -> Long = { System.currentTimeMillis() }

    /**
     * The effective feedback flags to emit on the next change, evaluated fresh at
     * each increment/subtract. The view sets this from `AppSettings` and the active
     * counter's overrides; keeping it a lambda lets per-counter resolution
     * re-evaluate without re-wiring. Defaults to all-off.
     */
    var effectiveFeedback: () -> EffectiveFeedback =
        { EffectiveFeedback(SoundOption.OFF, HapticOption.OFF, HapticOption.OFF) }

    init {
        // A release build only trusts store state carrying the app's own provenance
        // marker; CodeYam seeding writes the data keys but never the marker, so an
        // untrusted store is treated as empty for every injection key and the default
        // starter set is used. Debug builds trust injected state.
        val trusted = policy.trustsStore(store)

        val loaded = if (trusted) loadCounters(store) else emptyList()
        val base = if (trusted) {
            migrateDeletedDefaults(if (loaded.isEmpty()) defaultCounters() else loaded, store)
        } else {
            defaultCounters()
        }
        _counters.addAll(base)

        if (trusted) {
            for ((id, runs) in loadHistories(store)) _histories[id] = runs.toMutableList()
        }

        // Presence is checked before `getInt` because `getInt` returns 0 (no counter
        // id) when absent. Skipped entirely for an untrusted store.
        val resolvedIndex = if (trusted && store.contains(SELECTED_KEY)) {
            val selId = store.getInt(SELECTED_KEY)
            _counters.indexOfFirst { it.id == selId }.takeIf { it >= 0 } ?: 0
        } else {
            0
        }
        selectedIndex = resolvedIndex

        // Seed the pending-undo state when a scenario injects it, so a static capture
        // renders the UNDO RESET affordance without a live tap. Require the active
        // counter to be at 0: a real pending undo is always a post-reset state, so a
        // non-zero active count is an impossible pairing — rejecting it also keeps the
        // key from falsely activating UNDO RESET in unrelated scenarios.
        resetUndo = if (trusted && store.contains(RESET_UNDO_KEY) && _counters[resolvedIndex].count == 0) {
            ResetUndo(
                counterId = _counters[resolvedIndex].id,
                previousCount = store.getInt(RESET_UNDO_KEY),
            )
        } else {
            null
        }
    }

    /** True when the pending undo applies to the currently active counter. */
    val canUndoReset: Boolean
        get() = resetUndo?.counterId == activeCounter.id

    // MARK: - Derived state

    val activeCounter: Counter
        get() = _counters[selectedIndex]

    /** The active counter's recorded runs, oldest first (empty when never changed). */
    val activeHistories: List<CounterHistory>
        get() = _histories[activeCounter.id] ?: emptyList()

    val counterCount: Int get() = _counters.size

    /**
     * 1-based position of the active counter, for the "01 / 04 COUNTERS" header. A
     * blank slot is still a slot, so the total counts blanks too.
     */
    val positionLabel: String
        get() = "%02d / %02d".format(selectedIndex + 1, _counters.size)

    // MARK: - Selection

    fun select(index: Int) {
        if (index !in _counters.indices) return
        // The captured pre-reset value belongs to the counter we're leaving.
        resetUndo = null
        selectedIndex = index
        persistSelection()
    }

    /** Selects the counter with the given id. Named distinctly from [select] because
     * Kotlin overloads cannot disambiguate on parameter name alone (Swift's
     * `select(id:)` vs `select(index:)` argument labels). */
    fun selectById(id: Int) {
        val idx = _counters.indexOfFirst { it.id == id }
        if (idx < 0) return
        select(idx)
    }

    /**
     * Advances to the next counter. Swiping *past the last* counter grows the list:
     * instead of wrapping back to the first, it appends a fresh blank slot and
     * selects it, so the user can keep swiping forward to add more counters.
     */
    fun selectNext() {
        if (_counters.isEmpty()) return
        if (selectedIndex >= _counters.size - 1) {
            addCounter()
        } else {
            select(selectedIndex + 1)
        }
    }

    /** Moves to the previous counter, wrapping around. */
    fun selectPrevious() {
        if (_counters.isEmpty()) return
        select((selectedIndex - 1 + _counters.size) % _counters.size)
    }

    /**
     * Appends a fresh blank counter to the end of the list and selects it. Backs the
     * "swipe past the last counter to add another" gesture. The new slot is a blank
     * (unnamed "—", neutral color) — named in settings or brought to life by
     * incrementing, exactly like a revived deleted slot.
     */
    fun addCounter() {
        resetUndo = null
        val nextId = (_counters.maxOfOrNull { it.id } ?: 0) + 1
        val nextOrder = (_counters.maxOfOrNull { it.order } ?: -1) + 1
        _counters.add(
            Counter(id = nextId, name = "", count = 0, colorKey = Counter.BLANK_COLOR_KEY, order = nextOrder),
        )
        selectedIndex = _counters.size - 1
        persistCounters()
        persistSelection()
    }

    // MARK: - Mutations (act on the active counter)

    fun increment() {
        // The counter "starts again" — the recovery offer expires.
        resetUndo = null
        val step = _counters[selectedIndex].step
        _counters[selectedIndex].count += step
        recordEvent(step)
        persistCounters()
        emitChangeFeedback(ChangeDirection.INCREMENT)
    }

    fun subtract() {
        val current = _counters[selectedIndex]
        // Any subtract counts as the counter starting again, even the no-op clamp.
        resetUndo = null
        val applied: Int
        if (current.allowNegative) {
            applied = -current.step
        } else {
            // Already at/below zero: no change — return before recording, persisting,
            // or firing feedback so the no-op clamp stays silent (and logs no event).
            if (current.count <= 0) return
            applied = maxOf(0, current.count - current.step) - current.count
        }
        _counters[selectedIndex].count += applied
        recordEvent(applied)
        persistCounters()
        emitChangeFeedback(ChangeDirection.DECREMENT)
    }

    /**
     * Appends a change to the active counter's current history, lazily opening a
     * first history when the counter has none yet. The recorded delta is the
     * *applied* change, so the running-count series reconstructs the count exactly.
     */
    private fun recordEvent(delta: Int) {
        val id = _counters[selectedIndex].id
        val runs = _histories.getOrPut(id) { mutableListOf() }
        if (runs.isEmpty()) {
            runs.add(CounterHistory(startedAt = now()))
        }
        runs[runs.size - 1].events.add(CounterEvent(at = now(), delta = delta))
        persistHistories()
    }

    /** The direction of a count change, selecting which resolved haptic fires. */
    private enum class ChangeDirection { INCREMENT, DECREMENT }

    /**
     * Emit change feedback for the just-applied change using the currently resolved
     * flags, picking the increment or decrement haptic per [direction]. `reset`/
     * `undoReset` deliberately do not call this — only a live count change gives
     * feedback.
     */
    private fun emitChangeFeedback(direction: ChangeDirection) {
        val flags = effectiveFeedback()
        val haptic = if (direction == ChangeDirection.INCREMENT) flags.incrementHaptic else flags.decrementHaptic
        feedback.changed(sound = flags.sound, haptic = haptic)
    }

    /**
     * Zeros the active counter, remembering its prior value so the bottom row can
     * offer an immediate UNDO RESET. The undo is captured even when the pre-reset
     * value was 0 (a harmless no-op to undo), keeping the affordance consistent.
     */
    fun reset() {
        val id = activeCounter.id
        resetUndo = ResetUndo(counterId = id, previousCount = _counters[selectedIndex].count)
        _counters[selectedIndex].count = 0
        // Seal the current run (it stays in the list) and open a fresh empty one, so
        // "relative to the start" is measured from this reset. Enforce the per-counter
        // cap by dropping the oldest run.
        val runs = _histories.getOrPut(id) { mutableListOf() }
        runs.add(CounterHistory(startedAt = now()))
        while (runs.size > MAX_HISTORIES_PER_COUNTER) {
            runs.removeAt(0)
        }
        persistCounters()
        persistHistories()
    }

    /**
     * Restores the value captured by the most recent `reset()` on the active counter
     * and clears the pending undo. Also reverses the history split reset performed: it
     * pops the empty run reset opened (guaranteed still empty, since any event would
     * have cleared the undo window) so the sealed run becomes active again. No-ops
     * when there is nothing to undo.
     */
    fun undoReset() {
        val undo = resetUndo
        if (!canUndoReset || undo == null) return
        _counters[selectedIndex].count = undo.previousCount
        val id = _counters[selectedIndex].id
        val runs = _histories[id]
        if (runs != null && runs.lastOrNull()?.events?.isEmpty() == true) {
            runs.removeAt(runs.size - 1)
            persistHistories()
        }
        resetUndo = null
        persistCounters()
    }

    // MARK: - Editing, deleting, restoring

    /**
     * Applies the settings panel's edits to the active counter and persists. The
     * overrides carry a `null` to mean "follow the app default"; the panel passes them
     * straight through so a counter can be pinned or reset to default in the same
     * save. The two haptic overrides are independent so a counter can pin one
     * direction while the other follows the app-wide pairing.
     */
    fun updateActiveCounter(
        name: String,
        colorKey: String,
        allowNegative: Boolean,
        step: Int,
        handednessOverride: Boolean? = null,
        soundOverride: SoundOption? = null,
        incrementHapticOverride: HapticOption? = null,
        decrementHapticOverride: HapticOption? = null,
    ) {
        if (selectedIndex !in _counters.indices) return
        // Editing the counter invalidates the captured pre-reset value.
        resetUndo = null
        val c = _counters[selectedIndex]
        c.name = name
        c.colorKey = colorKey
        c.allowNegative = allowNegative
        c.step = maxOf(1, step)
        c.handednessOverride = handednessOverride
        c.soundOverride = soundOverride
        c.incrementHapticOverride = incrementHapticOverride
        c.decrementHapticOverride = decrementHapticOverride
        persistCounters()
    }

    /**
     * Deleting behaves differently either side of the four permanent base slots.
     *
     * In the first four positions the counter is blanked *in place* rather than
     * removed: its name is emptied, count reset to 0, and color/step/allow-negative
     * dropped to neutral, keeping its `id` and `order`. The slot stays in [counters]
     * (so the header total is unchanged) and stays selected, so the user can
     * immediately revive it.
     *
     * Past those four (position 5+, counters the user added), the counter is removed
     * outright and the previous counter becomes active — the row shrinks.
     */
    fun deleteCounter(id: Int) {
        val idx = _counters.indexOfFirst { it.id == id }
        if (idx < 0) return
        // The captured pre-reset value no longer applies once a counter is deleted.
        resetUndo = null

        // Counters past the permanent base slots are removed outright, and focus falls
        // back to the previous counter. The rule only fires at or beyond baseSlotCount
        // (>= 1), so `idx - 1` is always a valid index and needs no clamp.
        if (idx >= BASE_SLOT_COUNT) {
            _histories.remove(_counters[idx].id)
            _counters.removeAt(idx)
            selectedIndex = idx - 1
            persistCounters()
            persistSelection()
            persistHistories()
            return
        }

        val c = _counters[idx]
        c.name = ""
        c.colorKey = Counter.BLANK_COLOR_KEY
        c.count = 0
        c.step = 1
        c.allowNegative = true
        // A revived slot starts on the app defaults, so drop any pinned overrides.
        c.handednessOverride = null
        c.soundOverride = null
        c.incrementHapticOverride = null
        c.decrementHapticOverride = null
        // A blank slot starts clean — drop the old counter's recorded runs.
        _histories.remove(c.id)
        selectedIndex = idx
        persistCounters()
        persistSelection()
        persistHistories()
    }

    // MARK: - Persistence

    private fun persistCounters() {
        val json = buildJsonArray { _counters.forEach { add(it.toJson()) } }.toString()
        store.putString(COUNTERS_KEY, json)
        // Stamp the app's provenance marker whenever it persists, so a real user's
        // own data is trusted on the next launch even under the release policy. Every
        // mutation path routes through here. CodeYam seeding never writes it.
        SeedPolicy.stampProvenance(store)
    }

    private fun persistSelection() {
        store.putInt(SELECTED_KEY, activeCounter.id)
    }

    private fun persistHistories() {
        // Encode string-keyed so JSON produces an object keyed by the counter id.
        val json = buildJsonObject {
            _histories.forEach { (id, runs) ->
                put(id.toString(), buildJsonArray { runs.forEach { add(it.toJson()) } })
            }
        }.toString()
        store.putString(HISTORIES_KEY, json)
    }

    companion object {
        const val COUNTERS_KEY = "counters"
        const val SELECTED_KEY = "selectedCounterId"
        const val DELETED_DEFAULTS_KEY = "deletedDefaultIds"
        const val RESET_UNDO_KEY = "resetUndoPreviousCount"
        const val HISTORIES_KEY = "counterHistories"

        /** The most recent runs kept per counter; the 11th reset drops the oldest. */
        const val MAX_HISTORIES_PER_COUNTER = 10

        /**
         * The permanent base slots. Counters in these first positions are blanked in
         * place on delete so the row never shrinks below them; counters the user adds
         * beyond them are removed outright. Positional, not id-based.
         */
        const val BASE_SLOT_COUNT = 4

        /** The starter set every fresh install begins with — four counters at zero. */
        fun defaultCounters(): List<Counter> = listOf(
            Counter(id = 1, name = "COUNTER 1", count = 0, colorKey = "lime", order = 0),
            Counter(id = 2, name = "COUNTER 2", count = 0, colorKey = "coffee", order = 1),
            Counter(id = 3, name = "COUNTER 3", count = 0, colorKey = "steps", order = 2),
            Counter(id = 4, name = "COUNTER 4", count = 0, colorKey = "bugs", order = 3),
        )

        private fun loadCounters(store: KeyValueStore): List<Counter> {
            val json = store.getString(COUNTERS_KEY) ?: return emptyList()
            return runCatching {
                (Json.parseToJsonElement(json) as JsonArray)
                    .map { Counter.fromJson(it.jsonObject) }
                    .sortedBy { it.order }
            }.getOrDefault(emptyList()).takeIf { it.isNotEmpty() } ?: emptyList()
        }

        private fun loadHistories(store: KeyValueStore): Map<Int, MutableList<CounterHistory>> {
            val json = store.getString(HISTORIES_KEY) ?: return emptyMap()
            return runCatching {
                (Json.parseToJsonElement(json) as JsonObject).entries.mapNotNull { (key, value) ->
                    // Drop any non-integer keys rather than fail the whole load.
                    key.toIntOrNull()?.let { id ->
                        id to value.jsonArray.map { CounterHistory.fromJson(it.jsonObject) }.toMutableList()
                    }
                }.toMap()
            }.getOrDefault(emptyMap())
        }

        // Stored as a JSON-encoded `[Int]` string. `deletedDefaultIds` is legacy/
        // read-only: this model no longer writes it (deleting blanks in place), but it
        // is still read once at launch to migrate users who deleted a default before
        // this change shipped.
        private fun loadDeletedDefaultIds(store: KeyValueStore): Set<Int> {
            val json = store.getString(DELETED_DEFAULTS_KEY) ?: return emptySet()
            return runCatching {
                (Json.parseToJsonElement(json) as JsonArray)
                    .map { it.jsonPrimitive.int }
                    .toSet()
            }.getOrDefault(emptySet())
        }

        /**
         * Legacy migration: for each id in the persisted `deletedDefaultIds` that is a
         * known default and absent from the loaded counters, fold in a blank counter at
         * that default's original order, then re-sort. This gives users (and older
         * scenarios) who deleted a default under the old remove+ghost model a blank slot
         * in the new blank-in-place model. Returns the loaded counters untouched when
         * there is nothing to migrate.
         */
        private fun migrateDeletedDefaults(counters: List<Counter>, store: KeyValueStore): List<Counter> {
            val deletedIds = loadDeletedDefaultIds(store)
            if (deletedIds.isEmpty()) return counters
            val present = counters.map { it.id }.toSet()
            val result = counters.toMutableList()
            for (template in defaultCounters()) {
                if (template.id in deletedIds && template.id !in present) {
                    result.add(
                        Counter(
                            id = template.id, name = "", count = 0,
                            colorKey = Counter.BLANK_COLOR_KEY, order = template.order,
                        ),
                    )
                }
            }
            return result.sortedBy { it.order }
        }
    }
}
