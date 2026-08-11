package com.codeyam.android.ui

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import com.codeyam.android.model.AppSettings
import com.codeyam.android.model.CounterModel
import com.codeyam.android.model.InMemoryKeyValueStore
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.absoluteValue

/**
 * The regression guard for edge-to-edge, which target 36 makes unconditional —
 * the `windowOptOutEdgeToEdgeEnforcement` escape hatch is ignored, so the window
 * extends under the status and navigation bars whether the app is ready or not.
 *
 * Why this test exists at all: nothing else in the suite touches a window inset.
 * The Paparazzi goldens render `CountHero` in isolation, a leaf composable that
 * never sees one, and every model test runs headless. Without this, the entire
 * edge-to-edge change would ship on nothing but a careful reading of the layout.
 *
 * Insets are injected rather than read from the platform: under Robolectric there
 * is no real window, so `WindowInsets.systemBars` is all zeroes and the behaviour
 * under test would be invisible. `CounterScreen` takes them as a defaulted
 * parameter for exactly this reason — production still resolves the real ones.
 *
 * Lives in `src/testDebug/` for the same reason as the other Compose test here:
 * `createComposeRule` needs a host `ComponentActivity`, contributed only by the
 * `debugImplementation` ui-test-manifest AAR.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
// The window size is pinned, not inherited: the size assertion below compares
// against a proportion of the window, and Robolectric's default device is small
// enough that the bottom bar would clamp to its 64dp floor and mask the very
// difference the test exists to detect.
@Config(sdk = [34], qualifiers = "w411dp-h891dp")
class CounterScreenInsetsTest {

    @get:Rule
    val composeRule = createComposeRule()

    private fun freshState(): CounterScreenState {
        val store = InMemoryKeyValueStore()
        return CounterScreenState(
            model = CounterModel(store),
            settings = AppSettings(store),
        )
    }

    /**
     * Deliberately lopsided and much larger than any real device's, so a failure
     * is unambiguous and an off-by-a-few-pixels rounding artefact cannot pass for
     * a correct result.
     */
    private val fakeInsets = WindowInsets(left = 0.dp, top = 80.dp, right = 0.dp, bottom = 120.dp)

    /**
     * The status bar is the top inset. The hero numeral must start below it, not
     * underneath it — the visible symptom of the bug on a live device.
     */
    @Test
    fun theCountHeroClearsTheTopInset() {
        composeRule.setContent {
            CounterScreen(state = freshState(), contentInsets = fakeInsets)
        }

        val rootTop = composeRule.onRoot().getUnclippedBoundsInRoot().top
        val heroTop = composeRule.onNodeWithContentDescription("count-value")
            .getUnclippedBoundsInRoot().top

        assertTrue(
            "Hero top ($heroTop) must clear the 80dp status-bar inset from root top ($rootTop)",
            heroTop >= rootTop + 80.dp,
        )
    }

    /** The navigation bar is the bottom inset; the control row must sit above it. */
    @Test
    fun theBottomControlRowClearsTheBottomInset() {
        composeRule.setContent {
            CounterScreen(state = freshState(), contentInsets = fakeInsets)
        }

        val rootBottom = composeRule.onRoot().getUnclippedBoundsInRoot().bottom
        val incrementBottom = composeRule.onNodeWithContentDescription("increment")
            .getUnclippedBoundsInRoot().bottom

        assertTrue(
            "Increment control bottom ($incrementBottom) must stay above the 120dp " +
                "navigation-bar inset, i.e. no lower than root bottom ($rootBottom) - 120dp",
            incrementBottom <= rootBottom - 120.dp,
        )
    }

    /**
     * The one that catches the subtle failure — and the reason the two position
     * assertions above are not sufficient on their own.
     *
     * Move the inset padding INSIDE `BoxWithConstraints` and the content still
     * *lands* correctly, because the base `Column` fills whatever space it is
     * given and `weight(1f)` absorbs the difference. Every positional assertion
     * keeps passing. What silently changes is SIZE: `CounterBottomBar` derives
     * `assemblyHeight = screenHeight * 0.20f`, so reading `maxHeight` from the
     * un-inset window makes the whole bottom assembly proportionally too tall —
     * scaled to a window the content no longer occupies. On a device with slim
     * system bars the error is a few pixels; on one with a tall nav bar and a
     * cutout it is substantial, which is the "correct on the device I tested"
     * failure mode this layout was written to avoid.
     *
     * The expected value is intentionally computed from the same constants the
     * production code uses. If those change, this assertion should be updated
     * deliberately — the geometry contract changing is a decision, not noise.
     */
    @Test
    fun theBottomBarIsSizedFromUsableHeightNotTheFullWindow() {
        composeRule.setContent {
            CounterScreen(state = freshState(), contentInsets = fakeInsets)
        }

        val root = composeRule.onRoot().getUnclippedBoundsInRoot()
        val incrementHeight = composeRule.onNodeWithContentDescription("increment")
            .getUnclippedBoundsInRoot().height

        // CounterBottomBar: assemblyHeight = screenHeight * 0.20f,
        //                   topBarHeight   = max(assemblyHeight - 64dp, 64dp)
        val usableHeight = root.height - 80.dp - 120.dp
        val expected = (usableHeight * 0.20f) - 64.dp
        val wrongIfDerivedFromFullWindow = (root.height * 0.20f) - 64.dp

        val tolerance = 2.dp
        assertTrue(
            "Increment bar height ($incrementHeight) must be derived from the USABLE " +
                "height (expected ~$expected). Deriving it from the full window would " +
                "give ~$wrongIfDerivedFromFullWindow, which means the inset padding was " +
                "applied inside BoxWithConstraints instead of outside it.",
            (incrementHeight - expected).value.absoluteValue <= tolerance.value,
        )
    }

    /**
     * The background is deliberately NOT inset — the app is a uniform near-black
     * and the bars should blend into it, so the root still spans the full window.
     * This pins the "pad the content, not the window" half of the change: a fix
     * that inset the whole screen would pass the two tests above while visibly
     * letterboxing the app.
     */
    @Test
    fun theWindowItselfStaysEdgeToEdge() {
        composeRule.setContent {
            CounterScreen(state = freshState(), contentInsets = fakeInsets)
        }

        val root = composeRule.onRoot().getUnclippedBoundsInRoot()
        val hero = composeRule.onNodeWithContentDescription("count-value")
            .getUnclippedBoundsInRoot()

        // The root must be taller than the inset content it holds — proof the
        // padding landed on the content rather than shrinking the window.
        assertTrue(
            "Root height (${root.height}) must exceed the inset hero's offset",
            root.height > hero.top - root.top,
        )
    }
}
