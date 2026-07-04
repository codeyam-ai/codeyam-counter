import Foundation

/// A single recorded change within a `CounterHistory` — one increment or
/// subtract on the counter. The no-op subtract clamp (already at floor with
/// negatives disallowed) records no event, mirroring how it fires no feedback.
public struct CounterEvent: Codable, Equatable {
    /// When the change happened. Its offset from the parent history's
    /// `startedAt` is the relative time shown in the graph and the event list.
    public let at: Date
    /// The signed change applied: `+step` on increment, the actual (negative)
    /// applied amount on subtract (`-step`, or the clamped delta at the floor).
    public let delta: Int

    public init(at: Date, delta: Int) {
        self.at = at
        self.delta = delta
    }
}

/// One point on the running-count series: the seconds elapsed since the
/// history's `startedAt` and the running count at that moment. A plain struct
/// (rather than a tuple) so the chart and the tests can share and compare it.
public struct CumulativePoint: Equatable {
    public let time: TimeInterval
    public let count: Int

    public init(time: TimeInterval, count: Int) {
        self.time = time
        self.count = count
    }
}

/// One run of activity for a counter — the span between resets. A history
/// begins fresh (empty) and is sealed when the counter is reset; reset then
/// opens a new empty history. Because time is always measured from `startedAt`,
/// "relative to the start" is unambiguous. Persisted separately from the
/// counters blob under the `counterHistories` key, capped at the 10 most recent
/// per counter.
public struct CounterHistory: Codable, Equatable {
    /// When this run began — the reset that opened it (or the counter's first
    /// event, for a lazily-created first history). The zero point of the graph.
    public let startedAt: Date
    /// The changes recorded during this run, oldest first.
    public var events: [CounterEvent]

    public init(startedAt: Date, events: [CounterEvent] = []) {
        self.startedAt = startedAt
        self.events = events
    }

    /// The running count over this run as `(relativeTime, runningCount)` points,
    /// starting from `(0, 0)` at `startedAt` and stepping at each event. Pure so
    /// the chart and unit tests share one source of truth.
    public func cumulativeSeries() -> [CumulativePoint] {
        var running = 0
        var series = [CumulativePoint(time: 0, count: 0)]
        for event in events {
            running += event.delta
            series.append(CumulativePoint(time: event.at.timeIntervalSince(startedAt), count: running))
        }
        return series
    }

    /// Seconds elapsed from this history's start to the given event.
    public func relativeOffset(of event: CounterEvent) -> TimeInterval {
        event.at.timeIntervalSince(startedAt)
    }

    /// The net count after all events — the counter's value when this history
    /// was sealed (or its current value, for the active history).
    public var runningTotal: Int {
        events.reduce(0) { $0 + $1.delta }
    }
}
