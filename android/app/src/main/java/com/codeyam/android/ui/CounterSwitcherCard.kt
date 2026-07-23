package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.codeyam.android.model.Counter

/**
 * The switcher card: the row of selectable counter dots (including any blank
 * slots), the active counter's name and the swipe hint, and the settings gear
 * that toggles the per-counter settings panel. Ports iOS `CounterSwitcherCard`.
 */
@Composable
fun CounterSwitcherCard(
    counters: List<Counter>,
    activeId: Int,
    activeName: String,
    onSelect: (Int) -> Unit,
    onAdd: () -> Unit,
    onGearTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val sorted = counters.sortedBy { it.order }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 12.dp)
            .background(CounterColors.panel)
            .border(1.dp, CounterColors.lineStrong, RectangleShape)
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            // Horizontal scroll so a large number of counters stays one row and
            // swipes through, instead of overflowing the card width.
            Row(
                modifier = Modifier
                    .horizontalScroll(rememberScrollState())
                    // Breathing room so the active dot's ring isn't clipped by
                    // the scroll viewport edges.
                    .padding(vertical = 5.dp, horizontal = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                sorted.forEach { counter ->
                    val empty = counter.isBlank && counter.count == 0
                    CounterDot(
                        color = if (counter.isBlank) CounterColors.inkMuted else dotColor(counter.colorKey),
                        isActive = counter.id == activeId,
                        isBlank = counter.isBlank,
                        isEmpty = empty,
                        identifier = if (empty) "dot-empty-${counter.id}" else "dot-${counter.id}",
                        onTap = { onSelect(counter.id) },
                    )
                }
                // Trailing "+" dot: appends a new blank counter and selects it —
                // the tap equivalent of swiping past the end.
                AddCounterDot(onAdd = onAdd)
            }

            // A blank active slot has no name — show a muted em-dash placeholder
            // instead of an empty label.
            Text(
                text = activeName.ifEmpty { "—" },
                fontSize = 24.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = (-0.4).sp,
                color = if (activeName.isEmpty()) CounterColors.inkMuted else CounterColors.ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = "TAP A DOT OR SWIPE TO SWITCH",
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace,
                letterSpacing = 0.6.sp,
                color = CounterColors.inkMuted,
            )
        }
        GearButton(onClick = onGearTap)
    }
}
