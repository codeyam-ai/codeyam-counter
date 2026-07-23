package com.codeyam.android

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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
            feedback = SystemCounterFeedback(),
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
