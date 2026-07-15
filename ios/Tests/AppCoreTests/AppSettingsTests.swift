import XCTest
@testable import AppCore

// XCTest, not swift-testing — see ModelTests for the rationale.
final class AppSettingsTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    // A fresh store with nothing seeded is right-handed, silent, and carries the
    // distinct default haptic pairing: increment Sharp, decrement Soft.
    func testDefaultsAreRightHandedSilentWithDistinctHaptics() {
        let settings = AppSettings(defaults: makeSuite())
        XCTAssertFalse(settings.defaultLeftHanded)
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertEqual(settings.incrementHapticOption, .sharp)
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
    // including the `soft`/`sharp` values.
    func testReadsSeededStringPreferences() {
        let suite = makeSuite()
        suite.set("1", forKey: AppSettings.leftHandedKey)
        suite.set("ding", forKey: AppSettings.soundOptionKey)
        suite.set("soft", forKey: AppSettings.incrementHapticOptionKey)
        suite.set("sharp", forKey: AppSettings.decrementHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertTrue(settings.defaultLeftHanded)
        XCTAssertEqual(settings.soundOption, .ding)
        XCTAssertEqual(settings.incrementHapticOption, .soft)
        XCTAssertEqual(settings.decrementHapticOption, .sharp)
    }

    // An unrecognized option rawValue falls back to the built-in default; a
    // missing haptic key likewise falls back (to its direction's default).
    func testUnknownOptionFallsBackToDefault() {
        let suite = makeSuite()
        suite.set("kazoo", forKey: AppSettings.soundOptionKey)
        suite.set("wobble", forKey: AppSettings.incrementHapticOptionKey)
        // decrement key left unset entirely
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertEqual(settings.incrementHapticOption, .sharp)
        XCTAssertEqual(settings.decrementHapticOption, .soft)
    }

    // Legacy migration: a user who tuned the pre-split single `hapticOption` key
    // (and has neither new key) adopts that value for BOTH directions. A stored
    // amplitude value (`heavy`) migrates to its nearest surviving feel (`sharp`).
    func testLegacyHapticKeyMigratesToBothDirections() {
        let suite = makeSuite()
        suite.set("heavy", forKey: AppSettings.legacyHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.incrementHapticOption, .sharp)
        XCTAssertEqual(settings.decrementHapticOption, .sharp)
    }

    // A legacy "off" is respected — both directions stay silent, not reset to the
    // new Sharp/Soft defaults.
    func testLegacyHapticOffMigratesToBothOff() {
        let suite = makeSuite()
        suite.set("off", forKey: AppSettings.legacyHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.incrementHapticOption, .off)
        XCTAssertEqual(settings.decrementHapticOption, .off)
    }

    // A new per-direction key wins over the legacy key when both are present.
    // The legacy amplitude value (`heavy`) still migrates to `sharp`.
    func testNewHapticKeyWinsOverLegacy() {
        let suite = makeSuite()
        suite.set("heavy", forKey: AppSettings.legacyHapticOptionKey)
        suite.set("double", forKey: AppSettings.incrementHapticOptionKey)
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.incrementHapticOption, .double)  // new key
        XCTAssertEqual(settings.decrementHapticOption, .sharp)   // migrated legacy
    }

    // Changing a setting persists it: a second store over the same suite reads
    // the written values back.
    func testPersistsChangesAcrossReload() {
        let suite = makeSuite()
        let settings = AppSettings(defaults: suite)
        settings.defaultLeftHanded = true
        settings.soundOption = .pop
        settings.incrementHapticOption = .double
        settings.decrementHapticOption = .buzz

        let reloaded = AppSettings(defaults: suite)
        XCTAssertTrue(reloaded.defaultLeftHanded)
        XCTAssertEqual(reloaded.soundOption, .pop)
        XCTAssertEqual(reloaded.incrementHapticOption, .double)
        XCTAssertEqual(reloaded.decrementHapticOption, .buzz)
    }

    // Each key is independent — changing one does not disturb the others.
    func testOptionsAreIndependent() {
        let suite = makeSuite()
        let settings = AppSettings(defaults: suite)
        settings.incrementHapticOption = .double
        XCTAssertEqual(settings.soundOption, .off)
        XCTAssertFalse(settings.defaultLeftHanded)
        XCTAssertEqual(settings.incrementHapticOption, .double)
        XCTAssertEqual(settings.decrementHapticOption, .soft)   // untouched default
    }

    // A distribution-policy launch over an unstamped container ignores injected
    // keys (including the legacy key) and starts from the Sharp/Soft defaults.
    func testReleasePolicyIgnoresSeededHapticsWithoutProvenance() {
        let suite = makeSuite()
        suite.set("double", forKey: AppSettings.incrementHapticOptionKey)
        suite.set("off", forKey: AppSettings.legacyHapticOptionKey)
        let settings = AppSettings(defaults: suite, policy: .requireProvenance)
        XCTAssertEqual(settings.incrementHapticOption, .sharp)
        XCTAssertEqual(settings.decrementHapticOption, .soft)
    }

    // `resolve(...)` migrates removed amplitude/`rigid` rawValues to their nearest
    // surviving feel, passes current cases through, and rejects unknown tokens.
    func testResolveMigratesRemovedRawValues() {
        XCTAssertEqual(HapticOption.resolve("rigid"), .sharp)
        XCTAssertEqual(HapticOption.resolve("heavy"), .sharp)
        XCTAssertEqual(HapticOption.resolve("medium"), .sharp)
        XCTAssertEqual(HapticOption.resolve("light"), .soft)
        XCTAssertEqual(HapticOption.resolve("soft"), .soft)
        XCTAssertEqual(HapticOption.resolve("sharp"), .sharp)
        XCTAssertEqual(HapticOption.resolve("double"), .double)
        XCTAssertEqual(HapticOption.resolve("buzz"), .buzz)
        XCTAssertNil(HapticOption.resolve("nonsense"))
        XCTAssertNil(HapticOption.resolve(nil))
    }

    // The option enums expose the full choice sets the settings picker renders.
    func testOptionCasesCoverTheChoiceSets() {
        XCTAssertEqual(SoundOption.allCases, [.off, .tock, .pop, .click, .bloop, .ding])
        XCTAssertEqual(HapticOption.allCases, [.off, .soft, .sharp, .double, .buzz])
        XCTAssertEqual(SoundOption.ding.label, "DING")
        XCTAssertEqual(HapticOption.soft.label, "SOFT")
        XCTAssertEqual(HapticOption.sharp.label, "SHARP")
        XCTAssertEqual(HapticOption.double.label, "DOUBLE")
        XCTAssertEqual(HapticOption.buzz.label, "BUZZ")
    }
}
