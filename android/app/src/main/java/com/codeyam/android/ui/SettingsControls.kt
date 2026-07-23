package com.codeyam.android.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
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
import com.codeyam.android.model.CounterTheme

/**
 * A labeled section in a settings panel: a small mono caption above its content.
 * Keeps the name field, color picker and option rows visually consistent.
 * Ports iOS `SettingsField`.
 */
@Composable
fun SettingsField(
    title: String,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        FieldCaption(title)
        content()
    }
}

/** The shared small-caps mono caption used by every settings heading. */
@Composable
fun FieldCaption(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        fontSize = 10.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = FontFamily.Monospace,
        letterSpacing = 0.8.sp,
        color = CounterColors.inkMuted,
        modifier = modifier,
    )
}

/**
 * A labeled on/off row: a mono label on the left, the switch pinned right.
 * Used for ALLOW NEGATIVE. Ports iOS `SettingsToggleRow`.
 */
@Composable
fun SettingsToggleRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    identifier: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = CounterColors.ink,
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = CounterColors.accent,
                checkedThumbColor = CounterColors.onAccent,
                uncheckedTrackColor = CounterColors.surface,
                uncheckedThumbColor = CounterColors.inkMuted,
                uncheckedBorderColor = CounterColors.line,
            ),
            modifier = Modifier
                .padding(end = 4.dp)
                .semantics { contentDescription = identifier },
        )
    }
}

/**
 * The collapsible disclosure header for a panel's feedback rows, plus an
 * optional caption describing what the section does. The chevron rotates from
 * pointing right (collapsed) to down (expanded); the whole row is tappable.
 * The caption stays visible in both states so the section's purpose is legible
 * before it is opened. Ports iOS `FeedbackDisclosureToggle`.
 */
@Composable
fun FeedbackDisclosureToggle(
    expanded: Boolean,
    onToggle: () -> Unit,
    title: String,
    identifier: String,
    modifier: Modifier = Modifier,
    caption: String? = null,
) {
    val rotation by animateFloatAsState(
        targetValue = if (expanded) 90f else 0f,
        animationSpec = tween(durationMillis = 200),
        label = "disclosure-chevron",
    )
    val interaction = remember { MutableInteractionSource() }

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(interactionSource = interaction, indication = null, onClick = onToggle)
                .padding(vertical = 8.dp)
                .semantics { contentDescription = identifier },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            FieldCaption(title)
            Text(
                text = "›",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = CounterColors.inkMuted,
                modifier = Modifier.rotate(rotation),
            )
        }
        if (caption != null) {
            Text(
                text = caption,
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace,
                color = CounterColors.inkMuted,
                modifier = Modifier.semantics { contentDescription = "$identifier-caption" },
            )
        }
    }
}

/**
 * The "COUNT BY" control: a −/value/+ stepper setting how much each increment or
 * subtract changes the count. Clamps the lower bound at 1. Ports iOS
 * `CounterStepStepper`.
 */
@Composable
fun CounterStepStepper(step: Int, onStepChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        FieldCaption("COUNT BY")
        Row(modifier = Modifier.border(1.dp, CounterColors.line, RectangleShape)) {
            StepperButton("−", "settings-step-decr") { onStepChange(maxOf(1, step - 1)) }
            Text(
                text = "$step",
                fontSize = 17.sp,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.Monospace,
                color = CounterColors.ink,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .width(48.dp)
                    .semantics { contentDescription = "settings-step" },
            )
            StepperButton("+", "settings-step-incr") { onStepChange(step + 1) }
        }
    }
}

@Composable
private fun StepperButton(glyph: String, identifier: String, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .size(42.dp)
            .background(CounterColors.surface)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics { contentDescription = identifier },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = glyph,
            fontSize = 20.sp,
            fontWeight = FontWeight.Black,
            color = CounterColors.ink,
        )
    }
}

/**
 * A grid of selectable color swatches drawn from the shared palette; the
 * selected key gets a lime ring. Ports iOS `CounterColorPicker`.
 *
 * Laid out as fixed rows of six rather than a `LazyVGrid` because the palette is
 * a small, fixed list — lazy layout inside an already-scrolling panel would nest
 * two scroll containers on the same axis.
 */
@Composable
fun CounterColorPicker(selection: String, onSelect: (String) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        CounterTheme.palette.chunked(6).forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                row.forEach { key ->
                    val selected = key == selection
                    val interaction = remember(key) { MutableInteractionSource() }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clickable(
                                interactionSource = interaction,
                                indication = null,
                                onClick = { onSelect(key) },
                            )
                            .semantics { contentDescription = "settings-color-$key" },
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(if (selected) 36.dp else 28.dp)
                                .then(
                                    if (selected) {
                                        Modifier.border(2.dp, CounterColors.accent, CircleShape)
                                    } else {
                                        Modifier
                                    },
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(28.dp)
                                    .clip(CircleShape)
                                    .background(dotColor(key)),
                            )
                        }
                    }
                }
                // Pad a short final row so its swatches keep the same column
                // width as the full rows above rather than spreading out.
                repeat(6 - row.size) { Box(modifier = Modifier.weight(1f)) }
            }
        }
    }
}

/**
 * A "default-or-value" chooser for the per-counter panel: a leading `DEFAULT`
 * chip (meaning "follow the app-wide setting", i.e. `null`) followed by one chip
 * per concrete option. The selected chip is filled with the accent so a static
 * capture shows the current choice without a live tap. Ports iOS
 * `OverridePicker`.
 */
@Composable
fun <T> OverridePicker(
    options: List<T>,
    selection: T?,
    onSelect: (T?) -> Unit,
    idPrefix: String,
    optionLabel: (T) -> String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(vertical = 1.dp)
            .semantics { contentDescription = idPrefix },
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Chip(
            text = "DEFAULT",
            selected = selection == null,
            identifier = "$idPrefix-default",
            onClick = { onSelect(null) },
        )
        options.forEach { option ->
            val label = optionLabel(option)
            Chip(
                text = label,
                selected = selection == option,
                identifier = "$idPrefix-${label.lowercase()}",
                onClick = { onSelect(option) },
            )
        }
    }
}

/**
 * A horizontally-scrolling row of selectable pills — one per option — with the
 * active one filled in the accent color. The App Settings variant of
 * [OverridePicker]: there is no "follow the default" choice because these rows
 * *are* the defaults.
 */
@Composable
fun <T> OptionPicker(
    options: List<T>,
    selected: T,
    onSelect: (T) -> Unit,
    idPrefix: String,
    optionLabel: (T) -> String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(vertical = 2.dp)
            .semantics { contentDescription = idPrefix },
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        options.forEach { option ->
            val label = optionLabel(option)
            Chip(
                text = label,
                selected = option == selected,
                identifier = "$idPrefix-${label.lowercase()}",
                onClick = { onSelect(option) },
                horizontalPadding = 14.dp,
                verticalPadding = 9.dp,
                fontSize = 12,
            )
        }
    }
}

@Composable
private fun Chip(
    text: String,
    selected: Boolean,
    identifier: String,
    onClick: () -> Unit,
    horizontalPadding: androidx.compose.ui.unit.Dp = 12.dp,
    verticalPadding: androidx.compose.ui.unit.Dp = 8.dp,
    fontSize: Int = 11,
) {
    val interaction = remember { MutableInteractionSource() }
    Text(
        text = text,
        fontSize = fontSize.sp,
        fontWeight = FontWeight.Black,
        fontFamily = FontFamily.Monospace,
        letterSpacing = 0.5.sp,
        color = if (selected) CounterColors.onAccent else CounterColors.ink,
        maxLines = 1,
        overflow = TextOverflow.Clip,
        modifier = Modifier
            .background(if (selected) CounterColors.accent else CounterColors.surface)
            .border(1.dp, if (selected) CounterColors.accent else CounterColors.line, RectangleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = horizontalPadding, vertical = verticalPadding)
            .semantics { contentDescription = identifier },
    )
}

/**
 * The destructive delete control, guarded by a two-tap confirm. Disarmed it is an
 * outlined coffee-colored "DELETE COUNTER"; the first tap arms it into a filled
 * "TAP AGAIN TO CONFIRM", so an accidental single tap never wipes a counter.
 * The `settings-delete` identifier stays on the control in both states, so arming
 * is a label/style swap rather than a new control. Ports iOS
 * `DeleteCounterButton`.
 *
 * [confirming] seeds the armed state so a scenario can capture it without a live
 * tap; the app always starts disarmed.
 */
@Composable
fun DeleteCounterButton(
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    confirming: Boolean = false,
    onConfirmingChange: (Boolean) -> Unit = {},
) {
    val coffee = dotColor("coffee")
    val interaction = remember { MutableInteractionSource() }

    Text(
        text = if (confirming) "TAP AGAIN TO CONFIRM" else "DELETE COUNTER",
        fontSize = 13.sp,
        fontWeight = FontWeight.Black,
        fontFamily = FontFamily.Monospace,
        letterSpacing = 1.sp,
        color = if (confirming) CounterColors.onAccent else coffee,
        textAlign = TextAlign.Center,
        modifier = modifier
            .fillMaxWidth()
            .background(if (confirming) coffee else Color.Transparent)
            .border(1.dp, coffee.copy(alpha = if (confirming) 1f else 0.6f), RectangleShape)
            .clickable(interactionSource = interaction, indication = null) {
                if (confirming) onDelete() else onConfirmingChange(true)
            }
            .padding(vertical = 12.dp)
            .semantics { contentDescription = "settings-delete" },
    )
}
