package com.codeyam.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
/**
 * The widest the counter column is ever laid out, regardless of screen size.
 *
 * This is a phone-first, one-handed app: the hero numeral is left-aligned at a
 * fixed `sp` size, the increment target is the lower half of the column, and the
 * bottom bar is sized for thumb reach. Stretched to a tablet's ~960dp width all
 * of that breaks down — the numeral strands itself against the left edge with
 * half the screen empty beside it, and the bottom controls sprawl far past any
 * thumb. Capping the column and centring it keeps the designed proportions on a
 * large screen instead of scaling them into something the design never intended.
 *
 * Above the cap the app renders as a centred column on the app background; at or
 * below it (every phone) the cap is inert and layout is byte-identical.
 */
internal val MaxContentWidth = 480.dp

/**
 * The window insets the content must stay clear of.
 *
 * System bars + display cutout, deliberately NOT `safeDrawing`: that also
 * includes the IME, which would re-derive the entire layout geometry every time
 * the rename keyboard opens.
 *
 * A composable default rather than a hardcoded one so a test can substitute
 * fixed insets — under Robolectric there is no real window, so the platform
 * values are all zero and the edge-to-edge behaviour would be untestable.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun defaultContentInsets(): WindowInsets =
    WindowInsets.systemBars.union(WindowInsets.displayCutout)

@Composable
fun CounterScreen(
    state: CounterScreenState,
    modifier: Modifier = Modifier,
    contentInsets: WindowInsets = defaultContentInsets(),
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(CounterColors.bg),
        contentAlignment = Alignment.TopCenter,
    ) {
    BoxWithConstraints(
        modifier = Modifier
            .widthIn(max = MaxContentWidth)
            .fillMaxSize()
            // Edge-to-edge is unconditional at target 36 (the opt-out is
            // ignored), so the window now extends under the status and
            // navigation bars. The padding is applied HERE, outside the
            // constraints read below, so `maxHeight`/`maxWidth` keep describing
            // USABLE space. Inset the content inside `BoxWithConstraints`
            // instead and every derived measurement — hero sizing, the
            // lower-half increment target, the bottom bar — would still be
            // computed against full-window height while the content sits
            // visually inset: correct on the device you tested, wrong on one
            // with a taller nav bar. The parent `Box` keeps the background
            // un-inset so the app colour still runs bar to bar.
            .windowInsetsPadding(contentInsets)
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
                // The whole flexible hero region is a secondary increment
                // target: tapping anywhere in the numeral's space bumps the
                // count, exactly like the + bar below. No press dim by design,
                // so the shared IncrementFaceButtonStyle state is untouched.
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .pointerInput(Unit) { detectTapGestures { state.increment() } }
                        .semantics { contentDescription = "count-hero-increment" },
                    contentAlignment = Alignment.Center,
                ) {
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
                // Read the revision-keyed getters HERE, inside the overlay's
                // content lambda (its own restartable scope), so a settings write
                // recomposes just this panel — not the whole screen on every count
                // change, which reading them in the outer scope would cause.
                AppSettingsPanel(
                    leftHanded = state.defaultLeftHanded,
                    soundOption = state.soundOption,
                    incrementHapticOption = state.incrementHapticOption,
                    decrementHapticOption = state.decrementHapticOption,
                    onLeftHandedChange = { state.setDefaultLeftHanded(it) },
                    onSoundChange = { state.setSoundOption(it) },
                    onIncrementHapticChange = { state.setIncrementHapticOption(it) },
                    onDecrementHapticChange = { state.setDecrementHapticOption(it) },
                    availableHeight = screenHeight,
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
}
