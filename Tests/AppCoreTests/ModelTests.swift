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
