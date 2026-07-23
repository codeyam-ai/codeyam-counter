package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * A floating panel anchored below the screen's fixed top chrome. The [anchor] is
 * an invisible, non-interactive copy of the header (and optionally the switcher)
 * that reserves exact-height space so the panel lands directly under it. Ports
 * iOS `HeaderAnchoredOverlay`, which existed for the same reason: `ContentView`
 * repeated this scaffold for each of its four overlays.
 *
 * The anchor is drawn at zero alpha rather than skipped, because the point is to
 * reserve its exact measured height — a hardcoded offset would drift the moment
 * the header or switcher card changed.
 */
@Composable
fun HeaderAnchoredOverlay(
    anchor: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .alpha(0f)
                // Zero-alpha content still takes touches, which would swallow
                // taps meant for the panel below it.
                .semantics { }
                .clickable(enabled = false, onClick = {}),
        ) {
            anchor()
        }
        content()
    }
}

/**
 * The shared card chrome every panel draws in: panel fill, hairline border, and
 * the same insets, with a pinned [title] row and DONE action above a body that
 * scrolls only once it outgrows the room available.
 *
 * The height cap lives on the SCROLL, not the card. Capping the card makes it
 * flexible — it fills the whole proposal up to the max rather than hugging,
 * which is what left the iOS panels reserving a screenful of empty space.
 * Bounding the scroll instead lets the card hug `header + scroll`.
 */
@Composable
fun SettingsPanelCard(
    title: String,
    doneIdentifier: String,
    onDone: () -> Unit,
    availableHeight: Dp,
    modifier: Modifier = Modifier,
    body: @Composable () -> Unit,
) {
    // Subtracts the top inset (12), the card's vertical padding (2 x 20), the
    // pinned header row and its spacing (~58), and a bottom breathing margin (24).
    val maxScrollHeight = maxOf(120.dp, availableHeight - 12.dp - 40.dp - 58.dp - 24.dp)

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
        PanelHeader(title = title, doneIdentifier = doneIdentifier, onDone = onDone)
        Column(
            modifier = Modifier
                .heightIn(max = maxScrollHeight)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            body()
        }
    }
}

/** The pinned title + DONE row shared by all three panels. */
@Composable
fun PanelHeader(
    title: String,
    doneIdentifier: String,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interaction = remember { MutableInteractionSource() }
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = title,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            letterSpacing = 1.4.sp,
            color = CounterColors.inkMuted,
        )
        Text(
            text = "DONE",
            fontSize = 12.sp,
            fontWeight = FontWeight.Black,
            fontFamily = FontFamily.Monospace,
            letterSpacing = 1.sp,
            color = CounterColors.onAccent,
            modifier = Modifier
                .background(CounterColors.accent)
                .clickable(interactionSource = interaction, indication = null, onClick = onDone)
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .semantics { contentDescription = doneIdentifier },
        )
    }
}
