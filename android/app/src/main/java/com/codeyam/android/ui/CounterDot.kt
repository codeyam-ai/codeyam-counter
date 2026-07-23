package com.codeyam.android.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/**
 * A single counter-selector dot. The active dot grows slightly and gains a lime
 * ring. A blank slot (a deleted counter left in place) renders as a dashed
 * outline circle while empty, and as a solid neutral-fill dot once it has been
 * incremented; tapping either only selects it — no resurrection. Ports iOS
 * `CounterDot`.
 *
 * The active ring is drawn as a `border` on a box padded out around the dot,
 * standing in for iOS's negative-padding overlay; Compose has no negative
 * padding, so the ring is sized rather than inset.
 */
@Composable
fun CounterDot(
    color: Color,
    isActive: Boolean,
    identifier: String,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
    isBlank: Boolean = false,
    isEmpty: Boolean = false,
) {
    val dotSize = if (isActive) 18.dp else 16.dp
    // The ring sits 3dp outside the dot on each side, matching iOS's `padding(-3)`.
    val ringSize = dotSize + 6.dp
    val interaction = remember { MutableInteractionSource() }

    Box(
        modifier = modifier
            .size(ringSize)
            .then(
                if (isActive) Modifier.border(2.dp, CounterColors.accent, CircleShape)
                else Modifier,
            )
            .clickable(interactionSource = interaction, indication = null, onClick = onTap)
            .semantics { contentDescription = identifier },
        contentAlignment = Alignment.Center,
    ) {
        if (isBlank && isEmpty) {
            // Blank + count 0 → the dashed outline circle. Even with no name it
            // still gains the accent ring above, so the user can see which
            // unnamed slot is selected.
            Canvas(modifier = Modifier.size(dotSize)) {
                drawCircle(
                    color = CounterColors.lineStrong,
                    radius = size.minDimension / 2f - 1.5f.dp.toPx() / 2f,
                    style = Stroke(
                        width = 1.5.dp.toPx(),
                        pathEffect = PathEffect.dashPathEffect(
                            floatArrayOf(2.5.dp.toPx(), 2.5.dp.toPx()),
                        ),
                    ),
                )
            }
        } else {
            // Blank + count ≠ 0 → a solid neutral (nameless) dot; otherwise the
            // counter's own color.
            Box(
                modifier = Modifier
                    .size(dotSize)
                    .clip(CircleShape)
                    .border(
                        width = if (isActive) 0.dp else 1.dp,
                        color = if (isActive) Color.Transparent else Color.White.copy(alpha = 0.18f),
                        shape = CircleShape,
                    )
                    .background(if (isBlank) CounterColors.inkMuted else color),
            )
        }
    }
}

/**
 * A muted "+" circle at the end of the switcher's dot row. Tapping it adds a new
 * blank counter — the tap equivalent of swiping past the last counter. Ports iOS
 * `AddCounterDot`.
 */
@Composable
fun AddCounterDot(onAdd: () -> Unit, modifier: Modifier = Modifier) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .size(16.dp)
            .border(1.5.dp, CounterColors.lineStrong, CircleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onAdd)
            .semantics { contentDescription = "dot-add" },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Filled.Add,
            contentDescription = null,
            tint = CounterColors.inkMuted,
            modifier = Modifier.size(10.dp),
        )
    }
}
