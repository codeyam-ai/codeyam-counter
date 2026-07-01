import XCTest
@testable import AppCore

// XCTest, not swift-testing: the editor's runner parses the XCTest
// `--xunit-output` file, and swift-testing results do not reliably land there
// on Xcode 16.x / Swift 6.x. See README "## Testing" for the full rationale.
final class ModelTests: XCTestCase {
    // Builds a model backed by an isolated, empty UserDefaults suite so tests
    // never read or write the shared `.standard` domain and never race.
    private func makeModel() -> CounterModel {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return CounterModel(defaults: suite)
    }

    // Builds a model whose counters are seeded into an isolated suite via the
    // same JSON contract the editor uses, so step/allowNegative survive a load.
    private func seededModel(_ counters: [Counter]) -> CounterModel {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let json = String(data: try! JSONEncoder().encode(counters), encoding: .utf8)!
        suite.set(json, forKey: CounterModel.countersKey)
        return CounterModel(defaults: suite)
    }

    // A fresh model with no seeded state falls back to the four-counter starter
    // set, all at zero, with the first counter selected.
    func testFreshModelHasFourStarterCountersAtZero() {
        let model = makeModel()
        XCTAssertEqual(model.counterCount, 4)
        XCTAssertTrue(model.counters.allSatisfy { $0.count == 0 })
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertEqual(model.activeCounter.name, "PUSH-UPS")
    }

    // Incrementing raises only the active counter's count by one.
    func testIncrementRaisesActiveCounter() {
        let model = makeModel()
        XCTAssertEqual(model.activeCounter.count, 0)
        model.increment()
        XCTAssertEqual(model.activeCounter.count, 1)
        XCTAssertEqual(model.counters[1].count, 0)
    }

    // With the default `allowNegative == true`, subtracting from zero produces a
    // negative count.
    func testSubtractGoesNegativeByDefault() {
        let model = makeModel()
        model.subtract()
        XCTAssertEqual(model.activeCounter.count, -1)
    }

    // A counter configured with `allowNegative == false` clamps at zero instead
    // of going negative.
    func testSubtractClampsWhenNegativesDisallowed() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let counters = [Counter(id: 1, name: "REPS", count: 0, colorKey: "lime", allowNegative: false, order: 0)]
        let json = String(data: try! JSONEncoder().encode(counters), encoding: .utf8)!
        suite.set(json, forKey: CounterModel.countersKey)
        let model = CounterModel(defaults: suite)
        model.subtract()
        XCTAssertEqual(model.activeCounter.count, 0)
    }

    // Reset zeroes the active counter without touching the others.
    func testResetZeroesActiveCounter() {
        let model = makeModel()
        model.increment()
        model.increment()
        XCTAssertEqual(model.activeCounter.count, 2)
        model.reset()
        XCTAssertEqual(model.activeCounter.count, 0)
    }

    // Swiping forward advances selection and wraps past the last counter back to
    // the first.
    func testSelectNextWrapsAround() {
        let model = makeModel()
        model.selectNext()
        XCTAssertEqual(model.selectedIndex, 1)
        model.select(index: model.counterCount - 1)
        model.selectNext()
        XCTAssertEqual(model.selectedIndex, 0)
    }

    // MARK: - Step ("count by")

    // A counter with step 5 increments in jumps of 5 (0 → 5 → 10).
    func testIncrementHonorsStep() {
        let model = seededModel([
            Counter(id: 1, name: "REPS", count: 0, colorKey: "lime", step: 5, order: 0),
        ])
        model.increment()
        XCTAssertEqual(model.activeCounter.count, 5)
        model.increment()
        XCTAssertEqual(model.activeCounter.count, 10)
    }

    // Subtracting honors the step symmetrically when negatives are allowed.
    func testSubtractHonorsStep() {
        let model = seededModel([
            Counter(id: 1, name: "REPS", count: 10, colorKey: "lime", step: 4, order: 0),
        ])
        model.subtract()
        XCTAssertEqual(model.activeCounter.count, 6)
    }

    // With negatives disallowed, a step that would overshoot below zero clamps
    // to zero rather than skipping the change.
    func testSubtractClampsToZeroWhenStepOvershoots() {
        let model = seededModel([
            Counter(id: 1, name: "REPS", count: 3, colorKey: "lime", allowNegative: false, step: 5, order: 0),
        ])
        model.subtract()
        XCTAssertEqual(model.activeCounter.count, 0)
        // Already at zero: a further subtract makes no change.
        model.subtract()
        XCTAssertEqual(model.activeCounter.count, 0)
    }

    // Counters persisted before `step` existed decode with step defaulting to 1.
    func testLegacyCounterWithoutStepDecodesToStepOne() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let legacyJSON = #"[{"id":1,"name":"PUSH-UPS","count":2,"colorKey":"lime","allowNegative":true,"order":0}]"#
        suite.set(legacyJSON, forKey: CounterModel.countersKey)
        let model = CounterModel(defaults: suite)
        XCTAssertEqual(model.activeCounter.step, 1)
        model.increment()
        XCTAssertEqual(model.activeCounter.count, 3)
    }

    // MARK: - Editing

    // updateActiveCounter applies every edited field and persists across reloads.
    func testUpdateActiveCounterEditsAndPersists() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let model = CounterModel(defaults: suite)
        model.updateActiveCounter(name: "MEDITATION", colorKey: "rose", allowNegative: false, step: 3)
        XCTAssertEqual(model.activeCounter.name, "MEDITATION")
        XCTAssertEqual(model.activeCounter.colorKey, "rose")
        XCTAssertFalse(model.activeCounter.allowNegative)
        XCTAssertEqual(model.activeCounter.step, 3)
        // Reload from the same suite to confirm persistence.
        let reloaded = CounterModel(defaults: suite)
        XCTAssertEqual(reloaded.activeCounter.name, "MEDITATION")
        XCTAssertEqual(reloaded.activeCounter.step, 3)
    }

    // A step below 1 is clamped up to 1.
    func testUpdateActiveCounterClampsStepToAtLeastOne() {
        let model = makeModel()
        model.updateActiveCounter(name: "X", colorKey: "lime", allowNegative: true, step: 0)
        XCTAssertEqual(model.activeCounter.step, 1)
    }

    // MARK: - Delete (blank in place) & revive

    // Deleting a counter blanks it in place rather than removing it: the row
    // length is unchanged, the id is still present, its name is empty (isBlank),
    // its count is reset to 0, and it stays selected so it can be revived.
    func testDeleteBlanksInPlace() {
        let model = makeModel() // PUSH-UPS, COFFEE, STEPS, BUGS
        model.select(id: 2) // COFFEE active
        model.increment()   // give it a non-zero count first
        model.deleteCounter(id: 2)
        XCTAssertEqual(model.counterCount, 4)
        let blanked = model.counters.first { $0.id == 2 }
        XCTAssertNotNil(blanked)
        XCTAssertTrue(blanked!.isBlank)
        XCTAssertEqual(blanked!.name, "")
        XCTAssertEqual(blanked!.count, 0)
        // Stays selected on the blanked slot for immediate revival.
        XCTAssertEqual(model.activeCounter.id, 2)
    }

    // A blanked slot stays selectable and increments into a solid blank dot
    // without resurrecting a name — incrementing does not clear blankness.
    func testBlankSlotIncrementsWithoutReviving() {
        let model = makeModel()
        model.deleteCounter(id: 3) // blank STEPS, stays selected
        XCTAssertTrue(model.activeCounter.isBlank)
        model.increment()
        XCTAssertEqual(model.activeCounter.count, 1)
        XCTAssertTrue(model.activeCounter.isBlank, "increment must not revive a blank slot")
    }

    // Giving a blank slot a name via settings revives it — it stops being blank.
    func testNamingBlankSlotRevivesIt() {
        let model = makeModel()
        model.deleteCounter(id: 3) // blank STEPS, stays selected
        XCTAssertTrue(model.activeCounter.isBlank)
        model.updateActiveCounter(name: "YOGA", colorKey: "mint", allowNegative: true, step: 1)
        XCTAssertFalse(model.activeCounter.isBlank)
        XCTAssertEqual(model.activeCounter.name, "YOGA")
    }

    // Deleting the last counter blanks it in place: the row length is unchanged
    // and the blanked slot stays selected (no selection clamp, since nothing is
    // removed).
    func testDeleteLastCounterBlanksInPlaceAndKeepsSelection() {
        let model = makeModel()
        model.select(index: 3) // BUGS, the last
        model.deleteCounter(id: model.activeCounter.id)
        XCTAssertEqual(model.counterCount, 4)
        XCTAssertEqual(model.selectedIndex, 3)
        XCTAssertTrue(model.activeCounter.isBlank)
    }

    // Legacy migration: a model seeded with `deletedDefaultIds` and a counters
    // array missing those ids exposes blank counters at the right orders (so a
    // user who deleted a default under the old model still sees a blank slot).
    func testMigrationFoldsDeletedDefaultsIntoBlankSlots() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let counters = [
            Counter(id: 1, name: "PUSH-UPS", count: 7, colorKey: "lime", order: 0),
            Counter(id: 3, name: "STEPS", count: 8421, colorKey: "steps", order: 2),
        ]
        let json = String(data: try! JSONEncoder().encode(counters), encoding: .utf8)!
        suite.set(json, forKey: CounterModel.countersKey)
        suite.set("[2, 4]", forKey: CounterModel.deletedDefaultsKey)
        let model = CounterModel(defaults: suite)
        // Two live counters + two migrated blank slots, in order.
        XCTAssertEqual(model.counters.map(\.id), [1, 2, 3, 4])
        let blank2 = model.counters.first { $0.id == 2 }
        let blank4 = model.counters.first { $0.id == 4 }
        XCTAssertTrue(blank2?.isBlank ?? false)
        XCTAssertEqual(blank2?.count, 0)
        XCTAssertEqual(blank2?.order, 1)
        XCTAssertTrue(blank4?.isBlank ?? false)
        XCTAssertEqual(blank4?.order, 3)
    }

    // A scenario that seeds a subset of counters (with no deletedDefaultIds) has
    // no blank slots — absence of a default id no longer sprouts a slot.
    func testSeededSubsetHasNoBlankSlots() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0),
            Counter(id: 2, name: "COFFEE", count: 0, colorKey: "coffee", order: 1),
        ])
        XCTAssertEqual(model.counterCount, 2)
        XCTAssertFalse(model.counters.contains { $0.isBlank })
    }

    // The model loads seeded counters and the selected id injected via
    // UserDefaults (the native scenario seed contract).
    func testLoadsSeededStateFromDefaults() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let counters = [
            Counter(id: 1, name: "PUSH-UPS", count: 7, colorKey: "lime", order: 0),
            Counter(id: 2, name: "COFFEE", count: 3, colorKey: "coffee", order: 1),
        ]
        let json = String(data: try! JSONEncoder().encode(counters), encoding: .utf8)!
        suite.set(json, forKey: CounterModel.countersKey)
        suite.set(2, forKey: CounterModel.selectedKey)
        let model = CounterModel(defaults: suite)
        XCTAssertEqual(model.counterCount, 2)
        XCTAssertEqual(model.selectedIndex, 1)
        XCTAssertEqual(model.activeCounter.count, 3)
    }

    // MARK: - Undo reset

    // Reset captures the pre-reset value and enters undo mode: the count is now
    // zero and canUndoReset is true for the active counter.
    func testResetEntersUndoModeAndCapturesPreviousValue() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 9, colorKey: "lime", order: 0),
        ])
        XCTAssertFalse(model.canUndoReset)
        model.reset()
        XCTAssertEqual(model.activeCounter.count, 0)
        XCTAssertTrue(model.canUndoReset)
        XCTAssertEqual(model.resetUndo, ResetUndo(counterId: 1, previousCount: 9))
    }

    // undoReset restores the captured value and exits undo mode.
    func testUndoResetRestoresPreviousValueAndExitsUndoMode() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 9, colorKey: "lime", order: 0),
        ])
        model.reset()
        model.undoReset()
        XCTAssertEqual(model.activeCounter.count, 9)
        XCTAssertFalse(model.canUndoReset)
        XCTAssertNil(model.resetUndo)
    }

    // Resetting a counter already at zero still enters undo mode for a consistent
    // affordance; undoing that restores zero (a harmless no-op).
    func testResetAtZeroEntersUndoModeAndUndoRestoresZero() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0),
        ])
        model.reset()
        XCTAssertTrue(model.canUndoReset)
        model.undoReset()
        XCTAssertEqual(model.activeCounter.count, 0)
        XCTAssertFalse(model.canUndoReset)
    }

    // Incrementing — the counter "starting again" — clears the pending undo.
    func testIncrementClearsPendingUndo() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 4, colorKey: "lime", order: 0),
        ])
        model.reset()
        XCTAssertTrue(model.canUndoReset)
        model.increment()
        XCTAssertFalse(model.canUndoReset)
        XCTAssertNil(model.resetUndo)
    }

    // Subtracting also clears the pending undo.
    func testSubtractClearsPendingUndo() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 4, colorKey: "lime", order: 0),
        ])
        model.reset()
        XCTAssertTrue(model.canUndoReset)
        model.subtract()
        XCTAssertFalse(model.canUndoReset)
    }

    // Switching counters expires the undo offer — the captured value belonged to
    // the counter we left.
    func testSwitchingCounterClearsPendingUndo() {
        let model = makeModel() // PUSH-UPS, COFFEE, STEPS, BUGS
        model.increment()       // PUSH-UPS -> 1
        model.reset()
        XCTAssertTrue(model.canUndoReset)
        model.selectNext()      // move to COFFEE
        XCTAssertFalse(model.canUndoReset)
        XCTAssertNil(model.resetUndo)
        // Returning to the original counter does not revive the offer.
        model.select(id: 1)
        XCTAssertFalse(model.canUndoReset)
    }

    // Editing the active counter invalidates the captured pre-reset value.
    func testEditingActiveCounterClearsPendingUndo() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 4, colorKey: "lime", order: 0),
        ])
        model.reset()
        XCTAssertTrue(model.canUndoReset)
        model.updateActiveCounter(name: "PUSH-UPS", colorKey: "lime", allowNegative: true, step: 1)
        XCTAssertFalse(model.canUndoReset)
    }

    // Deleting a counter clears the pending undo.
    func testDeletingCounterClearsPendingUndo() {
        let model = makeModel()
        model.increment()
        model.reset()
        XCTAssertTrue(model.canUndoReset)
        model.deleteCounter(id: model.activeCounter.id)
        XCTAssertFalse(model.canUndoReset)
    }

    // A model seeded with the resetUndo key enters undo mode on launch when the
    // active counter is at zero (the static-scenario seed path).
    func testSeededResetUndoKeyEntersUndoModeOnLaunch() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let counters = [Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0)]
        let json = String(data: try! JSONEncoder().encode(counters), encoding: .utf8)!
        suite.set(json, forKey: CounterModel.countersKey)
        suite.set(1, forKey: CounterModel.selectedKey)
        suite.set(12, forKey: CounterModel.resetUndoKey)
        let model = CounterModel(defaults: suite)
        XCTAssertTrue(model.canUndoReset)
        XCTAssertEqual(model.resetUndo, ResetUndo(counterId: 1, previousCount: 12))
    }

    // The seed read coerces a string-injected value (the editor injects
    // `defaults write` values as strings) via integer(forKey:).
    func testSeededResetUndoKeyCoercesStringValue() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let counters = [Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0)]
        let json = String(data: try! JSONEncoder().encode(counters), encoding: .utf8)!
        suite.set(json, forKey: CounterModel.countersKey)
        suite.set("12", forKey: CounterModel.resetUndoKey)
        let model = CounterModel(defaults: suite)
        XCTAssertTrue(model.canUndoReset)
        XCTAssertEqual(model.resetUndo?.previousCount, 12)
    }

    // The seed is rejected when the active counter is not at zero: a real pending
    // undo is always a post-reset state, so a non-zero count means the key is a
    // stale leftover (the editor's seed leaves the key set across scenario loads)
    // and must not falsely activate UNDO RESET.
    func testSeededResetUndoKeyIgnoredWhenActiveCountNonZero() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let counters = [Counter(id: 1, name: "PUSH-UPS", count: 7, colorKey: "lime", order: 0)]
        let json = String(data: try! JSONEncoder().encode(counters), encoding: .utf8)!
        suite.set(json, forKey: CounterModel.countersKey)
        suite.set(1, forKey: CounterModel.selectedKey)
        suite.set(12, forKey: CounterModel.resetUndoKey)
        let model = CounterModel(defaults: suite)
        XCTAssertFalse(model.canUndoReset)
        XCTAssertNil(model.resetUndo)
    }
}
