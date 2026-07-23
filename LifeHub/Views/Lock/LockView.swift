//
//  LockView.swift
//  LifeHub
//

import SwiftUI

/// The PIN lock screen shown on launch and whenever the app returns from
/// the background. Offers Face ID when enabled.
struct LockView: View {
    let useBiometrics: Bool
    let onUnlock: () -> Void

    @State private var pin = ""
    @State private var failedAttempt = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: failedAttempt)
                Text("LifeHub is locked")
                    .font(.title2.weight(.semibold))
                Text("Enter your PIN")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            PINPadView(
                pin: $pin,
                maxLength: 6,
                showsBiometricButton: useBiometrics && PINService.biometricsAvailable,
                onBiometric: attemptBiometrics
            )

            Spacer()
        }
        .padding()
        .background(.background)
        .onChange(of: pin) { _, newValue in
            // PINs are 4–6 digits; try validating from 4 digits up.
            if newValue.count >= 4, PINService.validate(newValue) {
                Haptics.shared.success()
                onUnlock()
            } else if newValue.count == 6 {
                Haptics.shared.warning()
                failedAttempt.toggle()
                pin = ""
            }
        }
        .task {
            if useBiometrics { attemptBiometrics() }
        }
    }

    private func attemptBiometrics() {
        guard useBiometrics, PINService.biometricsAvailable else { return }
        Task {
            if await PINService.authenticateWithBiometrics() {
                Haptics.shared.success()
                onUnlock()
            }
        }
    }
}
