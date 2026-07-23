//
//  OnboardingView.swift
//  LifeHub
//

import SwiftUI

/// First-launch flow: welcome → choose a PIN → confirm → enable reminders.
struct OnboardingView: View {
    let onComplete: () -> Void

    private enum Step {
        case welcome
        case choosePIN
        case confirmPIN
    }

    @State private var step: Step = .welcome
    @State private var pin = ""
    @State private var firstPIN = ""
    @State private var mismatch = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()
            header
            content
            Spacer()
        }
        .padding()
        .background(.background)
        .animation(.spring(duration: 0.35), value: step)
    }

    @ViewBuilder
    private var header: some View {
        switch step {
        case .welcome:
            VStack(spacing: 14) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor.gradient)
                Text("Welcome to LifeHub")
                    .font(.largeTitle.weight(.bold))
                Text("Your money, salary, rent, debts, calendar, tasks, and notes — all in one private place.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        case .choosePIN:
            VStack(spacing: 8) {
                Text("Choose a PIN")
                    .font(.title2.weight(.semibold))
                Text("4–6 digits. Only you can open LifeHub.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .confirmPIN:
            VStack(spacing: 8) {
                Text("Confirm your PIN")
                    .font(.title2.weight(.semibold))
                Text(mismatch ? "PINs didn't match — try again." : "Enter the same PIN once more.")
                    .font(.subheadline)
                    .foregroundStyle(mismatch ? .red : .secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            Button {
                step = .choosePIN
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)

        case .choosePIN:
            VStack(spacing: 24) {
                PINPadView(pin: $pin, maxLength: 6)
                Button {
                    guard pin.count >= 4 else { return }
                    firstPIN = pin
                    pin = ""
                    step = .confirmPIN
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(pin.count < 4)
                .padding(.horizontal, 24)
            }

        case .confirmPIN:
            PINPadView(pin: $pin, maxLength: 6)
                .onChange(of: pin) { _, newValue in
                    guard newValue.count == firstPIN.count else {
                        if newValue.count > firstPIN.count { failConfirm() }
                        return
                    }
                    if newValue == firstPIN {
                        PINService.setPIN(newValue)
                        Haptics.shared.success()
                        Task {
                            _ = await NotificationScheduler.requestAuthorization()
                            onComplete()
                        }
                    } else {
                        failConfirm()
                    }
                }
        }
    }

    private func failConfirm() {
        Haptics.shared.warning()
        mismatch = true
        pin = ""
    }
}
