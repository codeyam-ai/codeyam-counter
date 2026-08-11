package com.codeyam.android

import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.codeyam.android.model.AppSettings
import com.codeyam.android.model.CounterModel
import com.codeyam.android.model.SeedPolicy
import com.codeyam.android.model.SharedPreferencesStore
import com.codeyam.android.model.SystemCounterFeedback
import com.codeyam.android.ui.CounterColors
import com.codeyam.android.ui.CounterScreen
import com.codeyam.android.ui.CounterScreenState
import com.codeyam.android.ui.androidHapticEmitter
import com.codeyam.android.ui.androidSoundEmitter

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Opt in explicitly rather than inheriting the target-36 default, so the
        // bar ICON appearance is ours: `SystemBarStyle.dark` means "dark bar
        // background, therefore light icons", which is what this near-black app
        // needs. A transparent scrim keeps the app colour running bar to bar.
        //
        // This replaces `android:statusBarColor` / `android:navigationBarColor`
        // in themes.xml, which are deprecated no-ops on API 35+ and were already
        // doing nothing. The layout side of edge-to-edge — keeping the content
        // clear of the bars — is handled by the inset padding in CounterScreen.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )

        // The default SharedPreferences file (`<package>_preferences.xml`) is the
        // store CodeYam's Android scenario seeder writes before relaunching the app,
        // and it is also where the model persists real user state. Both sides use the
        // same keys (`counters`, `selectedCounterId`, …), so a seeded scenario is
        // observed from the first frame — `SeedPolicy` is what lets a release build
        // still tell injected state from a real user's own.
        val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
        val store = SharedPreferencesStore(prefs)

        // `BuildConfig` is not generated for this module, so debuggability is read off
        // the manifest-derived application flags instead — the same signal, without
        // turning on the buildConfig feature.
        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

        val policy = SeedPolicy.current(isDebuggable)
        val model = CounterModel(
            store = store,
            // Supply the real Android hardware bridges to the feedback seam; the
            // option gating in `SystemCounterFeedback` stays hardware-free (and
            // unit-tested), while these emitters own the Vibrator / ToneGenerator I/O.
            feedback = SystemCounterFeedback(
                emitHaptic = androidHapticEmitter(this),
                emitSound = androidSoundEmitter(),
            ),
            policy = policy,
        )

        // The four panel-open flags are pure-UI seed keys the real app never
        // persists, so a distribution build must not honor them: they are gated
        // on the same trust decision as the data stores. An untrusted store
        // ignores every flag, so a stray `appSettingsOpen=true` cannot boot
        // production into a panel.
        val trusted = policy.trustsStore(store)
        val state = CounterScreenState(
            model = model,
            settings = AppSettings(store, policy),
            settingsOpen = trusted && store.getBoolean("settingsOpen"),
            appSettingsOpen = trusted && store.getBoolean("appSettingsOpen"),
            counterListOpen = trusted && store.getBoolean("counterListOpen"),
            graphOpen = trusted && store.getBoolean("graphOpen"),
        )

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = CounterColors.bg,
                ) {
                    CounterScreen(state)
                }
            }
        }
    }
}
