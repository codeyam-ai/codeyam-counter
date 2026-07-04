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
        feedback.changed(sound: .off, haptic: .heavy)
        XCTAssertEqual(haptics(), [.heavy])
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
        feedback.changed(sound: .tock, haptic: .light)
        XCTAssertEqual(haptics(), [.light])
        XCTAssertEqual(sounds(), [.tock])
    }

    // Both off → nothing fires.
    func testBothOffFiresNothing() {
        let (feedback, haptics, sounds) = spied()
        feedback.changed(sound: .off, haptic: .off)
        XCTAssertEqual(haptics(), [])
        XCTAssertEqual(sounds(), [])
    }

    // The no-op default implementation never touches its arguments — a smoke
    // check that calling it with any options is safe and silent.
    func testNoopFeedbackDoesNothing() {
        let noop = NoopCounterFeedback()
        noop.changed(sound: .ding, haptic: .medium)
        noop.changed(sound: .off, haptic: .off)
    }
}
