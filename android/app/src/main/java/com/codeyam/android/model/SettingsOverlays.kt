package com.codeyam.android.model

/**
 * The open/closed state of the two settings overlays, which are mutually
 * exclusive: only one settings panel may be on screen at a time. Modeled as one
 * value rather than two independent booleans so the "never both open" rule lives
 * in one testable place instead of being re-derived at each tap site. Ported from
 * iOS `SettingsOverlays`.
 *
 * Only the *toggles* enforce exclusivity. Closing a panel never reopens the other,
 * and seeding both open is still representable — the rule governs user taps.
 */
data class SettingsOverlays(
    /** The per-counter settings panel, opened from the switcher's gear. */
    val counterSettings: Boolean = false,
    /** The system-wide App Settings panel, opened from the header. */
    val appSettings: Boolean = false,
) {
    /**
     * Tapping the header control. Opening App Settings closes the per-counter
     * panel; closing it just closes it.
     */
    fun togglingAppSettings(): SettingsOverlays {
        val opening = !appSettings
        return SettingsOverlays(
            counterSettings = if (opening) false else counterSettings,
            appSettings = opening,
        )
    }

    /**
     * Tapping the switcher's gear. Opening the per-counter panel closes App
     * Settings; closing it just closes it.
     */
    fun togglingCounterSettings(): SettingsOverlays {
        val opening = !counterSettings
        return SettingsOverlays(
            counterSettings = opening,
            appSettings = if (opening) false else appSettings,
        )
    }
}
