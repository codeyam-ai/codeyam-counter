package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.codeyam.android.model.CounterEvent
import com.codeyam.android.model.CounterHistory

/**
 * The graph surface as a whole page: the activity chart stacked above its own
 * centered CLOSE button. While this is up, [CounterScreen] hides the count hero
 * and the entire bottom control assembly, so these two are the only things on
 * screen below the header — and the close button is the only way back.
 * Ports iOS `GraphPage`.
 */
@Composable
fun GraphPage(
    counterName: String,
    colorKey: String,
    histories: List<CounterHistory>,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        CounterGraphView(counterName = counterName, colorKey = colorKey, histories = histories)
        GraphCloseButton(onClose = onClose)
    }
}

/**
 * A counter's activity: a step-line chart of the running count over relative
 * time plus a list of each event, with a selector to page between the stored
 * histories (runs between resets). Ports iOS `CounterGraphView`.
 */
@Composable
fun CounterGraphView(
    counterName: String,
    colorKey: String,
    histories: List<CounterHistory>,
    modifier: Modifier = Modifier,
) {
    // Defaults to the current (last) run, and is re-seeded when the counter
    // changes so the graph always opens on the new counter's current run.
    var index by remember(counterName, histories.size) {
        mutableIntStateOf(maxOf(0, histories.size - 1))
    }
    val accent = if (colorKey.isEmpty()) CounterColors.accent else dotColor(colorKey)
    val selected = histories.getOrNull(index) ?: histories.lastOrNull()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 12.dp)
            .background(CounterColors.panel)
            .border(1.dp, CounterColors.lineStrong, RectangleShape)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        GraphHeader(counterName = counterName)

        if (histories.size > 1) {
            GraphHistorySelector(
                index = index,
                count = histories.size,
                onIndexChange = { index = it },
            )
        }

        if (selected != null && selected.events.isNotEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .background(CounterColors.surface)
                    .border(1.dp, CounterColors.line, RectangleShape)
                    .semantics { contentDescription = "graph-chart" },
            ) {
                CounterGraphChart(history = selected, accent = accent)
            }
        } else {
            Text(
                text = "NO ACTIVITY YET",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                letterSpacing = 1.sp,
                color = CounterColors.inkMuted,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .background(CounterColors.surface)
                    .border(1.dp, CounterColors.line, RectangleShape)
                    .padding(top = 72.dp)
                    .semantics { contentDescription = "graph-empty" },
            )
        }

        if (selected != null && selected.events.isNotEmpty()) {
            GraphEventList(history = selected, accent = accent)
        }
    }
}

/** The graph's header: the small GRAPH caption above the active counter's name. */
@Composable
fun GraphHeader(counterName: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = "GRAPH",
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            letterSpacing = 1.4.sp,
            color = CounterColors.inkMuted,
        )
        Text(
            text = counterName,
            fontSize = 18.sp,
            fontWeight = FontWeight.Black,
            color = CounterColors.ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * Prev/next paging across a counter's stored runs, with the recency label
 * ("CURRENT", "−1", "−2", …) between the arrows. Ports iOS
 * `GraphHistorySelector`.
 */
@Composable
fun GraphHistorySelector(
    index: Int,
    count: Int,
    onIndexChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    // How recent the shown run is: CURRENT for the newest, then −1, −2, … back
    // through the stored runs.
    val offset = count - 1 - index
    val recency = if (offset <= 0) "CURRENT" else "−$offset"

    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        PageButton("‹", "graph-history-prev", enabled = index > 0) {
            onIndexChange(maxOf(0, index - 1))
        }
        Text(
            text = recency,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            letterSpacing = 1.sp,
            color = CounterColors.ink,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .weight(1f)
                .semantics { contentDescription = "graph-history-label" },
        )
        PageButton("›", "graph-history-next", enabled = index < count - 1) {
            onIndexChange(minOf(count - 1, index + 1))
        }
    }
}

@Composable
private fun PageButton(glyph: String, identifier: String, enabled: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .size(width = 44.dp, height = 32.dp)
            .background(CounterColors.surface)
            .border(1.dp, CounterColors.line, RectangleShape)
            .clickable(
                interactionSource = interaction,
                indication = null,
                enabled = enabled,
                onClick = onClick,
            )
            .semantics { contentDescription = identifier },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = glyph,
            fontSize = 20.sp,
            fontWeight = FontWeight.Black,
            color = if (enabled) CounterColors.ink else CounterColors.line,
        )
    }
}

/**
 * The most-recent-first list of a run's events: each row a signed delta and the
 * relative time since the run began. Ports iOS `GraphEventList`.
 */
@Composable
fun GraphEventList(history: CounterHistory, accent: Color, modifier: Modifier = Modifier) {
    if (history.events.isEmpty()) return

    SettingsField("EVENTS", modifier = modifier) {
        Column(
            modifier = Modifier
                .heightIn(max = 180.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            history.events.withIndex().reversed().forEach { (i, event) ->
                EventRow(index = i, event = event, history = history, accent = accent)
            }
        }
    }
}

@Composable
private fun EventRow(index: Int, event: CounterEvent, history: CounterHistory, accent: Color) {
    val up = event.delta >= 0
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp, horizontal = 4.dp)
                .semantics { contentDescription = "graph-event-row-$index" },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = formatDelta(event.delta),
                fontSize = 15.sp,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.Monospace,
                color = if (up) accent else dotColor("coffee"),
            )
            Text(
                text = GraphGeometry.relativeTime(history.relativeOffset(event)),
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
                color = CounterColors.inkMuted,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(CounterColors.line),
        )
    }
}

/**
 * The graph page's dismissal control: a centered CLOSE pill directly below the
 * chart panel. The graph hides the whole bottom bar while it is open, so this is
 * the only way out. Ports iOS `GraphCloseButton`.
 */
@Composable
fun GraphCloseButton(onClose: () -> Unit, modifier: Modifier = Modifier) {
    val interaction = remember { MutableInteractionSource() }
    Row(
        modifier = modifier
            .fillMaxWidth()
            // Matches CounterGraphView's own horizontal inset so the pill aligns
            // flush under the chart panel above it.
            .padding(horizontal = 22.dp)
            .background(CounterColors.panel)
            .border(1.dp, CounterColors.lineStrong, RectangleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClose)
            .padding(vertical = 14.dp)
            .semantics { contentDescription = "graph-close" },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "✕",
            fontSize = 12.sp,
            fontWeight = FontWeight.Black,
            color = CounterColors.ink,
        )
        Text(
            text = "CLOSE",
            fontSize = 12.sp,
            fontFamily = FontFamily.Monospace,
            letterSpacing = 1.2.sp,
            color = CounterColors.ink,
            modifier = Modifier.padding(start = 8.dp),
        )
    }
}
