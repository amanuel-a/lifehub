//
//  PINPadView.swift
//  LifeHub
//

import SwiftUI

/// A reusable numeric PIN pad with dots, used by the lock screen and the
/// PIN setup flow. Large touch targets, VoiceOver labels, and haptic taps.
struct PINPadView: View {
    @Binding var pin: String
    let maxLength: Int
    var showsBiometricButton: Bool = false
    var onBiometric: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake = false

    var body: some View {
        VStack(spacing: 32) {
            dots
            keypad
        }
    }

    /// Triggers the wrong-PIN shake animation.
    func indicateFailure() {
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.4)) { shake.toggle() }
    }

    private var dots: some View {
        HStack(spacing: 18) {
            ForEach(0..<maxLength, id: \.self) { index in
                Circle()
                    .fill(index < pin.count ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .animation(.spring(duration: 0.25), value: pin.count)
            }
        }
        .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
        .accessibilityElement()
        .accessibilityLabel(Text("PIN entry, \(pin.count) of \(maxLength) digits entered"))
    }

    private var keypad: some View {
        Grid(horizontalSpacing: 24, verticalSpacing: 18) {
            ForEach(0..<3) { row in
                GridRow {
                    ForEach(1...3, id: \.self) { column in
                        digitButton(row * 3 + column)
                    }
                }
            }
            GridRow {
                if showsBiometricButton {
                    keyButton(symbol: "faceid", label: Text("Unlock with Face ID")) {
                        onBiometric?()
                    }
                } else {
                    Color.clear.frame(width: 76, height: 76)
                }
                digitButton(0)
                keyButton(symbol: "delete.left", label: Text("Delete")) {
                    guard !pin.isEmpty else { return }
                    pin.removeLast()
                }
            }
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            guard pin.count < maxLength else { return }
            Haptics.shared.tap()
            pin.append("\(digit)")
        } label: {
            Text("\(digit)")
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .frame(width: 76, height: 76)
                .background(.fill.secondary, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(digit)"))
    }

    private func keyButton(symbol: String, label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 76, height: 76)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Horizontal shake for wrong-PIN feedback.
private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: 12 * sin(animatableData * .pi * 4),
            y: 0
        ))
    }
}
