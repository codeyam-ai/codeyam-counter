package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp

/**
 * The counter screen: header, switcher card, the count hero and the bottom
 * control assembly, plus the swipe-to-switch gesture. Ports iOS `ContentView`.
 *
 * While the graph is open the hero and the whole bottom assembly are gone, so
 * everything around the chart is blank and the increment / subtract / reset
 * controls are neither visible nor reachable. The hero must go too, not just the
 * bar — the graph overlay is transparent, so a numeral left behind would show
 * through the gap between the chart panel and the CLOSE button.
 */
@Composable
fun CounterScreen(state: CounterScreenState, modifier: Modifier = Modifier) {
    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .background(CounterColors.bg)
            .pointerInput(Unit) {
                // Same ±40pt threshold as the iOS DragGesture, so a deliberate
                // swipe switches counters but a stray drag while tapping the
                // hero does not. `PointerInputScope` is itself a `Density`, so
                // the dp threshold converts against the real screen here.
                val threshold = 40.dp.toPx()
                var dragTotal = 0f
                detectHorizontalDragGestures(
                    onDragStart = { dragTotal = 0f },
                    onDragEnd = {
                        if (dragTotal < -threshold) state.selectNext()
                        else if (dragTotal > threshold) state.selectPrevious()
                    },
                    onHorizontalDrag = { _, amount -> dragTotal += amount },
                )
            },
        contentAlignment = Alignment.TopStart,
    ) {
        val screenHeight = maxHeight
        val screenWidth = maxWidth

        // The two pieces of top chrome, hoisted so the floating panels below can
        // re-render them at zero alpha as exact-height anchors.
        val header: @Composable () -> Unit = {
            HeaderBar(onSettingsTap = { state.toggleAppSettings() })
        }
        val switcher: @Composable () -> Unit = {
            CounterSwitcherCard(
                counters = state.counters,
                activeId = state.activeCounter.id,
                activeName = state.activeCounter.name,
                onSelect = { state.select(it) },
                onAdd = { state.addCounter() },
                onGearTap = { state.toggleCounterSettings() },
            )
        }

        // Base layer: the full screen always laid out normally.
        Column(modifier = Modifier.fillMaxSize()) {
            header()
            switcher()

            if (state.showGraph) {
                Spacer(modifier = Modifier.weight(1f))
            } else {
                Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    CountHero(count = state.activeCounter.count)
                }
                CounterBottomBar(
                    leftHanded = state.leftHanded,
                    screenHeight = screenHeight,
                    screenWidth = screenWidth,
                    resetIsUndo = state.canUndoReset,
                    graphOpen = state.showGraph,
                    onIncrement = { state.increment() },
                    onSubtract = { state.subtract() },
                    onReset = { state.resetOrUndo() },
                    onGraph = { state.toggleGraph() },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        // Floating per-counter settings panel: anchored directly under the
        // switcher (an invisible header + card reserve the exact height), drawn
        // on top so it overlays the count and the increment bar.
        if (state.showSettings) {
            HeaderAnchoredOverlay(anchor = { header(); switcher() }) {
                CounterSettingsPanel(
                    counter = state.activeCounter,
                    availableHeight = screenHeight,
                    onSave = { name, colorKey, allowNegative, step, handed, sound, incHaptic, decHaptic ->
                        state.updateActiveCounter(
                            name = name,
                            colorKey = colorKey,
                            allowNegative = allowNegative,
                            step = step,
                            handednessOverride = handed,
                            soundOverride = sound,
                            incrementHapticOverride = incHaptic,
                            decrementHapticOverride = decHaptic,
                        )
                    },
                    onDelete = { state.deleteActiveCounter() },
                    onClose = { state.closeSettings() },
                )
            }
        }

        // Floating App Settings panel: anchored under the header alone.
        //
        // Suppressed while the counter list is up. iOS relies on the list card
        // being drawn last and happening to be exactly as tall as this one, so it
        // covers it — a coincidence of content heights, not a guarantee. Making
        // the occlusion explicit is the same visual result without depending on
        // two independent panels staying the same size. `showAppSettings` stays
        // true, so closing the list still returns here.
        if (state.showAppSettings && !state.showCounterList) {
            HeaderAnchoredOverlay(anchor = { header() }) {
                AppSettingsPanel(
                    settings = state.settings,
                    availableHeight = screenHeight,
                    onChanged = { state.settingsChanged() },
                    onOpenList = { state.openCounterList() },
                    onClose = { state.closeAppSettings() },
                )
            }
        }

        // All-counters list: also anchored under the header, drawn last so it
        // sits above the App Settings panel that opened it.
        if (state.showCounterList) {
            HeaderAnchoredOverlay(anchor = { header() }) {
                CounterListPanel(
                    counters = state.counters,
                    activeId = state.activeCounter.id,
                    onSelect = { state.selectFromList(it) },
                    onClose = { state.closeCounterList() },
                )
            }
        }

        // Activity graph: anchored under the header, drawn on top of the screen.
        if (state.showGraph) {
            HeaderAnchoredOverlay(anchor = { header() }) {
                GraphPage(
                    counterName = if (state.activeCounter.isBlank) "—" else state.activeCounter.name,
                    colorKey = state.activeCounter.colorKey,
                    histories = state.activeHistories,
                    onClose = { state.closeGraph() },
                )
            }
        }
    }
}
