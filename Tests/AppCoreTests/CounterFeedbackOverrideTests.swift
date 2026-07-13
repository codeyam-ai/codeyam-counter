import XCTest
@testable import AppCore

// XCTest, not swift-testing: the editor's runner parses the XCTest
// `--xunit-output` file (see ModelTests for the full rationale).
//
// Covers `Counter.hasFeedbackOverride`, the heuristic that decides whether the
// settings panel's FEEDBACK & HANDEDNESS section opens on appear.
final class CounterFeedbackOverrideTests: XCTestCase {
    // A counter left on pure app-wide defaults pins nothing, so the section
    // stays collapsed.
    func testNoOverridesReturnsFalse() {
        let counter = Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0)
        XCTAssertFalse(counter.hasFeedbackOverride)
    }

    // A handedness override alone is enough to open the section.
    func testHandednessOverrideAloneReturnsTrue() {
        let counter = Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0,
                              handednessOverride: true)
        XCTAssertTrue(counter.hasFeedbackOverride)
    }

    // A sound override alone is enough to open the section.
    func testSoundOverrideAloneReturnsTrue() {
        let counter = Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0,
                              soundOverride: .ding)
        XCTAssertTrue(counter.hasFeedbackOverride)
    }

    // An increment-haptic override alone is enough to open the section.
    func testIncrementHapticOverrideAloneReturnsTrue() {
        let counter = Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0,
                              incrementHapticOverride: .sharp)
        XCTAssertTrue(counter.hasFeedbackOverride)
    }

    // A decrement-haptic override alone is enough to open the section.
    func testDecrementHapticOverrideAloneReturnsTrue() {
        let counter = Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0,
                              decrementHapticOverride: .soft)
        XCTAssertTrue(counter.hasFeedbackOverride)
    }

    // An explicit `.off` sound is a deliberate pin, not the absence of one, so it
    // still counts as an override — a non-nil value, not the default fall-through.
    func testExplicitOffSoundOverrideReturnsTrue() {
        let counter = Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0,
                              soundOverride: .off)
        XCTAssertTrue(counter.hasFeedbackOverride)
    }

    // Every override pinned at once still reads true.
    func testAllOverridesSetReturnsTrue() {
        let counter = Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0,
                              handednessOverride: false, soundOverride: .off,
                              incrementHapticOverride: .double, decrementHapticOverride: .buzz)
        XCTAssertTrue(counter.hasFeedbackOverride)
    }

    // A blank slot (no name, no overrides) leaves the section collapsed.
    func testBlankSlotReturnsFalse() {
        let counter = Counter(id: 1, name: "", count: 0, colorKey: "", order: 0)
        XCTAssertFalse(counter.hasFeedbackOverride)
    }
}
