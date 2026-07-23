//
//  Haptics.swift
//  LifeHub
//

import Foundation
import CoreHaptics
import UIKit

/// Native haptic feedback. Uses Core Haptics for the custom "money"
/// confirmation pattern and system feedback generators for standard taps.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?

    private init() {
        prepareEngine()
    }

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in
            try? self?.engine?.start()
        }
        try? engine?.start()
    }

    /// Light tap for selections and toggles.
    func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Success notification for saves and completions.
    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning for destructive or over-budget moments.
    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// A short rising double-tap used when money is confirmed received —
    /// a custom Core Haptics pattern.
    func moneyConfirmed() {
        guard let engine else {
            success()
            return
        }
        do {
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0.12
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            success()
        }
    }
}
