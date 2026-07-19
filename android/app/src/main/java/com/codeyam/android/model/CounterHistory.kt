package com.codeyam.android.model

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put

/**
 * A single recorded change within a [CounterHistory] — one increment or subtract
 * on the counter. The no-op subtract clamp (already at floor with negatives
 * disallowed) records no event, mirroring how it fires no feedback. Ported from
 * iOS `CounterEvent`.
 *
 * Time is epoch milliseconds ([Long]) — the Kotlin analog of Swift's `Date`. Its
 * offset from the parent history's [CounterHistory.startedAt] is the relative time
 * shown in the graph and the event list.
 */
data class CounterEvent(
    /** When the change happened, as epoch milliseconds. */
    val at: Long,
    /**
     * The signed change applied: `+step` on increment, the actual (negative)
     * applied amount on subtract (`-step`, or the clamped delta at the floor).
     */
    val delta: Int,
) {
    fun toJson(): JsonObject = buildJsonObject {
        put("at", at)
        put("delta", delta)
    }

    companion object {
        fun fromJson(obj: JsonObject): CounterEvent = CounterEvent(
            at = obj["at"]?.jsonPrimitive?.long ?: 0L,
            delta = obj["delta"]?.jsonPrimitive?.int ?: 0,
        )
    }
}

/**
 * One point on the running-count series: the seconds elapsed since the history's
 * [CounterHistory.startedAt] and the running count at that moment. A plain data
 * class so the chart and the tests can share and compare it. Ported from iOS
 * `CumulativePoint`.
 */
data class CumulativePoint(
    /** Seconds since the history's start (Swift `TimeInterval`). */
    val time: Double,
    val count: Int,
)

/**
 * One run of activity for a counter — the span between resets. A history begins
 * fresh (empty) and is sealed when the counter is reset; reset then opens a new
 * empty history. Because time is always measured from [startedAt], "relative to
 * the start" is unambiguous. Persisted separately from the counters blob under the
 * `counterHistories` key, capped at the 10 most recent per counter. Ported from
 * iOS `CounterHistory`.
 */
data class CounterHistory(
    /**
     * When this run began — the reset that opened it (or the counter's first event,
     * for a lazily-created first history), as epoch milliseconds. The zero point of
     * the graph.
     */
    val startedAt: Long,
    /** The changes recorded during this run, oldest first. */
    val events: MutableList<CounterEvent> = mutableListOf(),
) {
    /**
     * The running count over this run as `(relativeTimeSeconds, runningCount)`
     * points, starting from `(0.0, 0)` at [startedAt] and stepping at each event.
     * Pure so the chart and unit tests share one source of truth.
     */
    fun cumulativeSeries(): List<CumulativePoint> {
        var running = 0
        val series = mutableListOf(CumulativePoint(time = 0.0, count = 0))
        for (event in events) {
            running += event.delta
            series.add(CumulativePoint(time = secondsBetween(startedAt, event.at), count = running))
        }
        return series
    }

    /** Seconds elapsed from this history's start to the given event. */
    fun relativeOffset(event: CounterEvent): Double = secondsBetween(startedAt, event.at)

    /**
     * The net count after all events — the counter's value when this history was
     * sealed (or its current value, for the active history).
     */
    val runningTotal: Int
        get() = events.sumOf { it.delta }

    fun toJson(): JsonObject = buildJsonObject {
        put("startedAt", startedAt)
        put("events", buildJsonArray { events.forEach { add(it.toJson()) } })
    }

    companion object {
        /** Seconds (as a Double) between two epoch-millis instants. */
        private fun secondsBetween(from: Long, to: Long): Double = (to - from) / 1000.0

        fun fromJson(obj: JsonObject): CounterHistory = CounterHistory(
            startedAt = obj["startedAt"]?.jsonPrimitive?.long ?: 0L,
            events = (obj["events"]?.jsonArray ?: emptyList())
                .map { CounterEvent.fromJson(it.jsonObject) }
                .toMutableList(),
        )
    }
}
