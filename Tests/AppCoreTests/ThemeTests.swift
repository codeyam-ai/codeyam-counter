import XCTest
import SwiftUI
@testable import AppCore

// XCTest, not swift-testing — see README "## Testing" for the rationale.
final class ThemeTests: XCTestCase {

    // MARK: - rgbComponents

    private func assertRGB(_ hex: String,
                           _ expected: (Double, Double, Double),
                           file: StaticString = #filePath, line: UInt = #line) {
        let c = CounterTheme.rgbComponents(hex: hex)
        XCTAssertEqual(c.red, expected.0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(c.green, expected.1, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(c.blue, expected.2, accuracy: 0.001, file: file, line: line)
    }

    // Pure black and white sit at the ends of the 0...1 range.
    func testParsesBlackAndWhite() {
        assertRGB("000000", (0, 0, 0))
        assertRGB("FFFFFF", (1, 1, 1))
    }

    // The lime accent decomposes into its three channels.
    func testParsesAccentLime() {
        assertRGB("D5F560", (213.0 / 255, 245.0 / 255, 96.0 / 255))
    }

    // A leading "#" is tolerated and parses identically.
    func testToleratesLeadingHash() {
        assertRGB("#4DB5FF", (77.0 / 255, 181.0 / 255, 255.0 / 255))
    }

    // Parsing is case-insensitive: lower- and upper-case hex agree.
    func testIsCaseInsensitive() {
        let lower = CounterTheme.rgbComponents(hex: "ff7a4d")
        let upper = CounterTheme.rgbComponents(hex: "FF7A4D")
        XCTAssertEqual(lower.red, upper.red, accuracy: 0.0001)
        XCTAssertEqual(lower.green, upper.green, accuracy: 0.0001)
        XCTAssertEqual(lower.blue, upper.blue, accuracy: 0.0001)
    }

    // Each isolated channel maps to the expected fraction of 255.
    func testIsolatesIndividualChannels() {
        assertRGB("FF0000", (1, 0, 0))
        assertRGB("00FF00", (0, 1, 0))
        assertRGB("0000FF", (0, 0, 1))
    }

    // MARK: - dotHex

    // Each known colorKey maps to its design-token hex.
    func testDotHexMapsKnownKeys() {
        XCTAssertEqual(CounterTheme.dotHex("lime"), "D5F560")
        XCTAssertEqual(CounterTheme.dotHex("coffee"), "FF7A4D")
        XCTAssertEqual(CounterTheme.dotHex("steps"), "4DB5FF")
        XCTAssertEqual(CounterTheme.dotHex("bugs"), "C98BFF")
    }

    // An unknown colorKey falls back to the lime accent rather than crashing.
    func testDotHexFallsBackToLimeForUnknownKey() {
        XCTAssertEqual(CounterTheme.dotHex("chartreuse"), "D5F560")
        XCTAssertEqual(CounterTheme.dotHex(""), "D5F560")
    }
}
