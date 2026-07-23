package com.codeyam.android.ui

import java.text.NumberFormat

/**
 * A count rendered with locale digit grouping — `8421` reads as `8,421`.
 *
 * This is not decoration; it is what iOS already does. SwiftUI's `Text("\(n)")`
 * resolves to the `LocalizedStringKey` initializer, which formats an interpolated
 * `Int` through the current locale and therefore groups thousands. Kotlin string
 * templates do not, so a straight `"$count"` port would silently drop the
 * separator and the two platforms would disagree on every four-digit value.
 *
 * Used everywhere a raw count reaches the screen — the hero, the all-counters
 * list, the graph's axis labels and event deltas.
 */
fun formatCount(value: Int): String = NumberFormat.getIntegerInstance().format(value)

/** A signed delta for the event list: `+3` / `-2`, grouped the same way. */
fun formatDelta(value: Int): String =
    if (value >= 0) "+${formatCount(value)}" else formatCount(value)
