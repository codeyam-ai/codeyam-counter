import XCTest
@testable import AppCore

// XCTest, not swift-testing — see ModelTests for the rationale.
final class AppSettingsTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    // A fresh store with nothing seeded is right-handed, silent, and carries the
    // distinct default haptic pairing: increment Rigid, decrement Soft.
    func testDefaultsAreRightHandedSilentWithDistinctHaptics() {
        let settings = AppSettings(defaults: makeSuite())
        XCTAssertFalse(settings.defaultLeftHanded)
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertEqual(settings.incrementHapticOption, .rigid)
        XCTAssertEqual(settings.decrementHapticOption, .soft)
    }

    // The "must feel different" guarantee, pinned: the two default haptics are
    // qualitatively distinct, not the same tap.
    func testDefaultHapticsAreDistinct() {
        let settings = AppSettings(defaults: makeSuite())
        XCTAssertNotEqual(settings.incrementHapticOption, settings.decrementHapticOption)
    }

    // The store reads seeded preferences, including the string-injected form the
    // editor writes via `defaults write` (enum rawValue via string(forKey:)),
    // including the two new `soft`/`rigid` values.
    func testReadsSeededStringPreferences() {
        let suite = makeSuite()
        suite.set("1", forKey: AppSettings.leftHandedKey)
        suite.set("ding", forKey: AppSettings.soundOptionKey)
        suite.set("soft", forKey: AppSettings.incrementHapticOptionKey)
        suite.set("rigid", forKey: AppSettings.decrementHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertTrue(settings.defaultLeftHanded)
        XCTAssertEqual(settings.soundOption, .ding)
        XCTAssertEqual(settings.incrementHapticOption, .soft)
        XCTAssertEqual(settings.decrementHapticOption, .rigid)
    }

    // An unrecognized option rawValue falls back to the built-in default; a
    // missing haptic key likewise falls back (to its direction's default).
    func testUnknownOptionFallsBackToDefault() {
        let suite = makeSuite()
        suite.set("kazoo", forKey: AppSettings.soundOptionKey)
        suite.set("buzz", forKey: AppSettings.incrementHapticOptionKey)
        // decrement key left unset entirely
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertEqual(settings.incrementHapticOption, .rigid)
        XCTAssertEqual(settings.decrementHapticOption, .soft)
    }

    // Legacy migration: a user who tuned the pre-split single `hapticOption` key
    // (and has neither new key) adopts that value for BOTH directions.
    func testLegacyHapticKeyMigratesToBothDirections() {
        let suite = makeSuite()
        suite.set("heavy", forKey: AppSettings.legacyHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.incrementHapticOption, .heavy)
        XCTAssertEqual(settings.decrementHapticOption, .heavy)
    }

    // A legacy "off" is respected — both directions stay silent, not reset to the
    // new Rigid/Soft defaults.
    func testLegacyHapticOffMigratesToBothOff() {
        let suite = makeSuite()
        suite.set("off", forKey: AppSettings.legacyHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.incrementHapticOption, .off)
        XCTAssertEqual(settings.decrementHapticOption, .off)
    }

    // A new per-direction key wins over the legacy key when both are present.
    func testNewHapticKeyWinsOverLegacy() {
        let suite = makeSuite()
        suite.set("heavy", forKey: AppSettings.legacyHapticOptionKey)
        suite.set("light", forKey: AppSettings.incrementHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.incrementHapticOption, .light)   // new key
        XCTAssertEqual(settings.decrementHapticOption, .heavy)   // migrated legacy
    }

    // Changing a setting persists it: a second store over the same suite reads
    // the written values back.
    func testPersistsChangesAcrossReload() {
        let suite = makeSuite()
        let settings = AppSettings(defaults: suite)
        settings.defaultLeftHanded = true
        settings.soundOption = .pop
        settings.incrementHapticOption = .heavy
        settings.decrementHapticOption = .light

        let reloaded = AppSettings(defaults: suite)
        XCTAssertTrue(reloaded.defaultLeftHanded)
        XCTAssertEqual(reloaded.soundOption, .pop)
        XCTAssertEqual(reloaded.incrementHapticOption, .heavy)
        XCTAssertEqual(reloaded.decrementHapticOption, .light)
    }

    // Each key is independent — changing one does not disturb the others.
    func testOptionsAreIndependent() {
        let suite = makeSuite()
        let settings = AppSettings(defaults: suite)
        settings.incrementHapticOption = .light
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertFalse(settings.defaultLeftHanded)
        XCTAssertEqual(settings.incrementHapticOption, .light)
        XCTAssertEqual(settings.decrementHapticOption, .soft)   // untouched default
    }

    // A distribution-policy launch over an unstamped container ignores injected
    // keys (including the legacy key) and starts from the Rigid/Soft defaults.
    func testReleasePolicyIgnoresSeededHapticsWithoutProvenance() {
        let suite = makeSuite()
        suite.set("light", forKey: AppSettings.incrementHapticOptionKey)
        suite.set("off", forKey: AppSettings.legacyHapticOptionKey)
        let settings = AppSettings(defaults: suite, policy: .requireProvenance)
        XCTAssertEqual(settings.incrementHapticOption, .rigid)
        XCTAssertEqual(settings.decrementHapticOption, .soft)
    }

    // The option enums expose the full choice sets the settings picker renders.
    func testOptionCasesCoverTheChoiceSets() {
        XCTAssertEqual(SoundOption.allCases, [.off, .tock, .pop, .click, .bloop, .ding])
        XCTAssertEqual(HapticOption.allCases, [.off, .light, .medium, .heavy, .soft, .rigid])
        XCTAssertEqual(SoundOption.ding.label, "DING")
        XCTAssertEqual(HapticOption.light.label, "LIGHT")
        XCTAssertEqual(HapticOption.soft.label, "SOFT")
        XCTAssertEqual(HapticOption.rigid.label, "RIGID")
    }
}
