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

    /// Per-counter override of the app-wide handedness default. `nil` follows
    /// `AppSettings.leftHanded`; `true` pins the mirrored left-handed layout while
    /// this counter is active, `false` pins right-handed.
    public var handednessOverride: Bool?
    /// Per-counter override of the app-wide sound-on-change default. `nil` follows
    /// `AppSettings.soundOption`; any value (including an explicit `.off`) pins
    /// that sound for this counter. Persisted as its `rawValue` string.
    public var soundOverride: SoundOption?
    /// Per-counter override of the app-wide increment haptic default. `nil`
    /// follows `AppSettings.incrementHapticOption`; any value (including an
    /// explicit `.off`) pins that haptic for increments on this counter. Persisted
    /// as its `rawValue` string.
    public var incrementHapticOverride: HapticOption?
    /// Per-counter override of the app-wide decrement haptic default. `nil`
    /// follows `AppSettings.decrementHapticOption`; any value (including an
    /// explicit `.off`) pins that haptic for subtracts on this counter. Persisted
    /// as its `rawValue` string.
    public var decrementHapticOverride: HapticOption?

    /// The sentinel `colorKey` a counter carries while blank — an empty string,
    /// which `CounterTheme.dotColor` never needs to resolve because a blank slot
    /// is drawn with the neutral muted fill instead of a palette color.
    public static let blankColorKey = ""

    /// True when this counter is a blank slot: a deleted counter left in place
    /// with an empty name, awaiting revival. Drives the dashed/solid-blank dot
    /// rendering and the "—" placeholder name. Giving it a name (via settings)
    /// clears blankness; incrementing does not.
    public var isBlank: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    public init(id: Int, name: String, count: Int, colorKey: String, allowNegative: Bool = true, step: Int = 1, order: Int,
                handednessOverride: Bool? = nil, soundOverride: SoundOption? = nil,
                incrementHapticOverride: HapticOption? = nil, decrementHapticOverride: HapticOption? = nil) {
        self.id = id
        self.name = name
        self.count = count
        self.colorKey = colorKey
        self.allowNegative = allowNegative
        self.step = max(1, step)
        self.order = order
        self.handednessOverride = handednessOverride
        self.soundOverride = soundOverride
        self.incrementHapticOverride = incrementHapticOverride
        self.decrementHapticOverride = decrementHapticOverride
    }

    /// Encoded/decoded keys — the current stored properties. Declared explicitly
    /// (rather than synthesized) so `init(from:)` and the synthesized `encode`
    /// agree once a legacy-only key (`LegacyCodingKeys.hapticOverride`) has to be
    /// read separately during migration.
    private enum CodingKeys: String, CodingKey {
        case id, name, count, colorKey, allowNegative, step, order
        case handednessOverride, soundOverride
        case incrementHapticOverride, decrementHapticOverride
    }

    /// The pre-split single haptic override key, read only as a migration
    /// fallback. Not a current stored property, so it lives in its own key set.
    private enum LegacyCodingKeys: String, CodingKey {
        case hapticOverride
    }

    // Custom decoding so counters persisted before `step` (and the original
    // pre-`allowNegative` seeds) still decode, falling back to the same defaults
    // as `init`. The override fields likewise decode as `nil` when absent, and the
    // enum overrides decode from their `rawValue` string, staying `nil` on any
    // unrecognized value so a stray seed never crashes the load. A counter written
    // before the haptic split carries a single `hapticOverride`; when the new
    // per-direction keys are absent it migrates into *both* directions.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        count = try c.decode(Int.self, forKey: .count)
        colorKey = try c.decode(String.self, forKey: .colorKey)
        allowNegative = try c.decodeIfPresent(Bool.self, forKey: .allowNegative) ?? true
        step = max(1, try c.decodeIfPresent(Int.self, forKey: .step) ?? 1)
        order = try c.decode(Int.self, forKey: .order)
        handednessOverride = try c.decodeIfPresent(Bool.self, forKey: .handednessOverride)
        soundOverride = (try c.decodeIfPresent(String.self, forKey: .soundOverride)).flatMap(SoundOption.init(rawValue:))

        // Route each override through `resolve(...)` so a persisted amplitude/`rigid`
        // rawValue migrates to its nearest surviving feel instead of decoding to nil
        // (which would silently drop the override and fall back to the app default).
        let increment = HapticOption.resolve(try c.decodeIfPresent(String.self, forKey: .incrementHapticOverride))
        let decrement = HapticOption.resolve(try c.decodeIfPresent(String.self, forKey: .decrementHapticOverride))
        // Migration: when neither new key decoded, adopt the legacy single override
        // for both directions (a stray/unrecognized legacy value stays nil).
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let legacy = HapticOption.resolve(try legacyContainer.decodeIfPresent(String.self, forKey: .hapticOverride))
        if increment == nil && decrement == nil, let legacy {
            incrementHapticOverride = legacy
            decrementHapticOverride = legacy
        } else {
            incrementHapticOverride = increment
            decrementHapticOverride = decrement
        }
    }

    // MARK: - Effective settings

    /// The handedness this counter actually renders with: its override when set,
    /// otherwise the supplied app-wide default.
    public func effectiveLeftHanded(default d: Bool) -> Bool { handednessOverride ?? d }

    /// The sound this counter actually emits on a change: its override when set
    /// (including an explicit `.off`), otherwise the supplied app-wide default.
    public func effectiveSound(default d: SoundOption) -> SoundOption { soundOverride ?? d }

    /// The haptic this counter actually fires on an increment: its override when
    /// set (including an explicit `.off`), otherwise the supplied app-wide default.
    public func effectiveIncrementHaptic(default d: HapticOption) -> HapticOption { incrementHapticOverride ?? d }

    /// The haptic this counter actually fires on a subtract: its override when set
    /// (including an explicit `.off`), otherwise the supplied app-wide default.
    public func effectiveDecrementHaptic(default d: HapticOption) -> HapticOption { decrementHapticOverride ?? d }

    /// Whether this counter pins ANY per-counter feedback/handedness override.
    /// Drives the settings panel's FEEDBACK & OVERRIDES section: a counter that
    /// already carries an override opens the section so the user sees it; one on
    /// pure defaults leaves it collapsed for a compact resting panel.
    public var hasFeedbackOverride: Bool {
        handednessOverride != nil
            || soundOverride != nil
            || incrementHapticOverride != nil
            || decrementHapticOverride != nil
    }
}

/// A pending undo for a single reset: the counter that was zeroed and the value
/// it held just before. Scoped to a counter id so the offer only applies while
/// that same counter is active.
public struct ResetUndo: Equatable {
    public let counterId: Int
    public let previousCount: Int

    public init(counterId: Int, previousCount: Int) {
        self.counterId = counterId
        self.previousCount = previousCount
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
///   - `resetUndoPreviousCount` — the pre-reset value of the active counter,
///     which seeds the bottom row into its UNDO RESET state for a static capture
///   - `counterHistories` — a JSON object string mapping a counter id (as a
///     string key) to its ordered `[CounterHistory]`, so a scenario can inject a
///     rich event history for a static graph capture (there is no live driver to
///     accumulate events). Dates are ISO-8601. Same string-injection contract as
///     `counters`.
/// A distribution build requires the app's own provenance marker
/// (`SeedPolicy.requireProvenance`) before adopting any of these keys: because
/// seeding reuses the real persistence keys, a Release build cannot simply
/// ignore them, so instead it trusts store state only once the app has stamped
/// its marker. Stray injected/stale scenario keys therefore land as an untrusted
/// container and the default starter set (four counters at 0, no history) is
/// used. Debug builds (what codeyam captures run) keep trusting injected state.
public final class CounterModel: ObservableObject {
    @Published public private(set) var counters: [Counter]
    @Published public private(set) var selectedIndex: Int
    /// A reset that can still be undone, or nil. Set the moment RESET is tapped
    /// (capturing the pre-reset value) and cleared as soon as the counter
    /// "starts again" — any count change, a selection switch, an edit, or a
    /// delete. Transient by design: never persisted on live mutations.
    @Published public private(set) var resetUndo: ResetUndo?

    /// Per-counter event history, keyed by counter id. Each value is the ordered
    /// list of that counter's runs (oldest first); the last is the *current*
    /// history that increments/subtracts append to. Capped at
    /// `maxHistoriesPerCounter` per counter (drop-oldest). Loaded at launch and
    /// persisted alongside the counters, but under a separate key so it can grow
    /// without bloating the counters blob.
    @Published public private(set) var histories: [Int: [CounterHistory]]

    /// The clock used to timestamp events and history starts. Injectable so tests
    /// can drive deterministic event times without waiting on the wall clock.
    public var now: () -> Date = Date.init

    private let defaults: UserDefaults

    /// Where count-change feedback is emitted. The default is silent; the app
    /// injects `SystemCounterFeedback`, tests inject a spy.
    private let feedback: CounterFeedback

    /// The effective feedback options to emit on the next change, evaluated fresh
    /// at each increment/subtract. Sound is shared across directions; the haptic
    /// is resolved per direction (increment vs decrement) so the model — not the
    /// feedback sink — picks which one fires. The view sets this from
    /// `AppSettings` and the active counter's overrides; keeping it a closure lets
    /// per-counter resolution re-evaluate without re-wiring. Defaults to all-off.
    public var effectiveFeedback: () -> (sound: SoundOption, incrementHaptic: HapticOption, decrementHaptic: HapticOption) = { (.off, .off, .off) }

    public static let countersKey = "counters"
    public static let selectedKey = "selectedCounterId"
    public static let deletedDefaultsKey = "deletedDefaultIds"
    public static let resetUndoKey = "resetUndoPreviousCount"
    public static let historiesKey = "counterHistories"

    /// The most recent runs kept per counter; the 11th reset drops the oldest.
    public static let maxHistoriesPerCounter = 10

    public init(defaults: UserDefaults = .standard, feedback: CounterFeedback = NoopCounterFeedback(),
                policy: SeedPolicy = .current) {
        self.defaults = defaults
        self.feedback = feedback

        // A distribution build only trusts store state carrying the app's own
        // provenance marker; codeyam seeding writes the data keys but never the
        // marker, so an untrusted container is treated as empty for every
        // injection key and the default starter set is used. Debug builds trust
        // injected state so codeyam captures keep seeding the app.
        let trusted = policy.trustsStore(in: defaults)

        let loaded = trusted ? Self.loadCounters(from: defaults) : []
        let counters = trusted
            ? Self.migrateDeletedDefaults(
                into: loaded.isEmpty ? Self.defaultCounters() : loaded,
                from: defaults)
            : Self.defaultCounters()
        self.counters = counters

        self.histories = trusted ? Self.loadHistories(from: defaults) : [:]

        // A seeded preference can arrive as a string (the editor injects
        // `deviceState.preferences` via `defaults write`), so coerce with
        // `integer(forKey:)` rather than an `as? Int` cast that a string would
        // silently fail. The key's presence is checked first because
        // `integer(forKey:)` returns 0 (no counter id) when absent. Skipped
        // entirely when the store is untrusted — the selection key is one of the
        // injected keys a distribution build ignores.
        let resolvedIndex: Int
        if trusted,
           defaults.object(forKey: Self.selectedKey) != nil,
           let idx = counters.firstIndex(where: { $0.id == defaults.integer(forKey: Self.selectedKey) }) {
            resolvedIndex = idx
        } else {
            resolvedIndex = 0
        }
        self.selectedIndex = resolvedIndex

        // Seed the pending-undo state when a scenario injects it, so a static
        // capture renders the UNDO RESET affordance without a live tap. Uses the
        // same presence-then-`integer(forKey:)` coercion as `selectedKey` so a
        // string-injected seed reads correctly.
        //
        // Require the active counter to be at 0: a real pending undo is always a
        // post-reset state (reset zeros the count), so a non-zero active count is
        // an impossible pairing. Rejecting it also keeps the key — which the
        // editor's `defaults write` seed leaves set across scenario loads — from
        // falsely activating UNDO RESET in unrelated scenarios whose counter is
        // not at 0.
        if trusted,
           defaults.object(forKey: Self.resetUndoKey) != nil,
           counters[resolvedIndex].count == 0 {
            self.resetUndo = ResetUndo(counterId: counters[resolvedIndex].id,
                                       previousCount: defaults.integer(forKey: Self.resetUndoKey))
        } else {
            self.resetUndo = nil
        }
    }

    /// True when the pending undo applies to the currently active counter — what
    /// the bottom row reads to render UNDO RESET in place of RESET.
    public var canUndoReset: Bool {
        resetUndo?.counterId == activeCounter.id
    }

    // MARK: - Derived state

    public var activeCounter: Counter {
        counters[selectedIndex]
    }

    /// The active counter's recorded runs, oldest first (empty when it has never
    /// been changed). What the graph view pages through.
    public var activeHistories: [CounterHistory] {
        histories[activeCounter.id] ?? []
    }

    public var counterCount: Int { counters.count }

    /// 1-based position of the active counter, for the "01 / 04 COUNTERS" header.
    /// A blank slot is still a slot, so the total counts blanks too — deleting a
    /// counter blanks it in place without shrinking the row.
    public var positionLabel: String {
        String(format: "%02d / %02d", selectedIndex + 1, counters.count)
    }

    // MARK: - Selection

    public func select(index: Int) {
        guard counters.indices.contains(index) else { return }
        // The captured pre-reset value belongs to the counter we're leaving, so
        // switching away expires the undo offer.
        resetUndo = nil
        selectedIndex = index
        persistSelection()
    }

    public func select(id: Int) {
        guard let idx = counters.firstIndex(where: { $0.id == id }) else { return }
        select(index: idx)
    }

    /// Advances to the next counter. Swiping *past the last* counter grows the
    /// list: instead of wrapping back to the first, it appends a fresh blank slot
    /// and selects it, so the user can keep swiping forward to add more counters.
    public func selectNext() {
        guard !counters.isEmpty else { return }
        if selectedIndex >= counters.count - 1 {
            addCounter()
        } else {
            select(index: selectedIndex + 1)
        }
    }

    /// Moves to the previous counter, wrapping around. Used by the swipe gesture.
    public func selectPrevious() {
        guard !counters.isEmpty else { return }
        select(index: (selectedIndex - 1 + counters.count) % counters.count)
    }

    /// Appends a fresh blank counter to the end of the list and selects it. Backs
    /// the "swipe past the last counter to add another" gesture. The new slot is a
    /// blank (unnamed "—", neutral color) — the user names it in settings or
    /// increments it to bring it to life, exactly like a revived deleted slot.
    public func addCounter() {
        resetUndo = nil
        let nextId = (counters.map(\.id).max() ?? 0) + 1
        let nextOrder = (counters.map(\.order).max() ?? -1) + 1
        counters.append(Counter(id: nextId, name: "", count: 0,
                                 colorKey: Counter.blankColorKey, order: nextOrder))
        selectedIndex = counters.count - 1
        persistCounters()
        persistSelection()
    }

    // MARK: - Mutations (act on the active counter)

    public func increment() {
        // The counter "starts again" — the recovery offer expires.
        resetUndo = nil
        let step = counters[selectedIndex].step
        counters[selectedIndex].count += step
        recordEvent(delta: step)
        persistCounters()
        emitChangeFeedback(.increment)
    }

    public func subtract() {
        let current = counters[selectedIndex]
        // Any subtract counts as the counter starting again, even the no-op
        // clamp case below — the user has moved on from the reset.
        resetUndo = nil
        let applied: Int
        if current.allowNegative {
            applied = -current.step
        } else {
            // Already at/below zero: no change — return before recording,
            // persisting, or firing feedback so the no-op clamp stays silent
            // (and logs no event). Otherwise step down, but never overshoot zero.
            if current.count <= 0 { return }
            applied = max(0, current.count - current.step) - current.count
        }
        counters[selectedIndex].count += applied
        recordEvent(delta: applied)
        persistCounters()
        emitChangeFeedback(.decrement)
    }

    /// Appends a change to the active counter's current history, lazily opening a
    /// first history when the counter has none yet (its run began at this event).
    /// The recorded delta is the *applied* change, so the running-count series
    /// reconstructs the count exactly.
    private func recordEvent(delta: Int) {
        let id = counters[selectedIndex].id
        var runs = histories[id] ?? []
        if runs.isEmpty {
            runs.append(CounterHistory(startedAt: now()))
        }
        runs[runs.count - 1].events.append(CounterEvent(at: now(), delta: delta))
        histories[id] = runs
        persistHistories()
    }

    /// The direction of a count change, selecting which resolved haptic fires.
    private enum ChangeDirection { case increment, decrement }

    /// Emit change feedback for the just-applied change using the currently
    /// resolved flags, picking the increment or decrement haptic per `direction`.
    /// `reset`/`undoReset` deliberately do not call this — only a live count
    /// change gives feedback.
    private func emitChangeFeedback(_ direction: ChangeDirection) {
        let flags = effectiveFeedback()
        let haptic = direction == .increment ? flags.incrementHaptic : flags.decrementHaptic
        feedback.changed(sound: flags.sound, haptic: haptic)
    }

    /// Zeros the active counter, remembering its prior value so the bottom row
    /// can offer an immediate UNDO RESET. The undo is captured even when the
    /// pre-reset value was 0 (a harmless no-op to undo), keeping the affordance
    /// consistent without a special case.
    public func reset() {
        let id = activeCounter.id
        resetUndo = ResetUndo(counterId: id, previousCount: counters[selectedIndex].count)
        counters[selectedIndex].count = 0
        // Seal the current run (it stays in the list) and open a fresh empty one,
        // so "relative to the start" is measured from this reset. Enforce the
        // per-counter cap by dropping the oldest run.
        var runs = histories[id] ?? []
        runs.append(CounterHistory(startedAt: now()))
        if runs.count > Self.maxHistoriesPerCounter {
            runs.removeFirst(runs.count - Self.maxHistoriesPerCounter)
        }
        histories[id] = runs
        persistCounters()
        persistHistories()
    }

    /// Restores the value captured by the most recent `reset()` on the active
    /// counter and clears the pending undo. Also reverses the history split that
    /// reset performed: it pops the empty run reset opened (guaranteed still
    /// empty, since any event would have cleared the undo window) so the sealed
    /// run becomes active again, keeping the count and the active history
    /// consistent. No-ops when there is nothing to undo.
    public func undoReset() {
        guard canUndoReset, let undo = resetUndo else { return }
        counters[selectedIndex].count = undo.previousCount
        let id = counters[selectedIndex].id
        if var runs = histories[id], let last = runs.last, last.events.isEmpty {
            runs.removeLast()
            histories[id] = runs
            persistHistories()
        }
        resetUndo = nil
        persistCounters()
    }

    // MARK: - Editing, deleting, restoring

    /// Applies the settings panel's edits to the active counter and persists.
    /// The overrides carry a `nil` to mean "follow the app default"; the panel
    /// passes them straight through so a counter can be pinned or reset to default
    /// in the same save. The two haptic overrides are independent so a counter can
    /// pin one direction while the other follows the app-wide pairing.
    public func updateActiveCounter(name: String, colorKey: String, allowNegative: Bool, step: Int,
                                    handednessOverride: Bool? = nil,
                                    soundOverride: SoundOption? = nil,
                                    incrementHapticOverride: HapticOption? = nil,
                                    decrementHapticOverride: HapticOption? = nil) {
        guard counters.indices.contains(selectedIndex) else { return }
        // Editing the counter invalidates the captured pre-reset value.
        resetUndo = nil
        counters[selectedIndex].name = name
        counters[selectedIndex].colorKey = colorKey
        counters[selectedIndex].allowNegative = allowNegative
        counters[selectedIndex].step = max(1, step)
        counters[selectedIndex].handednessOverride = handednessOverride
        counters[selectedIndex].soundOverride = soundOverride
        counters[selectedIndex].incrementHapticOverride = incrementHapticOverride
        counters[selectedIndex].decrementHapticOverride = decrementHapticOverride
        persistCounters()
    }

    /// Blanks a counter *in place* rather than removing it: empties its name,
    /// resets count to 0, and drops it to neutral color/step/allow-negative,
    /// keeping its `id` and `order`. The slot stays in `counters` (so the header
    /// total is unchanged) and stays selected, so the user can immediately revive
    /// it — by giving it a name in settings, or by incrementing it into a solid
    /// blank dot. Tapping the blank slot only selects it; it does not resurrect
    /// the old counter.
    public func deleteCounter(id: Int) {
        guard let idx = counters.firstIndex(where: { $0.id == id }) else { return }
        // The captured pre-reset value no longer applies once a counter is blanked.
        resetUndo = nil
        counters[idx].name = ""
        counters[idx].colorKey = Counter.blankColorKey
        counters[idx].count = 0
        counters[idx].step = 1
        counters[idx].allowNegative = true
        // A revived slot starts on the app defaults, so drop any pinned overrides.
        counters[idx].handednessOverride = nil
        counters[idx].soundOverride = nil
        counters[idx].incrementHapticOverride = nil
        counters[idx].decrementHapticOverride = nil
        // A blank slot starts clean — drop the old counter's recorded runs.
        histories[counters[idx].id] = nil
        selectedIndex = idx
        persistCounters()
        persistSelection()
        persistHistories()
    }

    // MARK: - Persistence

    private func persistCounters() {
        if let data = try? JSONEncoder().encode(counters),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: Self.countersKey)
        }
        // Stamp the app's provenance marker whenever it persists, so a real
        // user's own data is trusted on the next launch even under the
        // distribution policy. Every mutation path routes through here, so this
        // one call covers the whole store. Codeyam seeding never writes it.
        SeedPolicy.stampProvenance(in: defaults)
    }

    private func persistSelection() {
        defaults.set(activeCounter.id, forKey: Self.selectedKey)
    }

    // Histories persist as a JSON object string keyed by the counter id (as a
    // string), with ISO-8601 dates — the same string-injection contract as
    // `counters`, and a shape a scenario can hand-author: {"1": [{"startedAt":…}]}.
    private static func historyCoders() -> (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    private func persistHistories() {
        let (encoder, _) = Self.historyCoders()
        // Encode string-keyed so JSON produces an object, not the alternating
        // array Swift emits for `[Int: …]`.
        let keyed = Dictionary(uniqueKeysWithValues: histories.map { (String($0.key), $0.value) })
        if let data = try? encoder.encode(keyed),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: Self.historiesKey)
        }
    }

    private static func loadHistories(from defaults: UserDefaults) -> [Int: [CounterHistory]] {
        guard let json = defaults.string(forKey: historiesKey),
              let data = json.data(using: .utf8) else {
            return [:]
        }
        let (_, decoder) = historyCoders()
        guard let keyed = try? decoder.decode([String: [CounterHistory]].self, from: data) else {
            return [:]
        }
        // Drop any non-integer keys rather than crash the whole load.
        return Dictionary(uniqueKeysWithValues: keyed.compactMap { key, value in
            Int(key).map { ($0, value) }
        })
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
    //
    // `deletedDefaultIds` is now legacy/read-only: this model no longer writes it
    // (deleting blanks in place instead), but it is still read once at launch to
    // migrate users who deleted a default before this change shipped.
    private static func loadDeletedDefaultIds(from defaults: UserDefaults) -> Set<Int> {
        guard let json = defaults.string(forKey: deletedDefaultsKey),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    /// Legacy migration: for each id in the persisted `deletedDefaultIds` that is
    /// a known default and absent from the loaded counters, fold in a blank
    /// counter at that default's original order, then re-sort. This gives users
    /// (and older scenarios) who deleted a default under the old remove+ghost
    /// model a blank slot in the new blank-in-place model. Returns the loaded
    /// counters untouched when there is nothing to migrate.
    private static func migrateDeletedDefaults(into counters: [Counter], from defaults: UserDefaults) -> [Counter] {
        let deletedIds = loadDeletedDefaultIds(from: defaults)
        guard !deletedIds.isEmpty else { return counters }
        let present = Set(counters.map(\.id))
        var result = counters
        for template in defaultCounters() where deletedIds.contains(template.id) && !present.contains(template.id) {
            result.append(Counter(id: template.id, name: "", count: 0,
                                   colorKey: Counter.blankColorKey, order: template.order))
        }
        return result.sorted { $0.order < $1.order }
    }

    /// The starter set every fresh install begins with — four counters at zero.
    public static func defaultCounters() -> [Counter] {
        [
            Counter(id: 1, name: "COUNTER 1", count: 0, colorKey: "lime", order: 0),
            Counter(id: 2, name: "COUNTER 2", count: 0, colorKey: "coffee", order: 1),
            Counter(id: 3, name: "COUNTER 3", count: 0, colorKey: "steps", order: 2),
            Counter(id: 4, name: "COUNTER 4", count: 0, colorKey: "bugs", order: 3),
        ]
    }
}
