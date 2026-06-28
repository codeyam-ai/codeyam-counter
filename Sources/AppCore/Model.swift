import Foundation

/// A single named tally the user increments, subtracts, and resets.
public struct Counter: Identifiable, Codable, Equatable {
    public var id: Int
    public var name: String
    public var count: Int
    /// One of "lime", "coffee", "steps", "bugs" — drives the switcher dot color.
    public var colorKey: String
    /// When false, `subtract` clamps at zero. Defaults to true (subtract may go
    /// negative) per the product decision; the settings panel toggles it.
    public var allowNegative: Bool
    /// How much each increment/subtract changes the count (the "count by"
    /// amount). Always at least 1; legacy persisted counters written before this
    /// field existed decode as 1.
    public var step: Int
    public var order: Int

    public init(id: Int, name: String, count: Int, colorKey: String, allowNegative: Bool = true, step: Int = 1, order: Int) {
        self.id = id
        self.name = name
        self.count = count
        self.colorKey = colorKey
        self.allowNegative = allowNegative
        self.step = max(1, step)
        self.order = order
    }

    // Custom decoding so counters persisted before `step` (and the original
    // pre-`allowNegative` seeds) still decode, falling back to the same defaults
    // as `init`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        count = try c.decode(Int.self, forKey: .count)
        colorKey = try c.decode(String.self, forKey: .colorKey)
        allowNegative = try c.decodeIfPresent(Bool.self, forKey: .allowNegative) ?? true
        step = max(1, try c.decodeIfPresent(Int.self, forKey: .step) ?? 1)
        order = try c.decode(Int.self, forKey: .order)
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
    /// Ids of default starter counters the user has explicitly deleted. Each
    /// renders as an empty "ghost" circle in the switcher; tapping it restores
    /// the default. Tracked explicitly (not inferred from absence) so a scenario
    /// that seeds a subset of counters does not sprout ghost dots.
    @Published public private(set) var deletedDefaultIds: Set<Int>

    private let defaults: UserDefaults

    public static let countersKey = "counters"
    public static let selectedKey = "selectedCounterId"
    public static let deletedDefaultsKey = "deletedDefaultIds"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let loaded = Self.loadCounters(from: defaults)
        let counters = loaded.isEmpty ? Self.defaultCounters() : loaded
        self.counters = counters
        self.deletedDefaultIds = Self.loadDeletedDefaultIds(from: defaults)

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
    /// Counts only live counters — ghost slots are not "real" counters here.
    public var positionLabel: String {
        String(format: "%02d / %02d", selectedIndex + 1, counters.count)
    }

    /// The deleted-default templates (fresh at 0, in original order) used by the
    /// switcher to draw empty restore circles where a default used to be.
    public var ghostSlots: [Counter] {
        Self.defaultCounters()
            .filter { deletedDefaultIds.contains($0.id) }
            .sorted { $0.order < $1.order }
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
        counters[selectedIndex].count += counters[selectedIndex].step
        persistCounters()
    }

    public func subtract() {
        let current = counters[selectedIndex]
        if current.allowNegative {
            counters[selectedIndex].count -= current.step
        } else {
            // Already at/below zero: no change. Otherwise step down, but never
            // overshoot past zero — clamp to 0 rather than skip the change.
            if current.count <= 0 { return }
            counters[selectedIndex].count = max(0, current.count - current.step)
        }
        persistCounters()
    }

    public func reset() {
        counters[selectedIndex].count = 0
        persistCounters()
    }

    // MARK: - Editing, deleting, restoring

    /// Applies the settings panel's edits to the active counter and persists.
    public func updateActiveCounter(name: String, colorKey: String, allowNegative: Bool, step: Int) {
        guard counters.indices.contains(selectedIndex) else { return }
        counters[selectedIndex].name = name
        counters[selectedIndex].colorKey = colorKey
        counters[selectedIndex].allowNegative = allowNegative
        counters[selectedIndex].step = max(1, step)
        persistCounters()
    }

    /// Removes a counter, fixing the selection so it stays in range (selecting a
    /// neighbor when the active counter is deleted). Deleting a default records
    /// its id so a ghost restore slot appears in its place.
    public func deleteCounter(id: Int) {
        guard let idx = counters.firstIndex(where: { $0.id == id }) else { return }
        counters.remove(at: idx)
        if Self.defaultIds.contains(id) {
            deletedDefaultIds.insert(id)
            persistDeletedDefaultIds()
        }
        if idx < selectedIndex { selectedIndex -= 1 }
        selectedIndex = counters.isEmpty ? 0 : min(selectedIndex, counters.count - 1)
        persistCounters()
        if !counters.isEmpty { persistSelection() }
    }

    /// Re-creates a deleted default from its template (fresh at 0, original
    /// name/color/order), clears its ghost slot, and selects it.
    public func restoreDefault(id: Int) {
        guard deletedDefaultIds.contains(id),
              let template = Self.defaultCounters().first(where: { $0.id == id }) else { return }
        deletedDefaultIds.remove(id)
        persistDeletedDefaultIds()
        counters.append(template)
        counters.sort { $0.order < $1.order }
        persistCounters()
        if let idx = counters.firstIndex(where: { $0.id == id }) {
            selectedIndex = idx
            persistSelection()
        }
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

    private func persistDeletedDefaultIds() {
        if let data = try? JSONEncoder().encode(deletedDefaultIds.sorted()),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: Self.deletedDefaultsKey)
        }
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

    // Stored as a JSON-encoded `[Int]` string (same convention as `counters`) so
    // it survives the editor's `defaults write` string injection.
    private static func loadDeletedDefaultIds(from defaults: UserDefaults) -> Set<Int> {
        guard let json = defaults.string(forKey: deletedDefaultsKey),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    /// Ids of the default starter counters — the only ones that leave a
    /// restorable ghost slot when deleted.
    private static var defaultIds: Set<Int> { Set(defaultCounters().map(\.id)) }

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
