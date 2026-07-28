package com.codeyam.android.ui

import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import com.codeyam.android.model.AppSettings
import com.codeyam.android.model.CounterModel
import com.codeyam.android.model.InMemoryKeyValueStore
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * The regression guard for the App Settings stale-selection bug. Unlike the JVM
 * state tests (which assert on getters and never compose) and static scenario
 * captures (which seed state before the first composition, so they render
 * correctly even against the broken code), this taps a control on a live
 * composition and asserts the highlight *moved* — the exact re-composition that
 * failed before the fix.
 *
 * Runs under Robolectric so it executes on `testDebugUnitTest` with no emulator,
 * matching ci.yml's ubuntu android job.
 *
 * Lives in `src/testDebug/` rather than `src/test/` on purpose: `createComposeRule`
 * needs a host `ComponentActivity`, which reaches the merged application manifest
 * only via the `androidx.compose.ui.test.manifest` AAR — and that is
 * `debugImplementation`, since test scaffolding must never ship in a release
 * artifact. A variant-agnostic `src/test/` placement would make
 * `testReleaseUnitTest` run this against a variant where the host activity cannot
 * exist. The model/logic tests stay in `src/test/` and still cover both variants.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class AppSettingsPanelInteractionTest {

    @get:Rule
    val composeRule = createComposeRule()

    private fun openAppSettingsState(): CounterScreenState {
        val store = InMemoryKeyValueStore()
        return CounterScreenState(
            model = CounterModel(store),
            settings = AppSettings(store),
            appSettingsOpen = true,
        )
    }

    /** The reported symptom: tapping LEFT must move the highlight, not just flip the bar. */
    @Test
    fun tappingLeftMovesTheHandednessHighlight() {
        val state = openAppSettingsState()
        composeRule.setContent { CounterScreen(state = state) }

        // Default is right-handed.
        composeRule.onNodeWithContentDescription("app-settings-handedness-right").assertIsSelected()
        composeRule.onNodeWithContentDescription("app-settings-handedness-left").assertIsNotSelected()

        composeRule.onNodeWithContentDescription("app-settings-handedness-left").performClick()

        // After the tap the panel must recompose so LEFT is now the selected one.
        composeRule.onNodeWithContentDescription("app-settings-handedness-left").assertIsSelected()
        composeRule.onNodeWithContentDescription("app-settings-handedness-right").assertIsNotSelected()
    }

    /** The same defect on a feedback picker, where no bottom-bar tell reveals it. */
    @Test
    fun tappingASoundChipMovesTheSelection() {
        val state = openAppSettingsState()
        composeRule.setContent { CounterScreen(state = state) }

        // Default sound is OFF.
        composeRule.onNodeWithContentDescription("app-settings-sound-off").assertIsSelected()

        composeRule.onNodeWithContentDescription("app-settings-sound-pop").performScrollTo().performClick()

        composeRule.onNodeWithContentDescription("app-settings-sound-pop").assertIsSelected()
        composeRule.onNodeWithContentDescription("app-settings-sound-off").assertIsNotSelected()
    }
}
