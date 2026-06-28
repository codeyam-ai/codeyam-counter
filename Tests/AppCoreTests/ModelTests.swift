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

    // MARK: - Delete & restore

    // Deleting a default removes it, records its id as a ghost slot, and keeps
    // the selection in range by selecting a neighbor.
    func testDeleteDefaultRemovesAndRecordsGhost() {
        let model = makeModel() // PUSH-UPS, COFFEE, STEPS, BUGS
        model.select(id: 2) // COFFEE active
        model.deleteCounter(id: 2)
        XCTAssertEqual(model.counterCount, 3)
        XCTAssertFalse(model.counters.contains { $0.id == 2 })
        XCTAssertTrue(model.deletedDefaultIds.contains(2))
        XCTAssertEqual(model.ghostSlots.map(\.id), [2])
        // Selection stayed in range (neighbor that slid into index 1).
        XCTAssertTrue(model.counters.indices.contains(model.selectedIndex))
        XCTAssertEqual(model.activeCounter.id, 3)
    }

    // Deleting the active last counter clamps the selection back into range.
    func testDeleteLastCounterClampsSelection() {
        let model = makeModel()
        model.select(index: 3) // BUGS, the last
        model.deleteCounter(id: model.activeCounter.id)
        XCTAssertEqual(model.counterCount, 3)
        XCTAssertEqual(model.selectedIndex, 2)
    }

    // Restoring a deleted default re-adds it at 0, clears its ghost slot, places
    // it back in order, and selects it.
    func testRestoreDefaultReaddsAtZeroAndSelects() {
        let model = makeModel()
        model.deleteCounter(id: 3) // delete STEPS
        XCTAssertEqual(model.ghostSlots.map(\.id), [3])
        model.restoreDefault(id: 3)
        XCTAssertEqual(model.counterCount, 4)
        XCTAssertFalse(model.deletedDefaultIds.contains(3))
        let restored = model.counters.first { $0.id == 3 }
        XCTAssertEqual(restored?.count, 0)
        XCTAssertEqual(restored?.name, "STEPS")
        XCTAssertEqual(model.activeCounter.id, 3)
        // Re-added in its original order position.
        XCTAssertEqual(model.counters.map(\.id), [1, 2, 3, 4])
    }

    // A scenario that seeds a subset of counters shows no ghost dots — ghosts are
    // tracked explicitly, never inferred from a default id simply being absent.
    func testSeededSubsetHasNoGhostSlots() {
        let model = seededModel([
            Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0),
            Counter(id: 2, name: "COFFEE", count: 0, colorKey: "coffee", order: 1),
        ])
        XCTAssertEqual(model.counterCount, 2)
        XCTAssertTrue(model.ghostSlots.isEmpty)
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
}
