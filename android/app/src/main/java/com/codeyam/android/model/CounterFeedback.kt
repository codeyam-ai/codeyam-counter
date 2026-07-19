package com.codeyam.android.model

/**
 * The change-feedback seam: increment/subtract ask this to emit a sound and/or
 * haptic per the resolved options, without the model knowing anything about the
 * Android view/haptic/audio APIs. Kept an interface so unit tests substitute a
 * silent, deterministic implementation. Ported from the iOS `CounterFeedback`
 * protocol.
 */
interface CounterFeedback {
    /**
     * Emit feedback for a count change. Each option is honored independently; an
     * `OFF` option emits nothing for that channel.
     */
    fun changed(sound: SoundOption, haptic: HapticOption)
}

/**
 * The default: does nothing. Keeps unit tests and previews silent and
 * deterministic (no real audio or haptics). Ported from iOS `NoopCounterFeedback`.
 */
class NoopCounterFeedback : CounterFeedback {
    override fun changed(sound: SoundOption, haptic: HapticOption) {}
}

/**
 * The production implementation. Owns only the option gating: a non-`OFF` haptic
 * fires the haptic emitter with its feel, a non-`OFF` sound fires the sound emitter
 * with its choice. The emitters are injectable so the gating logic is unit-testable
 * without hardware — the actual Android view/haptic/audio wiring is supplied by the
 * UI layer (which owns a `View`/`Context`) when it constructs this. They default to
 * no-ops so the gating contract is exercised in isolation, mirroring how the iOS
 * `SystemCounterFeedback` guards its real I/O behind `#if canImport(UIKit)`.
 */
class SystemCounterFeedback(
    private val emitHaptic: (HapticOption) -> Unit = {},
    private val emitSound: (SoundOption) -> Unit = {},
) : CounterFeedback {
    override fun changed(sound: SoundOption, haptic: HapticOption) {
        if (haptic != HapticOption.OFF) emitHaptic(haptic)
        if (sound != SoundOption.OFF) emitSound(sound)
    }
}
