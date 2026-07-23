package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Top app-chrome row: the brand name and the app-settings button that opens the
 * system-wide App Settings panel. Ports iOS `HeaderBar`.
 */
@Composable
fun HeaderBar(onSettingsTap: () -> Unit = {}, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = "CODEYAM COUNTER",
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = CounterColors.ink,
        )
        // Deliberately a sliders glyph, not a gear: this is the app-wide entry
        // point and must not read as the per-counter gear on the switcher card.
        CircleIconButton(
            icon = CounterIcons.Sliders,
            identifier = "app-settings",
            onClick = onSettingsTap,
        )
    }
}

/**
 * The settings gear on the switcher card, toggling the per-counter panel that
 * expands over the count. Ports iOS `GearButton`.
 */
@Composable
fun GearButton(onClick: () -> Unit = {}, modifier: Modifier = Modifier) {
    CircleIconButton(
        icon = Icons.Filled.Settings,
        identifier = "gear",
        onClick = onClick,
        modifier = modifier,
    )
}

/**
 * The shared circular-icon chrome button both entry points draw as: a 36dp
 * surface-filled circle with a hairline stroke. Factored out because iOS styles
 * `HeaderBar`'s button by explicitly "mirroring `GearButton`" — here that shared
 * styling is one composable rather than a comment.
 */
@Composable
private fun CircleIconButton(
    icon: ImageVector,
    identifier: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(CounterColors.surface)
            .border(1.dp, CounterColors.lineStrong, CircleShape)
            .clickable(onClick = onClick)
            .semantics { contentDescription = identifier },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = CounterColors.ink,
            modifier = Modifier.size(18.dp),
        )
    }
}
