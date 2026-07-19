package com.codeyam.android.model

import kotlinx.serialization.json.buildJsonArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Ported from iOS `ModelTests` (case-for-case). The three `CounterGraphChart`
 * cases from the Swift file — `testChartPlotMapsExtremesAndDomain`,
 * `testChartPlotDomainIncludesNegativeRange`, `testRelativeTimeFormatting` —
 * exercise a SwiftUI view helper, not the AppCore logic layer, so they are ported
 * with the UI in a later plan, not here.
 *
 * Time is epoch milliseconds in the Kotlin model, so relative offsets that read as
 * seconds in the Swift tests are seeded as `seconds * 1000` here.
 */
class CounterModelTest {

    /** Records every `changed(sound:haptic:)` call so tests can assert what fired. */
    private class FeedbackSpy : CounterFeedback {
        val calls = mutableListOf<FeedbackCall>()
        override fun changed(sound: SoundOption, haptic: HapticOption) {
            calls.add(FeedbackCall(sound, haptic))
        }
    }

    private data class FeedbackCall(val sound: SoundOption, val haptic: HapticOption)

    private fun encodeCounters(counters: List<Counter>): String =
        buildJsonArray { counters.forEach { add(it.toJson()) } }.toString()

    /** A model over an isolated empty store. */
    private fun makeModel(): CounterModel = CounterModel(InMemoryKeyValueStore())

    /** A model whose counters are seeded into an isolated store via the JSON contract. */
    private fun seededModel(counters: List<Counter>): CounterModel {
        val store = InMemoryKeyValueStore()
        store.putString(CounterModel.COUNTERS_KEY, encodeCounters(counters))
        return CounterModel(store)
    }

    private fun spiedModel(counters: List<Counter>, spy: FeedbackSpy): CounterModel {
        val store = InMemoryKeyValueStore()
        store.putString(CounterModel.COUNTERS_KEY, encodeCounters(counters))
        return CounterModel(store, feedback = spy)
    }

    // A fresh model with no seeded state falls back to the four-counter starter set,
    // all at zero, with the first counter selected.
    @Test
    fun testFreshModelHasFourStarterCountersAtZero() {
        val model = makeModel()
        assertEquals(4, model.counterCount)
        assertTrue(model.counters.all { it.count == 0 })
        assertEquals(0, model.selectedIndex)
        assertEquals("COUNTER 1", model.activeCounter.name)
    }

    // Incrementing raises only the active counter's count by one.
    @Test
    fun testIncrementRaisesActiveCounter() {
        val model = makeModel()
        assertEquals(0, model.activeCounter.count)
        model.increment()
        assertEquals(1, model.activeCounter.count)
        assertEquals(0, model.counters[1].count)
    }

    // With the default allowNegative == true, subtracting from zero goes negative.
    @Test
    fun testSubtractGoesNegativeByDefault() {
        val model = makeModel()
        model.subtract()
        assertEquals(-1, model.activeCounter.count)
    }

    // A counter with allowNegative == false clamps at zero instead of going negative.
    @Test
    fun testSubtractClampsWhenNegativesDisallowed() {
        val model = seededModel(
            listOf(Counter(id = 1, name = "REPS", count = 0, colorKey = "lime", allowNegative = false, order = 0)),
        )
        model.subtract()
        assertEquals(0, model.activeCounter.count)
    }

    // Reset zeroes the active counter without touching the others.
    @Test
    fun testResetZeroesActiveCounter() {
        val model = makeModel()
        model.increment()
        model.increment()
        assertEquals(2, model.activeCounter.count)
        model.reset()
        assertEquals(0, model.activeCounter.count)
    }

    // Swiping forward within the list advances selection by one and does not grow it.
    @Test
    fun testSelectNextAdvancesWithinList() {
        val model = makeModel()
        assertEquals(4, model.counterCount)
        model.selectNext()
        assertEquals(1, model.selectedIndex)
        assertEquals(4, model.counterCount)
    }

    // Swiping forward PAST the last counter grows the list: it appends a fresh blank
    // slot and selects it instead of wrapping back to the first.
    @Test
    fun testSelectNextPastLastAppendsBlankAndSelectsIt() {
        val model = makeModel()
        model.select(model.counterCount - 1) // on the last counter
        model.selectNext()
        assertEquals(5, model.counterCount)
        assertEquals(4, model.selectedIndex)
        assertTrue(model.activeCounter.isBlank)
        assertEquals(0, model.activeCounter.count)
    }

    // selectPrevious wraps around from the first counter to the last, never growing.
    @Test
    fun testSelectPreviousWrapsFromFirstToLast() {
        val model = makeModel()
        assertEquals(0, model.selectedIndex)
        model.selectPrevious()
        assertEquals(model.counterCount - 1, model.selectedIndex)
        assertEquals(4, model.counterCount)
    }

    // selectPrevious within the list moves back by one.
    @Test
    fun testSelectPreviousMovesBackWithinList() {
        val model = makeModel()
        model.select(2)
        model.selectPrevious()
        assertEquals(1, model.selectedIndex)
    }

    // addCounter appends a blank slot (empty name, blank color, count 0) and selects it.
    @Test
    fun testAddCounterAppendsBlankAndSelectsIt() {
        val model = makeModel()
        model.addCounter()
        assertEquals(5, model.counterCount)
        assertEquals(4, model.selectedIndex)
        assertTrue(model.activeCounter.isBlank)
        assertEquals("", model.activeCounter.name)
        assertEquals(Counter.BLANK_COLOR_KEY, model.activeCounter.colorKey)
        assertEquals(0, model.activeCounter.count)
    }

    // addCounter assigns an id one past the current max and an order one past the max.
    @Test
    fun testAddCounterAssignsNextIdAndOrder() {
        val model = seededModel(
            listOf(
                Counter(id = 3, name = "A", count = 0, colorKey = "lime", order = 5),
                Counter(id = 7, name = "B", count = 0, colorKey = "coffee", order = 9),
            ),
        )
        model.addCounter()
        assertEquals(8, model.activeCounter.id)
        assertEquals(10, model.activeCounter.order)
    }

    // addCounter persists both the grown counters list and the new selection.
    @Test
    fun testAddCounterPersists() {
        val store = InMemoryKeyValueStore()
        val model = CounterModel(store)
        model.addCounter()
        val addedId = model.activeCounter.id
        val reloaded = CounterModel(store)
        assertEquals(5, reloaded.counterCount)
        assertEquals(addedId, reloaded.activeCounter.id)
        assertTrue(reloaded.activeCounter.isBlank)
    }

    // Every add stacks another blank slot, each with its own unique id.
    @Test
    fun testAddCounterAllowsConsecutiveBlankSlots() {
        val model = makeModel()
        model.addCounter()
        model.addCounter()
        assertEquals(6, model.counterCount)
        val blankIds = model.counters.filter { it.isBlank }.map { it.id }
        assertEquals(2, blankIds.size)
        assertEquals(2, blankIds.toSet().size)
    }

    // Adding a counter is a fresh start, so it clears any pending reset-undo.
    @Test
    fun testAddCounterClearsPendingUndo() {
        val model = makeModel()
        model.increment()
        model.reset()
        assertTrue(model.canUndoReset)
        model.addCounter()
        assertFalse(model.canUndoReset)
        assertNull(model.resetUndo)
    }

    // A counter with step 5 increments in jumps of 5 (0 -> 5 -> 10).
    @Test
    fun testIncrementHonorsStep() {
        val model = seededModel(listOf(Counter(id = 1, name = "REPS", count = 0, colorKey = "lime", step = 5, order = 0)))
        model.increment()
        assertEquals(5, model.activeCounter.count)
        model.increment()
        assertEquals(10, model.activeCounter.count)
    }

    // Subtracting honors the step symmetrically when negatives are allowed.
    @Test
    fun testSubtractHonorsStep() {
        val model = seededModel(listOf(Counter(id = 1, name = "REPS", count = 10, colorKey = "lime", step = 4, order = 0)))
        model.subtract()
        assertEquals(6, model.activeCounter.count)
    }

    // With negatives disallowed, a step that would overshoot below zero clamps to zero.
    @Test
    fun testSubtractClampsToZeroWhenStepOvershoots() {
        val model = seededModel(
            listOf(Counter(id = 1, name = "REPS", count = 3, colorKey = "lime", allowNegative = false, step = 5, order = 0)),
        )
        model.subtract()
        assertEquals(0, model.activeCounter.count)
        // Already at zero: a further subtract makes no change.
        model.subtract()
        assertEquals(0, model.activeCounter.count)
    }

    // Counters persisted before step existed decode with step defaulting to 1.
    @Test
    fun testLegacyCounterWithoutStepDecodesToStepOne() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            """[{"id":1,"name":"PUSH-UPS","count":2,"colorKey":"lime","allowNegative":true,"order":0}]""",
        )
        val model = CounterModel(store)
        assertEquals(1, model.activeCounter.step)
        model.increment()
        assertEquals(3, model.activeCounter.count)
    }

    // updateActiveCounter applies every edited field and persists across reloads.
    @Test
    fun testUpdateActiveCounterEditsAndPersists() {
        val store = InMemoryKeyValueStore()
        val model = CounterModel(store)
        model.updateActiveCounter(name = "MEDITATION", colorKey = "rose", allowNegative = false, step = 3)
        assertEquals("MEDITATION", model.activeCounter.name)
        assertEquals("rose", model.activeCounter.colorKey)
        assertFalse(model.activeCounter.allowNegative)
        assertEquals(3, model.activeCounter.step)
        val reloaded = CounterModel(store)
        assertEquals("MEDITATION", reloaded.activeCounter.name)
        assertEquals(3, reloaded.activeCounter.step)
    }

    // A step below 1 is clamped up to 1.
    @Test
    fun testUpdateActiveCounterClampsStepToAtLeastOne() {
        val model = makeModel()
        model.updateActiveCounter(name = "X", colorKey = "lime", allowNegative = true, step = 0)
        assertEquals(1, model.activeCounter.step)
    }

    // Deleting a counter blanks it in place rather than removing it.
    @Test
    fun testDeleteBlanksInPlace() {
        val model = makeModel()
        model.selectById(2)
        model.increment()
        model.deleteCounter(2)
        assertEquals(4, model.counterCount)
        val blanked = model.counters.firstOrNull { it.id == 2 }
        assertNotNull(blanked)
        assertTrue(blanked!!.isBlank)
        assertEquals("", blanked.name)
        assertEquals(0, blanked.count)
        assertEquals(2, model.activeCounter.id)
    }

    // A blanked slot increments into a solid blank dot without resurrecting a name.
    @Test
    fun testBlankSlotIncrementsWithoutReviving() {
        val model = makeModel()
        model.deleteCounter(3)
        assertTrue(model.activeCounter.isBlank)
        model.increment()
        assertEquals(1, model.activeCounter.count)
        assertTrue(model.activeCounter.isBlank)
    }

    // Giving a blank slot a name via settings revives it — it stops being blank.
    @Test
    fun testNamingBlankSlotRevivesIt() {
        val model = makeModel()
        model.deleteCounter(3)
        assertTrue(model.activeCounter.isBlank)
        model.updateActiveCounter(name = "YOGA", colorKey = "mint", allowNegative = true, step = 1)
        assertFalse(model.activeCounter.isBlank)
        assertEquals("YOGA", model.activeCounter.name)
    }

    // Deleting the last counter blanks it in place: the row length is unchanged and
    // the blanked slot stays selected.
    @Test
    fun testDeleteLastCounterBlanksInPlaceAndKeepsSelection() {
        val model = makeModel()
        model.select(3)
        model.deleteCounter(model.activeCounter.id)
        assertEquals(4, model.counterCount)
        assertEquals(3, model.selectedIndex)
        assertTrue(model.activeCounter.isBlank)
    }

    // Past the four permanent base slots, deleting removes the counter outright and
    // selection falls back to the previous counter.
    @Test
    fun testDeleteBeyondFirstFourRemovesAndSelectsPrevious() {
        val model = makeModel()
        model.addCounter()
        assertEquals(5, model.counterCount)
        assertEquals(4, model.selectedIndex)
        val fifthId = model.activeCounter.id

        model.deleteCounter(fifthId)

        assertEquals(4, model.counterCount)
        assertNull(model.counters.firstOrNull { it.id == fifthId })
        assertEquals(3, model.selectedIndex)
    }

    // The blank-in-place / remove split is keyed on baseSlotCount, so the row can
    // never shrink below it no matter how many base slots are deleted.
    @Test
    fun testDeletingEveryBaseSlotNeverShrinksTheRow() {
        val model = makeModel()
        assertEquals(CounterModel.BASE_SLOT_COUNT, model.counterCount)
        for (id in model.counters.map { it.id }) {
            model.deleteCounter(id)
        }
        assertEquals(CounterModel.BASE_SLOT_COUNT, model.counterCount)
        assertTrue(model.counters.all { it.isBlank })
    }

    // Deleting an extra counter that is not the last one closes the gap.
    @Test
    fun testDeletingMiddleExtraCounterSlidesFollowingCounterDown() {
        val model = makeModel()
        model.addCounter() // index 4
        model.updateActiveCounter(name = "WATER", colorKey = "teal", allowNegative = true, step = 1)
        model.addCounter() // index 5
        model.updateActiveCounter(name = "MILES", colorKey = "mint", allowNegative = true, step = 1)
        assertEquals(6, model.counterCount)

        val waterId = model.counters[4].id
        model.deleteCounter(waterId)

        assertEquals(5, model.counterCount)
        assertEquals("MILES", model.counters[4].name)
        assertEquals(3, model.selectedIndex)
    }

    // Deleting the last extra counter selects the new last counter.
    @Test
    fun testDeletingLastExtraCounterSelectsNewLast() {
        val model = makeModel()
        model.addCounter() // index 4
        model.addCounter() // index 5, selected
        assertEquals(5, model.selectedIndex)

        model.deleteCounter(model.activeCounter.id)

        assertEquals(5, model.counterCount)
        assertEquals(4, model.selectedIndex)
        assertEquals(model.counterCount - 1, model.selectedIndex)
    }

    // Removing an extra counter drops its recorded runs rather than orphaning them.
    @Test
    fun testDeletingExtraCounterDropsItsHistory() {
        val model = makeModel()
        model.addCounter()
        val extraId = model.activeCounter.id
        model.increment()
        model.reset()
        assertFalse(model.activeHistories.isEmpty())

        model.deleteCounter(extraId)

        assertNull(model.histories[extraId])
    }

    // Legacy migration: deletedDefaultIds folds blank counters at the right orders.
    @Test
    fun testMigrationFoldsDeletedDefaultsIntoBlankSlots() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            encodeCounters(
                listOf(
                    Counter(id = 1, name = "PUSH-UPS", count = 7, colorKey = "lime", order = 0),
                    Counter(id = 3, name = "STEPS", count = 8421, colorKey = "steps", order = 2),
                ),
            ),
        )
        store.putString(CounterModel.DELETED_DEFAULTS_KEY, "[2, 4]")
        val model = CounterModel(store)
        assertEquals(listOf(1, 2, 3, 4), model.counters.map { it.id })
        val blank2 = model.counters.firstOrNull { it.id == 2 }
        val blank4 = model.counters.firstOrNull { it.id == 4 }
        assertTrue(blank2?.isBlank ?: false)
        assertEquals(0, blank2?.count)
        assertEquals(1, blank2?.order)
        assertTrue(blank4?.isBlank ?: false)
        assertEquals(3, blank4?.order)
    }

    // A seeded subset (no deletedDefaultIds) has no blank slots.
    @Test
    fun testSeededSubsetHasNoBlankSlots() {
        val model = seededModel(
            listOf(
                Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0),
                Counter(id = 2, name = "COFFEE", count = 0, colorKey = "coffee", order = 1),
            ),
        )
        assertEquals(2, model.counterCount)
        assertFalse(model.counters.any { it.isBlank })
    }

    // The model loads seeded counters and the selected id injected via the store.
    @Test
    fun testLoadsSeededStateFromDefaults() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            encodeCounters(
                listOf(
                    Counter(id = 1, name = "PUSH-UPS", count = 7, colorKey = "lime", order = 0),
                    Counter(id = 2, name = "COFFEE", count = 3, colorKey = "coffee", order = 1),
                ),
            ),
        )
        store.putInt(CounterModel.SELECTED_KEY, 2)
        val model = CounterModel(store)
        assertEquals(2, model.counterCount)
        assertEquals(1, model.selectedIndex)
        assertEquals(3, model.activeCounter.count)
    }

    // Reset captures the pre-reset value and enters undo mode.
    @Test
    fun testResetEntersUndoModeAndCapturesPreviousValue() {
        val model = seededModel(listOf(Counter(id = 1, name = "PUSH-UPS", count = 9, colorKey = "lime", order = 0)))
        assertFalse(model.canUndoReset)
        model.reset()
        assertEquals(0, model.activeCounter.count)
        assertTrue(model.canUndoReset)
        assertEquals(ResetUndo(counterId = 1, previousCount = 9), model.resetUndo)
    }

    // undoReset restores the captured value and exits undo mode.
    @Test
    fun testUndoResetRestoresPreviousValueAndExitsUndoMode() {
        val model = seededModel(listOf(Counter(id = 1, name = "PUSH-UPS", count = 9, colorKey = "lime", order = 0)))
        model.reset()
        model.undoReset()
        assertEquals(9, model.activeCounter.count)
        assertFalse(model.canUndoReset)
        assertNull(model.resetUndo)
    }

    // Resetting a counter already at zero still enters undo mode; undoing restores zero.
    @Test
    fun testResetAtZeroEntersUndoModeAndUndoRestoresZero() {
        val model = seededModel(listOf(Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0)))
        model.reset()
        assertTrue(model.canUndoReset)
        model.undoReset()
        assertEquals(0, model.activeCounter.count)
        assertFalse(model.canUndoReset)
    }

    // Incrementing — the counter "starting again" — clears the pending undo.
    @Test
    fun testIncrementClearsPendingUndo() {
        val model = seededModel(listOf(Counter(id = 1, name = "PUSH-UPS", count = 4, colorKey = "lime", order = 0)))
        model.reset()
        assertTrue(model.canUndoReset)
        model.increment()
        assertFalse(model.canUndoReset)
        assertNull(model.resetUndo)
    }

    // Subtracting also clears the pending undo.
    @Test
    fun testSubtractClearsPendingUndo() {
        val model = seededModel(listOf(Counter(id = 1, name = "PUSH-UPS", count = 4, colorKey = "lime", order = 0)))
        model.reset()
        assertTrue(model.canUndoReset)
        model.subtract()
        assertFalse(model.canUndoReset)
    }

    // Switching counters expires the undo offer — the captured value belonged to the
    // counter we left; returning does not revive it.
    @Test
    fun testSwitchingCounterClearsPendingUndo() {
        val model = makeModel()
        model.increment()
        model.reset()
        assertTrue(model.canUndoReset)
        model.selectNext()
        assertFalse(model.canUndoReset)
        assertNull(model.resetUndo)
        model.selectById(1)
        assertFalse(model.canUndoReset)
    }

    // Editing the active counter invalidates the captured pre-reset value.
    @Test
    fun testEditingActiveCounterClearsPendingUndo() {
        val model = seededModel(listOf(Counter(id = 1, name = "PUSH-UPS", count = 4, colorKey = "lime", order = 0)))
        model.reset()
        assertTrue(model.canUndoReset)
        model.updateActiveCounter(name = "PUSH-UPS", colorKey = "lime", allowNegative = true, step = 1)
        assertFalse(model.canUndoReset)
    }

    // Deleting a counter clears the pending undo.
    @Test
    fun testDeletingCounterClearsPendingUndo() {
        val model = makeModel()
        model.increment()
        model.reset()
        assertTrue(model.canUndoReset)
        model.deleteCounter(model.activeCounter.id)
        assertFalse(model.canUndoReset)
    }

    // A model seeded with the resetUndo key enters undo mode on launch when the
    // active counter is at zero (the static-scenario seed path).
    @Test
    fun testSeededResetUndoKeyEntersUndoModeOnLaunch() {
        val store = InMemoryKeyValueStore()
        store.putString(CounterModel.COUNTERS_KEY, encodeCounters(listOf(Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0))))
        store.putInt(CounterModel.SELECTED_KEY, 1)
        store.putInt(CounterModel.RESET_UNDO_KEY, 12)
        val model = CounterModel(store)
        assertTrue(model.canUndoReset)
        assertEquals(ResetUndo(counterId = 1, previousCount = 12), model.resetUndo)
    }

    // The seed read coerces a string-injected value via the store's int coercion.
    @Test
    fun testSeededResetUndoKeyCoercesStringValue() {
        val store = InMemoryKeyValueStore()
        store.putString(CounterModel.COUNTERS_KEY, encodeCounters(listOf(Counter(id = 1, name = "PUSH-UPS", count = 0, colorKey = "lime", order = 0))))
        store.putString(CounterModel.RESET_UNDO_KEY, "12")
        val model = CounterModel(store)
        assertTrue(model.canUndoReset)
        assertEquals(12, model.resetUndo?.previousCount)
    }

    // The seed is rejected when the active counter is not at zero — a stale leftover
    // key must not falsely activate UNDO RESET.
    @Test
    fun testSeededResetUndoKeyIgnoredWhenActiveCountNonZero() {
        val store = InMemoryKeyValueStore()
        store.putString(CounterModel.COUNTERS_KEY, encodeCounters(listOf(Counter(id = 1, name = "PUSH-UPS", count = 7, colorKey = "lime", order = 0))))
        store.putInt(CounterModel.SELECTED_KEY, 1)
        store.putInt(CounterModel.RESET_UNDO_KEY, 12)
        val model = CounterModel(store)
        assertFalse(model.canUndoReset)
        assertNull(model.resetUndo)
    }

    // Incrementing emits one feedback call carrying the resolved sound and the
    // increment haptic (not the decrement one).
    @Test
    fun testIncrementFiresFeedbackWithIncrementHaptic() {
        val spy = FeedbackSpy()
        val model = spiedModel(listOf(Counter(id = 1, name = "REPS", count = 0, colorKey = "lime", order = 0)), spy)
        model.effectiveFeedback = { EffectiveFeedback(SoundOption.POP, HapticOption.SHARP, HapticOption.SOFT) }
        model.increment()
        assertEquals(1, spy.calls.size)
        assertEquals(SoundOption.POP, spy.calls[0].sound)
        assertEquals(HapticOption.SHARP, spy.calls[0].haptic)
    }

    // A subtract that changes the count emits the decrement haptic, distinct from
    // the increment default.
    @Test
    fun testSubtractFiresFeedbackWithDecrementHaptic() {
        val spy = FeedbackSpy()
        val model = spiedModel(listOf(Counter(id = 1, name = "REPS", count = 5, colorKey = "lime", order = 0)), spy)
        model.effectiveFeedback = { EffectiveFeedback(SoundOption.DING, HapticOption.SHARP, HapticOption.SOFT) }
        model.subtract()
        assertEquals(1, spy.calls.size)
        assertEquals(SoundOption.DING, spy.calls[0].sound)
        assertEquals(HapticOption.SOFT, spy.calls[0].haptic)
        assertNotEquals(HapticOption.SHARP, spy.calls[0].haptic)
    }

    // The no-op clamp (negatives disallowed, already at zero) fires no feedback.
    @Test
    fun testSubtractNoOpClampDoesNotFireFeedback() {
        val spy = FeedbackSpy()
        val model = spiedModel(
            listOf(Counter(id = 1, name = "REPS", count = 0, colorKey = "lime", allowNegative = false, order = 0)),
            spy,
        )
        model.effectiveFeedback = { EffectiveFeedback(SoundOption.TOCK, HapticOption.SHARP, HapticOption.SOFT) }
        model.subtract()
        assertTrue(spy.calls.isEmpty())
    }

    // reset() and undoReset() are not count-change events — they stay silent.
    @Test
    fun testResetAndUndoResetStaySilent() {
        val spy = FeedbackSpy()
        val model = spiedModel(listOf(Counter(id = 1, name = "REPS", count = 4, colorKey = "lime", order = 0)), spy)
        model.effectiveFeedback = { EffectiveFeedback(SoundOption.TOCK, HapticOption.SHARP, HapticOption.SOFT) }
        model.reset()
        model.undoReset()
        assertTrue(spy.calls.isEmpty())
    }

    // The default (no effectiveFeedback set) resolves to all-off and fires OFF options.
    @Test
    fun testDefaultEffectiveFeedbackIsAllOff() {
        val spy = FeedbackSpy()
        val model = spiedModel(listOf(Counter(id = 1, name = "REPS", count = 0, colorKey = "lime", order = 0)), spy)
        model.increment()
        assertEquals(1, spy.calls.size)
        assertEquals(SoundOption.OFF, spy.calls[0].sound)
        assertEquals(HapticOption.OFF, spy.calls[0].haptic)
    }

    // With no override set, every effective* resolver returns the supplied app default.
    @Test
    fun testEffectiveResolversFollowDefaultWhenNil() {
        val c = Counter(id = 1, name = "REPS", count = 0, colorKey = "lime", order = 0)
        assertEquals(true, c.effectiveLeftHanded(true))
        assertEquals(false, c.effectiveLeftHanded(false))
        assertEquals(SoundOption.DING, c.effectiveSound(SoundOption.DING))
        assertEquals(HapticOption.SHARP, c.effectiveIncrementHaptic(HapticOption.SHARP))
        assertEquals(HapticOption.SOFT, c.effectiveDecrementHaptic(HapticOption.SOFT))
    }

    // A set override pins its own value regardless of the app default — including an
    // explicit OFF winning over a non-OFF default; the two haptic directions resolve
    // independently.
    @Test
    fun testEffectiveResolversPinOverrideWhenSet() {
        val c = Counter(
            id = 1, name = "REPS", count = 0, colorKey = "lime", order = 0,
            handednessOverride = true, soundOverride = SoundOption.OFF,
            incrementHapticOverride = HapticOption.SHARP, decrementHapticOverride = HapticOption.OFF,
        )
        assertEquals(true, c.effectiveLeftHanded(false))
        assertEquals(SoundOption.OFF, c.effectiveSound(SoundOption.DING))
        assertEquals(HapticOption.SHARP, c.effectiveIncrementHaptic(HapticOption.SOFT))
        assertEquals(HapticOption.OFF, c.effectiveDecrementHaptic(HapticOption.DOUBLE))
    }

    // A counter can pin one haptic direction while the other follows the app default.
    @Test
    fun testHapticDirectionsResolveIndependently() {
        val c = Counter(
            id = 1, name = "REPS", count = 0, colorKey = "lime", order = 0,
            incrementHapticOverride = HapticOption.SHARP, decrementHapticOverride = null,
        )
        assertEquals(HapticOption.SHARP, c.effectiveIncrementHaptic(HapticOption.DOUBLE))
        assertEquals(HapticOption.SOFT, c.effectiveDecrementHaptic(HapticOption.SOFT))
    }

    // updateActiveCounter persists all overrides across a reload, enum overrides
    // surviving as their rawValue.
    @Test
    fun testUpdateActiveCounterRoundTripsOverrides() {
        val store = InMemoryKeyValueStore()
        val model = CounterModel(store)
        model.updateActiveCounter(
            name = "PUSH-UPS", colorKey = "lime", allowNegative = true, step = 1,
            handednessOverride = true, soundOverride = SoundOption.BLOOP,
            incrementHapticOverride = HapticOption.DOUBLE, decrementHapticOverride = HapticOption.BUZZ,
        )
        assertEquals(true, model.activeCounter.handednessOverride)
        assertEquals(SoundOption.BLOOP, model.activeCounter.soundOverride)
        assertEquals(HapticOption.DOUBLE, model.activeCounter.incrementHapticOverride)
        assertEquals(HapticOption.BUZZ, model.activeCounter.decrementHapticOverride)
        val reloaded = CounterModel(store)
        assertEquals(true, reloaded.activeCounter.handednessOverride)
        assertEquals(SoundOption.BLOOP, reloaded.activeCounter.soundOverride)
        assertEquals(HapticOption.DOUBLE, reloaded.activeCounter.incrementHapticOverride)
        assertEquals(HapticOption.BUZZ, reloaded.activeCounter.decrementHapticOverride)
    }

    // Saving with null overrides clears any previously pinned values.
    @Test
    fun testUpdateActiveCounterClearsOverridesWhenNil() {
        val model = seededModel(
            listOf(
                Counter(
                    id = 1, name = "REPS", count = 0, colorKey = "lime", order = 0,
                    handednessOverride = false, soundOverride = SoundOption.DING,
                    incrementHapticOverride = HapticOption.DOUBLE, decrementHapticOverride = HapticOption.BUZZ,
                ),
            ),
        )
        model.updateActiveCounter(name = "REPS", colorKey = "lime", allowNegative = true, step = 1)
        assertNull(model.activeCounter.handednessOverride)
        assertNull(model.activeCounter.soundOverride)
        assertNull(model.activeCounter.incrementHapticOverride)
        assertNull(model.activeCounter.decrementHapticOverride)
    }

    // A nil-override counter tracks a changed app default; an overriding counter is pinned.
    @Test
    fun testOverrideTracksOrPinsAgainstChangingDefault() {
        val follower = Counter(id = 1, name = "A", count = 0, colorKey = "lime", order = 0)
        val pinned = Counter(id = 2, name = "B", count = 0, colorKey = "coffee", order = 1, soundOverride = SoundOption.OFF)
        assertEquals(SoundOption.TOCK, follower.effectiveSound(SoundOption.TOCK))
        assertEquals(SoundOption.OFF, pinned.effectiveSound(SoundOption.TOCK))
        assertEquals(SoundOption.DING, follower.effectiveSound(SoundOption.DING))
        assertEquals(SoundOption.OFF, pinned.effectiveSound(SoundOption.DING))
    }

    // Legacy persisted counters decode with all overrides null.
    @Test
    fun testLegacyCountersDecodeWithNilOverrides() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            """[{"id":1,"name":"PUSH-UPS","count":2,"colorKey":"lime","allowNegative":true,"step":1,"order":0}]""",
        )
        val model = CounterModel(store)
        assertNull(model.activeCounter.handednessOverride)
        assertNull(model.activeCounter.soundOverride)
        assertNull(model.activeCounter.incrementHapticOverride)
        assertNull(model.activeCounter.decrementHapticOverride)
    }

    // A counter persisted with the pre-split single hapticOverride key migrates that
    // value into BOTH direction overrides on decode; heavy migrates to sharp.
    @Test
    fun testLegacySingleHapticOverrideMigratesToBothDirections() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            """[{"id":1,"name":"PUSH-UPS","count":2,"colorKey":"lime","allowNegative":true,"step":1,"order":0,"hapticOverride":"heavy"}]""",
        )
        val model = CounterModel(store)
        assertEquals(HapticOption.SHARP, model.activeCounter.incrementHapticOverride)
        assertEquals(HapticOption.SHARP, model.activeCounter.decrementHapticOverride)
    }

    // A new per-direction override key in persisted JSON wins over a legacy single key.
    @Test
    fun testNewHapticOverrideKeyWinsOverLegacyOnDecode() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            """[{"id":1,"name":"PUSH-UPS","count":0,"colorKey":"lime","allowNegative":true,"step":1,"order":0,"hapticOverride":"heavy","incrementHapticOverride":"double"}]""",
        )
        val model = CounterModel(store)
        assertEquals(HapticOption.DOUBLE, model.activeCounter.incrementHapticOverride)
        assertNull(model.activeCounter.decrementHapticOverride)
    }

    // An unrecognized override rawValue in seeded JSON decodes to null rather than
    // crashing the whole load.
    @Test
    fun testUnrecognizedOverrideRawValueDecodesToNil() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            """[{"id":1,"name":"PUSH-UPS","count":0,"colorKey":"lime","allowNegative":true,"step":1,"order":0,"soundOverride":"kazoo"}]""",
        )
        val model = CounterModel(store)
        assertEquals(1, model.counterCount)
        assertNull(model.activeCounter.soundOverride)
    }

    // Feedback fired on increment resolves through the active counter's override.
    @Test
    fun testIncrementUsesActiveCounterEffectiveFeedback() {
        val spy = FeedbackSpy()
        val model = spiedModel(
            listOf(
                Counter(
                    id = 1, name = "A", count = 0, colorKey = "lime", order = 0, soundOverride = SoundOption.OFF,
                    incrementHapticOverride = HapticOption.DOUBLE, decrementHapticOverride = HapticOption.BUZZ,
                ),
                Counter(id = 2, name = "B", count = 5, colorKey = "coffee", order = 1),
            ),
            spy,
        )
        model.effectiveFeedback = {
            val c = model.activeCounter
            EffectiveFeedback(
                c.effectiveSound(SoundOption.DING),
                c.effectiveIncrementHaptic(HapticOption.SHARP),
                c.effectiveDecrementHaptic(HapticOption.SOFT),
            )
        }
        // Counter A overrides: sound OFF (silenced); increment haptic DOUBLE pinned.
        model.increment()
        assertEquals(SoundOption.OFF, spy.calls.last().sound)
        assertEquals(HapticOption.DOUBLE, spy.calls.last().haptic)
        // Counter B follows the app defaults — increment fires the default SHARP.
        model.selectById(2)
        model.increment()
        assertEquals(SoundOption.DING, spy.calls.last().sound)
        assertEquals(HapticOption.SHARP, spy.calls.last().haptic)
        // Counter B subtract fires the default decrement haptic SOFT.
        model.subtract()
        assertEquals(HapticOption.SOFT, spy.calls.last().haptic)
    }

    // A per-counter handedness override drives the effective layout independent of
    // the app default.
    @Test
    fun testHandednessOverrideResolvesPerCounter() {
        val leftPinned = Counter(id = 1, name = "A", count = 0, colorKey = "lime", order = 0, handednessOverride = true)
        val follower = Counter(id = 2, name = "B", count = 0, colorKey = "coffee", order = 1)
        assertTrue(leftPinned.effectiveLeftHanded(false))
        assertFalse(follower.effectiveLeftHanded(false))
    }

    // Increment appends a positive event (of the counter's step) to the current run,
    // lazily opening the first run on the first change.
    @Test
    fun testIncrementRecordsPositiveEvent() {
        val model = seededModel(listOf(Counter(id = 1, name = "R", count = 0, colorKey = "lime", step = 2, order = 0)))
        var clock = 100_000L
        model.now = { clock }
        model.increment()
        clock += 5_000
        model.increment()
        val runs = model.activeHistories
        assertEquals(1, runs.size)
        assertEquals(listOf(2, 2), runs[0].events.map { it.delta })
    }

    // Subtract records the actual (negative) applied delta.
    @Test
    fun testSubtractRecordsNegativeAppliedDelta() {
        val model = seededModel(listOf(Counter(id = 1, name = "R", count = 10, colorKey = "lime", step = 3, order = 0)))
        model.subtract()
        assertEquals(listOf(-3), model.activeHistories.first().events.map { it.delta })
    }

    // The no-op subtract clamp records no event — and opens no history at all.
    @Test
    fun testNoOpSubtractClampRecordsNoEvent() {
        val model = seededModel(listOf(Counter(id = 1, name = "R", count = 0, colorKey = "lime", allowNegative = false, order = 0)))
        model.subtract()
        assertTrue(model.activeHistories.isEmpty())
    }

    // A clamped subtract that DOES change the count records the actual applied delta.
    @Test
    fun testClampedSubtractRecordsActualAppliedDelta() {
        val model = seededModel(listOf(Counter(id = 1, name = "R", count = 3, colorKey = "lime", allowNegative = false, step = 5, order = 0)))
        model.subtract()
        assertEquals(listOf(-3), model.activeHistories.first().events.map { it.delta })
    }

    // Reset seals the current run and opens a new empty run; the count zeroes.
    @Test
    fun testResetSealsCurrentAndOpensEmptyRun() {
        val model = seededModel(listOf(Counter(id = 1, name = "R", count = 0, colorKey = "lime", order = 0)))
        model.increment()
        model.increment()
        assertEquals(1, model.activeHistories.size)
        assertEquals(2, model.activeHistories.last().events.size)
        model.reset()
        assertEquals(0, model.activeCounter.count)
        assertEquals(2, model.activeHistories.size)
        assertEquals(2, model.activeHistories.first().events.size)
        assertEquals(0, model.activeHistories.last().events.size)
    }

    // The per-counter run list caps at 10, dropping the oldest once an 11th run opens.
    @Test
    fun testHistoryCapDropsOldestRun() {
        val model = seededModel(listOf(Counter(id = 1, name = "R", count = 0, colorKey = "lime", order = 0)))
        var clock = 0L
        model.now = { clock }
        model.increment() // run 1 carries the only event
        for (i in 1..11) {
            clock += (i * 60_000).toLong()
            model.reset()
        }
        assertEquals(CounterModel.MAX_HISTORIES_PER_COUNTER, model.activeHistories.size)
        assertTrue(model.activeHistories.all { it.events.isEmpty() })
    }

    // undoReset restores the count AND pops the empty run reset opened.
    @Test
    fun testUndoResetReopensSealedRunAndRestoresCount() {
        val model = seededModel(listOf(Counter(id = 1, name = "R", count = 0, colorKey = "lime", order = 0)))
        model.increment(); model.increment(); model.increment()
        assertEquals(1, model.activeHistories.size)
        model.reset()
        assertEquals(2, model.activeHistories.size)
        model.undoReset()
        assertEquals(3, model.activeCounter.count)
        assertEquals(1, model.activeHistories.size)
        assertEquals(3, model.activeHistories.last().events.size)
    }

    // Deleting a counter clears its recorded runs — a blank slot starts clean.
    @Test
    fun testDeleteCounterClearsItsHistories() {
        val model = makeModel()
        model.increment()
        assertFalse(model.activeHistories.isEmpty())
        model.deleteCounter(model.activeCounter.id)
        assertTrue(model.activeHistories.isEmpty())
    }

    // The cumulative-series helper reconstructs the running count over relative time,
    // starting from (0, 0); runningTotal is the net.
    @Test
    fun testCumulativeSeriesReconstructsRunningCount() {
        val base = 0L
        val history = CounterHistory(
            startedAt = base,
            events = mutableListOf(
                CounterEvent(at = base + 10_000, delta = 1),
                CounterEvent(at = base + 25_000, delta = 1),
                CounterEvent(at = base + 40_000, delta = -1),
            ),
        )
        assertEquals(
            listOf(
                CumulativePoint(0.0, 0),
                CumulativePoint(10.0, 1),
                CumulativePoint(25.0, 2),
                CumulativePoint(40.0, 1),
            ),
            history.cumulativeSeries(),
        )
        assertEquals(1, history.runningTotal)
    }

    // The relative-offset helper measures seconds from the run's start.
    @Test
    fun testRelativeOffsetMeasuredFromStart() {
        val base = 500_000L
        val event = CounterEvent(at = base + 73_000, delta = 1)
        val history = CounterHistory(startedAt = base, events = mutableListOf(event))
        assertEquals(73.0, history.relativeOffset(event), 0.001)
    }

    // Recorded runs persist and reload through the same store.
    @Test
    fun testHistoriesPersistAndReloadFromDefaults() {
        val store = InMemoryKeyValueStore()
        val model = CounterModel(store)
        var clock = 0L
        model.now = { clock }
        model.increment()
        clock += 30_000
        model.increment()
        val reloaded = CounterModel(store)
        assertEquals(listOf(1, 1), reloaded.histories[reloaded.activeCounter.id]?.first()?.events?.map { it.delta })
    }

    // A hand-authored history seed (JSON object keyed by counter id, epoch-millis
    // times) loads with correct deltas and relative offsets.
    @Test
    fun testSeededHistoriesJSONLoadsFromDefaults() {
        val store = InMemoryKeyValueStore()
        store.putString(CounterModel.COUNTERS_KEY, encodeCounters(listOf(Counter(id = 1, name = "PUSH-UPS", count = 3, colorKey = "lime", order = 0))))
        store.putString(
            CounterModel.HISTORIES_KEY,
            """{"1":[{"startedAt":0,"events":[{"at":10000,"delta":1},{"at":40000,"delta":1},{"at":80000,"delta":1}]}]}""",
        )
        val model = CounterModel(store)
        val runs = model.histories[1]
        assertEquals(1, runs?.size)
        assertEquals(listOf(1, 1, 1), runs?.first()?.events?.map { it.delta })
        assertEquals(40.0, runs!!.first().relativeOffset(runs.first().events[1]), 0.001)
    }

    // A release-policy launch ignores injected counter state lacking the provenance
    // marker, falling back to the four default starter counters.
    @Test
    fun testReleasePolicyIgnoresSeededCountersWithoutProvenance() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            """[{"id":1,"name":"PUSH-UPS","count":7,"colorKey":"lime","allowNegative":true,"step":1,"order":0},{"id":2,"name":"COFFEE","count":3,"colorKey":"coffee","allowNegative":true,"step":1,"order":1}]""",
        )
        val model = CounterModel(store, policy = SeedPolicy.REQUIRE_PROVENANCE)
        assertEquals(listOf("COUNTER 1", "COUNTER 2", "COUNTER 3", "COUNTER 4"), model.counters.map { it.name })
        assertEquals(listOf(0, 0, 0, 0), model.counters.map { it.count })
    }

    // The default (debug) trust policy still adopts injected state.
    @Test
    fun testTrustInjectedPolicyAdoptsSeededCounters() {
        val store = InMemoryKeyValueStore()
        store.putString(
            CounterModel.COUNTERS_KEY,
            """[{"id":1,"name":"PUSH-UPS","count":7,"colorKey":"lime","allowNegative":true,"step":1,"order":0}]""",
        )
        val model = CounterModel(store, policy = SeedPolicy.TRUST_INJECTED)
        assertEquals(7, model.activeCounter.count)
    }

    // Under the release policy, a real user's own persisted data survives: once the
    // app persists (stamping the marker), a reload trusts it.
    @Test
    fun testReleasePolicyTrustsOwnPersistedDataAfterStamp() {
        val store = InMemoryKeyValueStore()
        val model = CounterModel(store, policy = SeedPolicy.REQUIRE_PROVENANCE)
        model.increment() // persists + stamps provenance
        val reloaded = CounterModel(store, policy = SeedPolicy.REQUIRE_PROVENANCE)
        assertEquals(1, reloaded.activeCounter.count)
    }

    // AppSettings applies the same gate: a release-policy launch over an unstamped
    // store ignores injected keys and starts from the built-in defaults.
    @Test
    fun testReleasePolicyIgnoresSeededAppSettingsWithoutProvenance() {
        val store = InMemoryKeyValueStore()
        store.putBoolean(AppSettings.LEFT_HANDED_KEY, true)
        store.putString(AppSettings.SOUND_OPTION_KEY, SoundOption.DING.rawValue)
        store.putString(AppSettings.INCREMENT_HAPTIC_OPTION_KEY, HapticOption.DOUBLE.rawValue)
        store.putString(AppSettings.DECREMENT_HAPTIC_OPTION_KEY, HapticOption.BUZZ.rawValue)
        val settings = AppSettings(store, policy = SeedPolicy.REQUIRE_PROVENANCE)
        assertFalse(settings.defaultLeftHanded)
        assertEquals(SoundOption.OFF, settings.soundOption)
        assertEquals(HapticOption.SHARP, settings.incrementHapticOption)
        assertEquals(HapticOption.SOFT, settings.decrementHapticOption)
    }

    // Once the app stamps provenance, a release-policy AppSettings launch trusts the
    // store's own settings again.
    @Test
    fun testReleasePolicyTrustsAppSettingsAfterProvenanceStamped() {
        val store = InMemoryKeyValueStore()
        store.putString(AppSettings.SOUND_OPTION_KEY, SoundOption.DING.rawValue)
        SeedPolicy.stampProvenance(store)
        val settings = AppSettings(store, policy = SeedPolicy.REQUIRE_PROVENANCE)
        assertEquals(SoundOption.DING, settings.soundOption)
    }
}
