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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.codeyam.android.model.Counter

/**
 * A scrollable list of every counter — colored dot, name, current count — opened
 * from the App Settings panel. Tapping a row selects that counter and dismisses
 * the list. Reuses the blank-slot em-dash / muted treatment from the switcher
 * card. Ports iOS `CounterListPanel`.
 */
@Composable
fun CounterListPanel(
    counters: List<Counter>,
    activeId: Int,
    onSelect: (Int) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val sorted = counters.sortedBy { it.order }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 12.dp)
            .background(CounterColors.panel)
            .border(1.dp, CounterColors.lineStrong, RectangleShape)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        PanelHeader(title = "ALL COUNTERS", doneIdentifier = "counter-list-close", onDone = onClose)

        // A FIXED height, not a max: iOS's `.frame(maxHeight: 320)` on a greedy
        // ScrollView always takes the full 320pt, so the card is tall enough to
        // fully cover the App Settings panel it was opened from. Hugging content
        // here instead would let that panel show through underneath.
        Column(
            modifier = Modifier
                .height(320.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            sorted.forEachIndexed { index, counter ->
                CounterListRow(counter = counter, isActive = counter.id == activeId) {
                    onSelect(counter.id)
                }
                if (index != sorted.lastIndex) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(CounterColors.line),
                    )
                }
            }
        }
    }
}

@Composable
private fun CounterListRow(counter: Counter, isActive: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val isBlank = counter.isBlank

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(vertical = 12.dp)
            // Leading inset so the active dot's ring isn't clipped by the scroll
            // viewport's edge.
            .padding(start = 6.dp)
            .semantics { contentDescription = "counter-list-row-${counter.id}" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(20.dp)
                .then(if (isActive) Modifier.border(2.dp, CounterColors.accent, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(if (isBlank) CounterColors.inkMuted else dotColor(counter.colorKey)),
            )
        }
        Text(
            text = if (isBlank) "—" else counter.name,
            fontSize = 16.sp,
            fontWeight = FontWeight.Black,
            color = if (isBlank) CounterColors.inkMuted else CounterColors.ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = formatCount(counter.count),
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = CounterColors.inkMuted,
        )
    }
}
