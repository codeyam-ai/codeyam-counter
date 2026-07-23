package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.codeyam.android.model.Counter
import com.codeyam.android.model.CounterTheme
import com.codeyam.android.model.HapticOption
import com.codeyam.android.model.SoundOption

/**
 * Inline per-counter settings panel that expands over the count numeral.
 * Composes the labeled name field, color picker, step stepper, allow-negative
 * toggle, the collapsible feedback overrides, and a destructive Delete. Local
 * state holds the in-progress edits; DONE saves. Ports iOS
 * `CounterSettingsPanel`.
 */
@Composable
fun CounterSettingsPanel(
    counter: Counter,
    availableHeight: Dp,
    onSave: (String, String, Boolean, Int, Boolean?, SoundOption?, HapticOption?, HapticOption?) -> Unit,
    onDelete: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Keyed on the counter id so switching counters re-seeds every field rather
    // than carrying the previous counter's in-progress edits across.
    var name by remember(counter.id) { mutableStateOf(counter.name) }
    // A blank slot has no color yet — default the picker to the first palette
    // swatch so saving with a name produces a normal colored counter. The name
    // stays empty, so saving without one leaves the slot blank.
    var colorKey by remember(counter.id) {
        mutableStateOf(
            if (counter.isBlank) CounterTheme.palette.firstOrNull() ?: "lime" else counter.colorKey,
        )
    }
    var allowNegative by remember(counter.id) { mutableStateOf(counter.allowNegative) }
    var step by remember(counter.id) { mutableStateOf(counter.step) }
    var handednessOverride by remember(counter.id) { mutableStateOf(counter.handednessOverride) }
    var soundOverride by remember(counter.id) { mutableStateOf(counter.soundOverride) }
    var incrementHapticOverride by remember(counter.id) { mutableStateOf(counter.incrementHapticOverride) }
    var decrementHapticOverride by remember(counter.id) { mutableStateOf(counter.decrementHapticOverride) }
    // Seeded open when the counter already pins any override, so a user who set
    // them sees them right away; collapsed otherwise so the resting panel is short.
    var showFeedback by remember(counter.id) { mutableStateOf(counter.hasFeedbackOverride) }
    var confirmingDelete by remember(counter.id) { mutableStateOf(false) }

    SettingsPanelCard(
        title = "SETTINGS",
        doneIdentifier = "settings-close",
        onDone = {
            onSave(
                name, colorKey, allowNegative, step,
                handednessOverride, soundOverride,
                incrementHapticOverride, decrementHapticOverride,
            )
            onClose()
        },
        availableHeight = availableHeight,
        modifier = modifier,
    ) {
        SettingsField("NAME") {
            BasicTextField(
                value = name,
                onValueChange = { name = it },
                singleLine = true,
                textStyle = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Black, color = CounterColors.ink),
                cursorBrush = SolidColor(CounterColors.accent),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(CounterColors.surface)
                    .border(1.dp, CounterColors.line, RectangleShape)
                    .padding(vertical = 8.dp, horizontal = 10.dp)
                    .semantics { contentDescription = "settings-name" },
            )
        }

        SettingsField("COLOR") {
            CounterColorPicker(selection = colorKey, onSelect = { colorKey = it })
        }

        CounterStepStepper(step = step, onStepChange = { step = it })

        SettingsToggleRow(
            label = "ALLOW NEGATIVE",
            checked = allowNegative,
            onCheckedChange = { allowNegative = it },
            identifier = "settings-allow-negative",
        )

        FeedbackDisclosureToggle(
            expanded = showFeedback,
            onToggle = { showFeedback = !showFeedback },
            title = "FEEDBACK & HANDEDNESS",
            identifier = "settings-feedback-toggle",
            caption = "Override application-wide settings",
        )

        if (showFeedback) {
            SettingsField("HANDEDNESS") {
                OverridePicker(
                    options = listOf(true, false),
                    selection = handednessOverride,
                    onSelect = { handednessOverride = it },
                    idPrefix = "settings-handedness",
                    optionLabel = { if (it) "LEFT" else "RIGHT" },
                )
            }
            SettingsField("SOUND") {
                OverridePicker(
                    options = SoundOption.entries,
                    selection = soundOverride,
                    onSelect = { soundOverride = it },
                    idPrefix = "settings-sound",
                    optionLabel = { it.label },
                )
            }
            SettingsField("INCREMENT HAPTIC") {
                OverridePicker(
                    options = HapticOption.entries,
                    selection = incrementHapticOverride,
                    onSelect = { incrementHapticOverride = it },
                    idPrefix = "settings-increment-haptic",
                    optionLabel = { it.label },
                )
            }
            SettingsField("DECREMENT HAPTIC") {
                OverridePicker(
                    options = HapticOption.entries,
                    selection = decrementHapticOverride,
                    onSelect = { decrementHapticOverride = it },
                    idPrefix = "settings-decrement-haptic",
                    optionLabel = { it.label },
                )
            }
        }

        DeleteCounterButton(
            confirming = confirmingDelete,
            onConfirmingChange = { confirmingDelete = it },
            onDelete = {
                onDelete()
                onClose()
            },
        )
    }
}
