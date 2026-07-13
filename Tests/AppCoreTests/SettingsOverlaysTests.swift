import XCTest
@testable import AppCore

// XCTest, not swift-testing — see ModelTests for the rationale.
//
// The "only one settings panel open at a time" rule. These pin the exclusivity
// that the two tap sites in ContentView delegate here.
final class SettingsOverlaysTests: XCTestCase {
    // Nothing is open out of the box.
    func testNothingIsOpenByDefault() {
        let overlays = SettingsOverlays()
        XCTAssertFalse(overlays.counterSettings)
        XCTAssertFalse(overlays.appSettings)
    }

    // Opening App Settings from a clean screen just opens it.
    func testOpeningAppSettingsFromClosedOpensIt() {
        let next = SettingsOverlays().togglingAppSettings()
        XCTAssertEqual(next, SettingsOverlays(counterSettings: false, appSettings: true))
    }

    // Opening the per-counter panel from a clean screen just opens it.
    func testOpeningCounterSettingsFromClosedOpensIt() {
        let next = SettingsOverlays().togglingCounterSettings()
        XCTAssertEqual(next, SettingsOverlays(counterSettings: true, appSettings: false))
    }

    // The core rule: opening App Settings while the per-counter panel is up
    // force-closes the per-counter panel, so the two are never both on screen.
    func testOpeningAppSettingsClosesTheCounterPanel() {
        let next = SettingsOverlays(counterSettings: true, appSettings: false)
            .togglingAppSettings()
        XCTAssertEqual(next, SettingsOverlays(counterSettings: false, appSettings: true))
    }

    // The same rule in the other direction.
    func testOpeningCounterSettingsClosesAppSettings() {
        let next = SettingsOverlays(counterSettings: false, appSettings: true)
            .togglingCounterSettings()
        XCTAssertEqual(next, SettingsOverlays(counterSettings: true, appSettings: false))
    }

    // Toggling an already-open panel closes it — and does NOT open the other one.
    func testTogglingOpenAppSettingsClosesItAndOpensNothing() {
        let next = SettingsOverlays(counterSettings: false, appSettings: true)
            .togglingAppSettings()
        XCTAssertEqual(next, SettingsOverlays(counterSettings: false, appSettings: false))
    }

    // The closing direction for the per-counter panel.
    func testTogglingOpenCounterSettingsClosesItAndOpensNothing() {
        let next = SettingsOverlays(counterSettings: true, appSettings: false)
            .togglingCounterSettings()
        XCTAssertEqual(next, SettingsOverlays(counterSettings: false, appSettings: false))
    }

    // Whatever the starting state, neither toggle can ever leave both panels open.
    func testNoToggleEverLeavesBothOpen() {
        for counter in [true, false] {
            for app in [true, false] {
                let start = SettingsOverlays(counterSettings: counter, appSettings: app)
                for next in [start.togglingAppSettings(), start.togglingCounterSettings()] {
                    XCTAssertFalse(next.counterSettings && next.appSettings,
                                   "both open after toggling from \(start)")
                }
            }
        }
    }
}
