package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.codeyam.android.model.AppSettings
import com.codeyam.android.model.HapticOption
import com.codeyam.android.model.SoundOption

/**
 * The system-wide App Settings panel. Mirrors the per-counter panel's chrome
 * (anchored under the header, DONE to close) but holds no local edit state:
 * every control writes straight through to the persisted default, so there is no
 * save/cancel — toggling is immediate. Ports iOS `AppSettingsPanel`.
 *
 * [onChanged] exists because [AppSettings] is a plain persisted object with no
 * observable streams; the screen state bumps its revision through this so a
 * write is reflected on screen.
 */
@Composable
fun AppSettingsPanel(
    settings: AppSettings,
    availableHeight: Dp,
    onChanged: () -> Unit,
    onOpenList: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    SettingsPanelCard(
        title = "APP SETTINGS",
        doneIdentifier = "app-settings-close",
        onDone = onClose,
        availableHeight = availableHeight,
        modifier = modifier,
    ) {
        SettingsField("HANDEDNESS") {
            HandednessControl(
                leftHanded = settings.defaultLeftHanded,
                onSelect = { settings.defaultLeftHanded = it; onChanged() },
            )
        }

        // App Settings has no per-counter override state to justify a collapsed
        // resting state, so the sound/haptic rows are always visible rather than
        // hidden behind a disclosure.
        SettingsField("SOUND ON CHANGE") {
            OptionPicker(
                options = SoundOption.entries,
                selected = settings.soundOption,
                onSelect = { settings.soundOption = it; onChanged() },
                idPrefix = "app-settings-sound",
                optionLabel = { it.label },
            )
        }

        SettingsField("INCREMENT HAPTIC") {
            OptionPicker(
                options = HapticOption.entries,
                selected = settings.incrementHapticOption,
                onSelect = { settings.incrementHapticOption = it; onChanged() },
                idPrefix = "app-settings-increment-haptic",
                optionLabel = { it.label },
            )
        }

        SettingsField("DECREMENT HAPTIC") {
            OptionPicker(
                options = HapticOption.entries,
                selected = settings.decrementHapticOption,
                onSelect = { settings.decrementHapticOption = it; onChanged() },
                idPrefix = "app-settings-decrement-haptic",
                optionLabel = { it.label },
            )
        }

        AllCountersButton(onClick = onOpenList)
    }
}

/** A two-way segmented LEFT / RIGHT control writing `defaultLeftHanded`. */
@Composable
private fun HandednessControl(leftHanded: Boolean, onSelect: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, CounterColors.line, RectangleShape)
            .semantics { contentDescription = "app-settings-handedness" },
    ) {
        HandednessOption("LEFT", selected = leftHanded, onClick = { onSelect(true) })
        HandednessOption("RIGHT", selected = !leftHanded, onClick = { onSelect(false) })
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.HandednessOption(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    Text(
        text = label,
        fontSize = 12.sp,
        fontWeight = FontWeight.Black,
        fontFamily = FontFamily.Monospace,
        letterSpacing = 1.sp,
        color = if (selected) CounterColors.onAccent else CounterColors.ink,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .weight(1f)
            .background(if (selected) CounterColors.accent else Color.Transparent)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(vertical = 10.dp),
    )
}

/** The row that opens the all-counters list overlay. */
@Composable
private fun AllCountersButton(onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, CounterColors.lineStrong, RectangleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 12.dp)
            .semantics { contentDescription = "app-settings-list" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = "ALL COUNTERS",
            fontSize = 13.sp,
            fontWeight = FontWeight.Black,
            fontFamily = FontFamily.Monospace,
            letterSpacing = 1.sp,
            color = CounterColors.ink,
        )
        Text(
            text = "›",
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = CounterColors.inkMuted,
        )
    }
}
