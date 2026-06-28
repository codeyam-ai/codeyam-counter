import SwiftUI

/// Design tokens lifted from the CodeYam Counter mockup
/// (.codeyam/design/user_files/CodeYam-Counter-marquee.html).
public enum CounterTheme {
    public static let bg = Color(hex: "0C0D08")
    public static let surface = Color(hex: "15170F")
    public static let panel = Color(hex: "10110B")
    public static let ink = Color(hex: "EAE8E0")
    public static let inkMuted = Color(hex: "8D8F80")
    public static let line = Color(hex: "2A2C20")
    public static let lineStrong = Color(hex: "43463A")
    public static let accent = Color(hex: "D5F560")
    public static let onAccent = Color(hex: "0B0A08")

    /// Maps a counter's `colorKey` to its dot/accent color.
    public static func dotColor(_ key: String) -> Color {
        Color(hex: dotHex(key))
    }

    /// Pure mapping from a counter `colorKey` to its hex string. Unknown keys
    /// fall back to the lime accent. Kept separate from `dotColor` so it can be
    /// unit-tested without rendering a `Color`.
    public static func dotHex(_ key: String) -> String {
        switch key {
        case "lime": return "D5F560"
        case "coffee": return "FF7A4D"
        case "steps": return "4DB5FF"
        case "bugs": return "C98BFF"
        default: return "D5F560"
        }
    }

    /// Pure hex → RGB parse backing `Color(hex:)`. Accepts an optional leading
    /// "#" and is case-insensitive; returns each channel in the 0...1 range.
    public static func rgbComponents(hex: String) -> (red: Double, green: Double, blue: Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        return (r, g, b)
    }
}

extension Color {
    /// Hex string like "D5F560" or "#D5F560" → Color.
    init(hex: String) {
        let c = CounterTheme.rgbComponents(hex: hex)
        self.init(red: c.red, green: c.green, blue: c.blue)
    }
}
