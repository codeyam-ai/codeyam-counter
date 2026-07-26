package com.codeyam.android.ui

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.codeyam.android.model.HapticOption
import com.codeyam.android.model.SoundOption

/**
 * The Android hardware bridges for [com.codeyam.android.model.SystemCounterFeedback].
 *
 * `SystemCounterFeedback` owns only the option gating (a non-`OFF` channel fires its
 * emitter); the emitters themselves — the real `Vibrator` / `ToneGenerator` I/O — are
 * supplied here by the UI layer, which owns a `Context`. Keeping the I/O in these
 * factories is what lets the gating stay hardware-free and unit-tested with spies
 * (`FeedbackTest`), mirroring how the iOS `SystemCounterFeedback` guards its real I/O
 * behind `#if canImport(UIKit)`.
 *
 * The option → cue *decisions* are split out as the pure [soundTone] / [hapticSpec]
 * mappings so they are unit-testable (`AndroidFeedbackTest`) without a device; the
 * factories below are the thin I/O that applies those decisions to real hardware.
 *
 * Both factories degrade to a silent no-op when the hardware/service is unavailable,
 * so a device with no vibrator (or a `ToneGenerator` that fails to construct — it can
 * on some devices) never crashes the increment path; it just plays nothing.
 */

/**
 * Build the haptic emitter: each non-`OFF` [HapticOption] feel maps to a qualitatively
 * distinct vibration. Returns a no-op when the device exposes no usable vibrator.
 */
fun androidHapticEmitter(context: Context): (HapticOption) -> Unit {
    val vibrator = resolveVibrator(context.applicationContext)
    if (vibrator == null || !vibrator.hasVibrator()) return {}
    return emit@{ option ->
        val spec = hapticSpec(option) ?: return@emit
        applyHaptic(vibrator, spec)
    }
}

/**
 * Build the sound emitter: each non-`OFF` [SoundOption] maps to a distinct
 * [ToneGenerator] cue. A single generator is created lazily and reused for the app's
 * lifetime (it owns a native audio resource; re-creating one per tap is expensive and
 * flaky). Returns a no-op if the generator cannot be constructed.
 */
fun androidSoundEmitter(): (SoundOption) -> Unit {
    // Lazily hold one generator; guard construction because ToneGenerator throws a
    // RuntimeException on devices that cannot allocate the audio resource.
    val generator: ToneGenerator? = try {
        ToneGenerator(AudioManager.STREAM_MUSIC, TONE_VOLUME)
    } catch (_: RuntimeException) {
        null
    }
    if (generator == null) return {}
    return emit@{ option ->
        val tone = soundTone(option) ?: return@emit
        try {
            generator.startTone(tone, TONE_DURATION_MS)
        } catch (_: RuntimeException) {
            // A failed tone must never break the increment it accompanies.
        }
    }
}

private const val TONE_VOLUME = 80 // 0..100
private const val TONE_DURATION_MS = 140

/** A gentler amplitude for `SOFT`; the rest use the system default. */
internal const val SOFT_AMPLITUDE = 60

/** Mirrors `VibrationEffect.DEFAULT_AMPLITUDE` (a compile-time -1) so [hapticSpec] stays hardware-free. */
internal const val DEFAULT_AMPLITUDE = -1

/**
 * A hardware-agnostic description of a haptic feel: either a single one-shot pulse
 * `(durationMs, amplitude)` or a `(timings, repeat)` waveform. Pure data so the
 * [HapticOption] → feel mapping is unit-testable without a `Vibrator`.
 */
internal sealed interface HapticSpec {
    data class OneShot(val durationMs: Long, val amplitude: Int) : HapticSpec
    data class Waveform(val timings: List<Long>, val repeat: Int) : HapticSpec
}

/** Map each non-`OFF` feel to a distinct, device-independent [HapticSpec]; `OFF` → null. */
internal fun hapticSpec(option: HapticOption): HapticSpec? = when (option) {
    HapticOption.OFF -> null
    HapticOption.SOFT -> HapticSpec.OneShot(durationMs = 20, amplitude = SOFT_AMPLITUDE)
    HapticOption.SHARP -> HapticSpec.OneShot(durationMs = 12, amplitude = DEFAULT_AMPLITUDE)
    HapticOption.DOUBLE -> HapticSpec.Waveform(timings = listOf(0L, 14L, 60L, 14L), repeat = -1)
    HapticOption.BUZZ -> HapticSpec.OneShot(durationMs = 60, amplitude = DEFAULT_AMPLITUDE)
}

/** Map each non-`OFF` sound to a distinct built-in [ToneGenerator] tone; `OFF` → null. */
internal fun soundTone(option: SoundOption): Int? = when (option) {
    SoundOption.OFF -> null
    SoundOption.TOCK -> ToneGenerator.TONE_PROP_BEEP
    SoundOption.POP -> ToneGenerator.TONE_PROP_ACK
    SoundOption.CLICK -> ToneGenerator.TONE_CDMA_PIP
    SoundOption.BLOOP -> ToneGenerator.TONE_PROP_PROMPT
    SoundOption.DING -> ToneGenerator.TONE_PROP_BEEP2
}

/** Resolve the system vibrator across the API-31 `VibratorManager` split. */
private fun resolveVibrator(context: Context): Vibrator? =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
        manager?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

/**
 * Apply a resolved [HapticSpec] to real hardware. Uses `VibrationEffect` on API 26+;
 * falls back to the deprecated duration/pattern `vibrate` calls on API 24–25 (this
 * module's `minSdk` is 24).
 */
private fun applyHaptic(vibrator: Vibrator, spec: HapticSpec) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val effect = when (spec) {
            is HapticSpec.OneShot -> VibrationEffect.createOneShot(spec.durationMs, spec.amplitude)
            is HapticSpec.Waveform -> VibrationEffect.createWaveform(spec.timings.toLongArray(), spec.repeat)
        }
        vibrator.vibrate(effect)
    } else {
        @Suppress("DEPRECATION")
        when (spec) {
            is HapticSpec.OneShot -> vibrator.vibrate(spec.durationMs)
            is HapticSpec.Waveform -> vibrator.vibrate(spec.timings.toLongArray(), spec.repeat)
        }
    }
}
