package com.codeyam.android.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * A small secondary control in the bottom row (SUBTRACT / RESET / GRAPH): an
 * icon above a mono label. The icon is a text [glyph] by default, or a vector
 * [icon] when supplied (GRAPH's chart mark). Ports iOS `ControlButton`.
 *
 * Declared as a `RowScope` extension because every call site is a quarter-width
 * slot in the bottom row; taking `weight(1f)` here keeps the equal-quarter rule
 * in one place instead of at each of the three call sites.
 */
@Composable
fun androidx.compose.foundation.layout.RowScope.ControlButton(
    label: String,
    identifier: String,
    onClick: () -> Unit,
    glyph: String = "",
    icon: ImageVector? = null,
) {
    val interaction = remember { MutableInteractionSource() }
    Column(
        modifier = Modifier
            .weight(1f)
            .fillMaxHeight()
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics { contentDescription = identifier },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = CounterColors.ink,
                modifier = Modifier.size(18.dp),
            )
        } else {
            Text(
                text = glyph,
                fontSize = 18.sp,
                fontWeight = FontWeight.Black,
                color = CounterColors.ink,
            )
        }
        Text(
            text = label,
            fontSize = 9.sp,
            fontFamily = FontFamily.Monospace,
            letterSpacing = 0.4.sp,
            maxLines = 1,
            color = CounterColors.ink,
            modifier = Modifier.padding(top = 3.dp),
        )
    }
}
