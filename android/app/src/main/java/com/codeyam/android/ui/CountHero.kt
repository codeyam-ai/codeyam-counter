package com.codeyam.android.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text

/**
 * The giant numeral showing the active counter's current value — the Compose
 * equivalent of iOS `CountHero`.
 *
 * The iOS view leans on `minimumScaleFactor(0.2)` to shrink an over-long numeral;
 * Compose has no direct equivalent, so [autoSizedFontSize] reproduces the same
 * behavior by stepping the size down as the digit count grows. Without it a value
 * like 8421 would clip rather than shrink.
 */
@Composable
fun CountHero(count: Int, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(
            text = formatCount(count),
            style = TextStyle(
                fontSize = autoSizedFontSize(formatCount(count)),
                fontWeight = FontWeight.Black,
                letterSpacing = (-6).sp,
            ),
            color = CounterColors.ink,
            maxLines = 1,
            overflow = TextOverflow.Clip,
            modifier = Modifier
                .fillMaxWidth()
                .semantics { contentDescription = "count-value" },
        )
    }
}

/**
 * The hero size for an already-formatted numeral: 280sp for one or two digits
 * (matching iOS's base `.system(size: 280)`), stepping down for longer numerals
 * so a grouped four- or five-digit count still fits the screen width instead of
 * clipping. Measured on the FORMATTED string, so the grouping separators and a
 * leading minus count toward the width — which is what the iOS scale factor
 * effectively does too.
 */
internal fun autoSizedFontSize(formatted: String) = when (formatted.length) {
    1, 2 -> 280.sp
    3 -> 220.sp
    4 -> 170.sp
    5 -> 140.sp
    else -> 110.sp
}
