package com.codeyam.android.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.codeyam.android.model.AppSettings
import com.codeyam.android.model.Counter
import com.codeyam.android.model.CounterHistory
import com.codeyam.android.model.CounterModel
import com.codeyam.android.model.EffectiveFeedback
import com.codeyam.android.model.HapticOption
import com.codeyam.android.model.SettingsOverlays
import com.codeyam.android.model.SoundOption

/**
 * The Compose state layer over the framework-free [CounterModel] and
 * [AppSettings] — the analog of the `@StateObject` + `@State` flags that iOS
 * `ContentView` owns.
 *
 * The ported model deliberately mutates in place rather than publishing
 * observable streams (it stays JVM-unit-testable with no Compose or Android
 * dependency). Compose therefore has nothing to subscribe to, so every mutation
 * routes through [mutate], which bumps a revision counter that reads are keyed
 * on. That keeps the "how do we recompose" decision in exactly one place instead
 * of at each of the dozen-plus mutation sites.
 *
 * The four overlay flags are pure-UI state the real app never persists. They are
 * seeded from the store only when the caller says the store is trusted, so a
 * release build can never be booted into a panel by a stray `appSettingsOpen`
 * key — the same gate iOS applies in `ContentView.init`.
 */
class CounterScreenState(
    val model: CounterModel,
    val settings: AppSettings,
    settingsOpen: Boolean = false,
    appSettingsOpen: Boolean = false,
    counterListOpen: Boolean = false,
    graphOpen: Boolean = false,
) {
    private var revision by mutableIntStateOf(0)

    var showSettings by mutableStateOf(settingsOpen)
        private set
    var showAppSettings by mutableStateOf(appSettingsOpen)
        private set
    var showCounterList by mutableStateOf(counterListOpen)
        private set
    var showGraph by mutableStateOf(graphOpen)
        private set

    init {
        // Resolve feedback through the active counter at emit time — its
        // per-counter override wins, else the shared app default — so switching
        // counters re-resolves without re-wiring the model.
        model.effectiveFeedback = {
            val c = model.activeCounter
            EffectiveFeedback(
                sound = c.effectiveSound(settings.soundOption),
                incrementHaptic = c.effectiveIncrementHaptic(settings.incrementHapticOption),
                decrementHaptic = c.effectiveDecrementHaptic(settings.decrementHapticOption),
            )
        }
    }

    // Reading `revision` inside each accessor is what subscribes the calling
    // composable to it, so any mutation re-reads the model.
    val counters: List<Counter> get() = revision.let { model.counters }
    val activeCounter: Counter get() = revision.let { model.activeCounter }
    val activeHistories: List<CounterHistory> get() = revision.let { model.activeHistories }
    val canUndoReset: Boolean get() = revision.let { model.canUndoReset }

    /** The handedness the active counter renders with: its override, else the app default. */
    val leftHanded: Boolean
        get() = revision.let { model.activeCounter.effectiveLeftHanded(settings.defaultLeftHanded) }

    private fun mutate(block: () -> Unit) {
        block()
        revision++
    }

    fun increment() = mutate { model.increment() }
    fun subtract() = mutate { model.subtract() }
    fun selectNext() = mutate { model.selectNext() }
    fun selectPrevious() = mutate { model.selectPrevious() }

    /** RESET doubles as UNDO RESET while an undo is pending — the bottom row dispatches by mode. */
    fun resetOrUndo() = mutate { if (model.canUndoReset) model.undoReset() else model.reset() }

    fun select(id: Int) = mutate {
        model.selectById(id)
        showSettings = false
    }

    fun addCounter() = mutate {
        model.addCounter()
        showSettings = false
    }

    fun deleteActiveCounter() = mutate {
        model.deleteCounter(model.activeCounter.id)
        showSettings = false
    }

    fun updateActiveCounter(
        name: String,
        colorKey: String,
        allowNegative: Boolean,
        step: Int,
        handednessOverride: Boolean?,
        soundOverride: SoundOption?,
        incrementHapticOverride: HapticOption?,
        decrementHapticOverride: HapticOption?,
    ) = mutate {
        model.updateActiveCounter(
            name = name,
            colorKey = colorKey,
            allowNegative = allowNegative,
            step = step,
            handednessOverride = handednessOverride,
            soundOverride = soundOverride,
            incrementHapticOverride = incrementHapticOverride,
            decrementHapticOverride = decrementHapticOverride,
        )
    }

    // MARK: - Overlays
    //
    // The two settings panels are mutually exclusive, and that rule lives in the
    // unit-tested `SettingsOverlays` rather than being re-derived at each tap
    // site — only the toggles enforce it, so a seeded both-open state is still
    // representable.

    private val overlays: SettingsOverlays
        get() = SettingsOverlays(counterSettings = showSettings, appSettings = showAppSettings)

    private fun apply(next: SettingsOverlays) {
        showSettings = next.counterSettings
        showAppSettings = next.appSettings
    }

    fun toggleAppSettings() = apply(overlays.togglingAppSettings())
    fun toggleCounterSettings() = apply(overlays.togglingCounterSettings())

    fun closeSettings() { showSettings = false }
    fun closeAppSettings() { showAppSettings = false }

    fun openCounterList() { showCounterList = true }
    fun closeCounterList() { showCounterList = false }

    fun selectFromList(id: Int) = mutate {
        model.selectById(id)
        showCounterList = false
        showAppSettings = false
    }

    fun toggleGraph() { showGraph = !showGraph }
    fun closeGraph() { showGraph = false }

    /** Re-persist app settings after a panel edit and re-read the model. */
    fun settingsChanged() = mutate { }
}
