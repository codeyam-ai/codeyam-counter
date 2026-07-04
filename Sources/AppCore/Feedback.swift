import Foundation
#if canImport(UIKit)
import UIKit
import AudioToolbox
#endif

/// The change-feedback seam: increment/subtract ask this to emit a sound and/or
/// haptic per the resolved options, without the model knowing anything about
/// UIKit or audio. Kept a protocol so unit tests and non-UIKit builds substitute
/// a silent, deterministic implementation.
public protocol CounterFeedback {
    /// Emit feedback for a count change. Each option is honored independently; an
    /// `.off` option emits nothing for that channel.
    func changed(sound: SoundOption, haptic: HapticOption)
}

/// The default: does nothing. Keeps `ModelTests`, SwiftUI previews, and the
/// macOS build silent and deterministic (no real audio or haptics).
public struct NoopCounterFeedback: CounterFeedback {
    public init() {}
    public func changed(sound: SoundOption, haptic: HapticOption) {}
}

/// The production implementation. Owns only the option gating: a non-`.off`
/// haptic fires the haptic emitter with its intensity, a non-`.off` sound fires
/// the sound emitter with its choice. The emitters are injectable (defaulting to
/// the real UIKit/audio effects) so the gating logic is unit-testable without
/// hardware — the actual platform I/O lives in the thin `defaultHaptic`/
/// `defaultSound` passthroughs, guarded by `canImport(UIKit)` so the shared
/// target still compiles on macOS/preview.
public struct SystemCounterFeedback: CounterFeedback {
    private let emitHaptic: (HapticOption) -> Void
    private let emitSound: (SoundOption) -> Void

    public init() {
        self.init(emitHaptic: SystemCounterFeedback.defaultHaptic,
                  emitSound: SystemCounterFeedback.defaultSound)
    }

    /// Testing seam: substitute spy emitters to assert the option gating.
    init(emitHaptic: @escaping (HapticOption) -> Void, emitSound: @escaping (SoundOption) -> Void) {
        self.emitHaptic = emitHaptic
        self.emitSound = emitSound
    }

    public func changed(sound: SoundOption, haptic: HapticOption) {
        if haptic != .off { emitHaptic(haptic) }
        if sound != .off { emitSound(sound) }
    }

    private static func defaultHaptic(_ option: HapticOption) {
        #if canImport(UIKit)
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch option {
        case .off: return
        case .light: style = .light
        case .medium: style = .medium
        case .heavy: style = .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    private static func defaultSound(_ option: SoundOption) {
        #if canImport(UIKit)
        // Distinct short iOS system sounds per choice; `.off` never reaches here.
        let id: SystemSoundID
        switch option {
        case .off: return
        case .tock: id = 1104
        case .pop: id = 1105
        case .click: id = 1123
        case .bloop: id = 1103
        case .ding: id = 1113
        }
        AudioServicesPlaySystemSound(id)
        #endif
    }
}
