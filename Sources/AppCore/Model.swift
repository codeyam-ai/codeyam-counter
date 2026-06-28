import Foundation

/// A single named tally the user increments, subtracts, and resets.
public struct Counter: Identifiable, Codable, Equatable {
    public var id: Int
    public var name: String
    public var count: Int
    /// One of "lime", "coffee", "steps", "bugs" — drives the switcher dot color.
    public var colorKey: String
    /// When false, `subtract` clamps at zero. Defaults to true (subtract may go
    /// negative) per the product decision; a future settings screen will toggle it.
    public var allowNegative: Bool
    public var order: Int

    public init(id: Int, name: String, count: Int, colorKey: String, allowNegative: Bool = true, order: Int) {
        self.id = id
        self.name = name
        self.count = count
        self.colorKey = colorKey
        self.allowNegative = allowNegative
        self.order = order
    }
}

/// Observable store backing the counter screen.
///
/// Seeding contract: at launch the editor injects a scenario's
/// `deviceState.preferences` into `UserDefaults` *before* the app starts. This
/// model reads those same keys in `init`, so each scenario observes its seeded
/// state from the first frame:
///   - `counters` — a JSON-encoded `[Counter]` string
///   - `selectedCounterId` — the id of the active counter
/// Production ships with neither key set, so first launch creates the default
/// starter set (four counters at 0).
public final class CounterModel: ObservableObject {
    @Published public private(set) var counters: [Counter]
    @Published public private(set) var selectedIndex: Int

    private let defaults: UserDefaults

    public static let countersKey = "counters"
    public static let selectedKey = "selectedCounterId"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let loaded = Self.loadCounters(from: defaults)
        let counters = loaded.isEmpty ? Self.defaultCounters() : loaded
        self.counters = counters

        // A seeded preference can arrive as a string (the editor injects
        // `deviceState.preferences` via `defaults write`), so coerce with
        // `integer(forKey:)` rather than an `as? Int` cast that a string would
        // silently fail. The key's presence is checked first because
        // `integer(forKey:)` returns 0 (no counter id) when absent.
        if defaults.object(forKey: Self.selectedKey) != nil,
           let idx = counters.firstIndex(where: { $0.id == defaults.integer(forKey: Self.selectedKey) }) {
            self.selectedIndex = idx
        } else {
            self.selectedIndex = 0
        }
    }

    // MARK: - Derived state

    public var activeCounter: Counter {
        counters[selectedIndex]
    }

    public var counterCount: Int { counters.count }

    /// 1-based position of the active counter, for the "01 / 04 COUNTERS" header.
    public var positionLabel: String {
        String(format: "%02d / %02d", selectedIndex + 1, counters.count)
    }

    // MARK: - Selection

    public func select(index: Int) {
        guard counters.indices.contains(index) else { return }
        selectedIndex = index
        persistSelection()
    }

    public func select(id: Int) {
        guard let idx = counters.firstIndex(where: { $0.id == id }) else { return }
        select(index: idx)
    }

    /// Advances to the next counter, wrapping around. Used by the swipe gesture.
    public func selectNext() {
        guard !counters.isEmpty else { return }
        select(index: (selectedIndex + 1) % counters.count)
    }

    /// Moves to the previous counter, wrapping around. Used by the swipe gesture.
    public func selectPrevious() {
        guard !counters.isEmpty else { return }
        select(index: (selectedIndex - 1 + counters.count) % counters.count)
    }

    // MARK: - Mutations (act on the active counter)

    public func increment() {
        counters[selectedIndex].count += 1
        persistCounters()
    }

    public func subtract() {
        let current = counters[selectedIndex]
        if !current.allowNegative && current.count <= 0 {
            return
        }
        counters[selectedIndex].count -= 1
        persistCounters()
    }

    public func reset() {
        counters[selectedIndex].count = 0
        persistCounters()
    }

    // MARK: - Persistence

    private func persistCounters() {
        if let data = try? JSONEncoder().encode(counters),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: Self.countersKey)
        }
    }

    private func persistSelection() {
        defaults.set(activeCounter.id, forKey: Self.selectedKey)
    }

    private static func loadCounters(from defaults: UserDefaults) -> [Counter] {
        guard let json = defaults.string(forKey: countersKey),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Counter].self, from: data),
              !decoded.isEmpty else {
            return []
        }
        return decoded.sorted { $0.order < $1.order }
    }

    /// The starter set every fresh install begins with — four counters at zero.
    public static func defaultCounters() -> [Counter] {
        [
            Counter(id: 1, name: "PUSH-UPS", count: 0, colorKey: "lime", order: 0),
            Counter(id: 2, name: "COFFEE", count: 0, colorKey: "coffee", order: 1),
            Counter(id: 3, name: "STEPS", count: 0, colorKey: "steps", order: 2),
            Counter(id: 4, name: "BUGS", count: 0, colorKey: "bugs", order: 3),
        ]
    }
}
