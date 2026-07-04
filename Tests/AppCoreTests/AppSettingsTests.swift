import XCTest
@testable import AppCore

// XCTest, not swift-testing — see ModelTests for the rationale.
final class AppSettingsTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    // A fresh store with nothing seeded is right-handed with sound and haptic off.
    func testDefaultsAreRightHandedAndSilent() {
        let settings = AppSettings(defaults: makeSuite())
        XCTAssertFalse(settings.defaultLeftHanded)
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertEqual(settings.hapticOption, .off)
    }

    // The store reads seeded preferences, including the string-injected form the
    // editor writes via `defaults write` (enum rawValue via string(forKey:)).
    func testReadsSeededStringPreferences() {
        let suite = makeSuite()
        suite.set("1", forKey: AppSettings.leftHandedKey)
        suite.set("ding", forKey: AppSettings.soundOptionKey)
        suite.set("medium", forKey: AppSettings.hapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertTrue(settings.defaultLeftHanded)
        XCTAssertEqual(settings.soundOption, .ding)
        XCTAssertEqual(settings.hapticOption, .medium)
    }

    // An unrecognized or missing option rawValue falls back to .off.
    func testUnknownOptionFallsBackToOff() {
        let suite = makeSuite()
        suite.set("kazoo", forKey: AppSettings.soundOptionKey)
        // hapticOption key left unset entirely
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertEqual(settings.hapticOption, .off)
    }

    // Changing a setting persists it: a second store over the same suite reads
    // the written values back.
    func testPersistsChangesAcrossReload() {
        let suite = makeSuite()
        let settings = AppSettings(defaults: suite)
        settings.defaultLeftHanded = true
        settings.soundOption = .pop
        settings.hapticOption = .heavy

        let reloaded = AppSettings(defaults: suite)
        XCTAssertTrue(reloaded.defaultLeftHanded)
        XCTAssertEqual(reloaded.soundOption, .pop)
        XCTAssertEqual(reloaded.hapticOption, .heavy)
    }

    // Each key is independent — changing one does not disturb the others.
    func testOptionsAreIndependent() {
        let suite = makeSuite()
        let settings = AppSettings(defaults: suite)
        settings.hapticOption = .light
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertFalse(settings.defaultLeftHanded)
        XCTAssertEqual(settings.hapticOption, .light)
    }

    // The option enums expose the full choice sets the settings picker renders.
    func testOptionCasesCoverTheChoiceSets() {
        XCTAssertEqual(SoundOption.allCases, [.off, .tock, .pop, .click, .bloop, .ding])
        XCTAssertEqual(HapticOption.allCases, [.off, .light, .medium, .heavy])
        XCTAssertEqual(SoundOption.ding.label, "DING")
        XCTAssertEqual(HapticOption.light.label, "LIGHT")
    }
}
