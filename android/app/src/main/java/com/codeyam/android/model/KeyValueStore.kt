package com.codeyam.android.model

import android.content.SharedPreferences

/**
 * The persistence seam the model reads and writes, mirroring the role iOS's
 * `UserDefaults` plays for the Swift `CounterModel`/`AppSettings`.
 *
 * Kept an interface for the same reason the Swift code injects `UserDefaults`:
 * unit tests substitute a deterministic in-memory store, and the app injects a
 * `SharedPreferences`-backed one. CodeYam's Android scenario seeder writes the
 * same keys into `SharedPreferences` before relaunch, so a seeded scenario is
 * observed from the first frame.
 *
 * The read accessors mirror `UserDefaults`'s tolerant coercion: a value seeded
 * as a string (the seeder often writes strings) is still read as the int/bool it
 * represents, so the seeding contract survives the string round-trip.
 */
interface KeyValueStore {
    /** True when a value has been stored for [key] — the `object(forKey:) != nil` check. */
    fun contains(key: String): Boolean

    /** The stored string, or null when absent or not string-shaped. */
    fun getString(key: String): String?

    /** The stored int, coercing a string-shaped value; 0 when absent or unparseable. */
    fun getInt(key: String): Int

    /** The stored bool, coercing a string/number-shaped value; false when absent. */
    fun getBoolean(key: String): Boolean

    fun putString(key: String, value: String)
    fun putInt(key: String, value: Int)
    fun putBoolean(key: String, value: Boolean)
}

/**
 * In-memory [KeyValueStore] for tests and as the default when no persistence is
 * wired. Stores values as `Any` and coerces on read exactly like `UserDefaults`,
 * so a value seeded as a `String` still reads correctly through [getInt]/
 * [getBoolean] — the property the seeding contract depends on.
 */
class InMemoryKeyValueStore(initial: Map<String, Any> = emptyMap()) : KeyValueStore {
    private val store: MutableMap<String, Any> = initial.toMutableMap()

    override fun contains(key: String): Boolean = store.containsKey(key)

    override fun getString(key: String): String? = store[key] as? String

    override fun getInt(key: String): Int = when (val v = store[key]) {
        is Int -> v
        is Long -> v.toInt()
        is Number -> v.toInt()
        is String -> v.toIntOrNull() ?: v.toDoubleOrNull()?.toInt() ?: 0
        is Boolean -> if (v) 1 else 0
        else -> 0
    }

    override fun getBoolean(key: String): Boolean = when (val v = store[key]) {
        is Boolean -> v
        is Number -> v.toDouble() != 0.0
        is String -> v == "true" || v == "1" || v == "YES" || v.toDoubleOrNull()?.let { it != 0.0 } == true
        else -> false
    }

    override fun putString(key: String, value: String) { store[key] = value }
    override fun putInt(key: String, value: Int) { store[key] = value }
    override fun putBoolean(key: String, value: Boolean) { store[key] = value }
}

/**
 * [KeyValueStore] backed by Android [SharedPreferences] — the app-runtime store.
 * `getInt`/`getBoolean` fall back to parsing a string when a value was seeded as
 * a string, matching [InMemoryKeyValueStore] and `UserDefaults` coercion.
 */
class SharedPreferencesStore(private val prefs: SharedPreferences) : KeyValueStore {
    override fun contains(key: String): Boolean = prefs.contains(key)

    override fun getString(key: String): String? = try {
        prefs.getString(key, null)
    } catch (_: ClassCastException) {
        null
    }

    override fun getInt(key: String): Int = try {
        prefs.getInt(key, 0)
    } catch (_: ClassCastException) {
        prefs.getString(key, null)?.toIntOrNull() ?: 0
    }

    override fun getBoolean(key: String): Boolean = try {
        prefs.getBoolean(key, false)
    } catch (_: ClassCastException) {
        prefs.getString(key, null)?.let { it == "true" || it == "1" || it == "YES" } ?: false
    }

    override fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    override fun putInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }

    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }
}
