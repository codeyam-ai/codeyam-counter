package com.codeyam.android

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.codeyam.android.ui.MainScreen
import com.codeyam.android.ui.MainViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Read the initial count from the default SharedPreferences file
        // (`<package>_preferences.xml`). This is the store CodeYam's Android
        // scenario seeder writes before relaunching the app, so a scenario that
        // seeds `count` is reflected on screen at launch. Defaults to 0 (the
        // day-one empty state) when no scenario has been seeded.
        val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
        val initialCount = prefs.getInt("count", 0)
        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MainScreen(MainViewModel(initialCount))
                }
            }
        }
    }
}
