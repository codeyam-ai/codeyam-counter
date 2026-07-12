import XCTest
@testable import AppCore

// XCTest, not swift-testing — see ModelTests for the rationale.
final class FeedbackTests: XCTestCase {
    // Build a SystemCounterFeedback with spy emitters that record the options
    // they were asked to emit.
    private func spied() -> (feedback: SystemCounterFeedback,
                             haptics: () -> [HapticOption],
                             sounds: () -> [SoundOption]) {
        var hapticCalls: [HapticOption] = []
        var soundCalls: [SoundOption] = []
        let feedback = SystemCounterFeedback(
            emitHaptic: { hapticCalls.append($0) },
            emitSound: { soundCalls.append($0) })
        return (feedback, { hapticCalls }, { soundCalls })
    }

    // A non-off haptic with sound off fires only the haptic emitter, carrying the
    // chosen intensity.
    func testHapticOnlyFiresHapticWithIntensity() {
        let (feedback, haptics, sounds) = spied()
        feedback.changed(sound: .off, haptic: .sharp)
        XCTAssertEqual(haptics(), [.sharp])
        XCTAssertEqual(sounds(), [])
    }

    // A non-off sound with haptic off fires only the sound emitter, carrying the
    // chosen sound.
    func testSoundOnlyFiresSoundWithChoice() {
        let (feedback, haptics, sounds) = spied()
        feedback.changed(sound: .bloop, haptic: .off)
        XCTAssertEqual(haptics(), [])
        XCTAssertEqual(sounds(), [.bloop])
    }

    // Both non-off → both emitters fire once with their respective choices.
    func testBothOptionsFireBoth() {
        let (feedback, haptics, sounds) = spied()
        feedback.changed(sound: .tock, haptic: .soft)
        XCTAssertEqual(haptics(), [.soft])
        XCTAssertEqual(sounds(), [.tock])
    }

    // Both off → nothing fires.
    func testBothOffFiresNothing() {
        let (feedback, haptics, sounds) = spied()
        feedback.changed(sound: .off, haptic: .off)
        XCTAssertEqual(haptics(), [])
        XCTAssertEqual(sounds(), [])
    }

    // Every qualitatively-distinct feel gates the same way: non-`.off`, so each
    // fires the haptic emitter once carrying its own choice — the two impacts
    // (`soft`/`sharp`) and the two notification patterns (`double`/`buzz`).
    func testAllDistinctFeelsAreTreatedAsNonOff() {
        let (feedback, haptics, _) = spied()
        feedback.changed(sound: .off, haptic: .soft)
        feedback.changed(sound: .off, haptic: .sharp)
        feedback.changed(sound: .off, haptic: .double)
        feedback.changed(sound: .off, haptic: .buzz)
        XCTAssertEqual(haptics(), [.soft, .sharp, .double, .buzz])
    }

    // The no-op default implementation never touches its arguments — a smoke
    // check that calling it with any options is safe and silent.
    func testNoopFeedbackDoesNothing() {
        let noop = NoopCounterFeedback()
        noop.changed(sound: .ding, haptic: .double)
        noop.changed(sound: .off, haptic: .off)
    }
}
