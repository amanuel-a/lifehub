//
//  CurrencyField.swift
//  LifeHub
//

import SwiftUI

/// A large, decimal-pad amount entry field used by every money form.
struct CurrencyField: View {
    @Environment(\.currencyCode) private var currencyCode

    let titleKey: LocalizedStringKey
    @Binding var text: String
    var prominent: Bool = false
    /// When provided, the trailing currency code becomes a tappable button that
    /// toggles between USD and ETB, bound here. When nil it just shows the
    /// app's currency.
    var toggleableCurrency: Binding<String>? = nil

    var body: some View {
        HStack(spacing: 8) {
            TextField(titleKey, text: $text)
                .keyboardType(.decimalPad)
                .font(prominent ? .system(.largeTitle, design: .rounded).weight(.semibold) : .body)
                .monospacedDigit()
                .multilineTextAlignment(prominent ? .center : .leading)
            if let toggleableCurrency {
                Button {
                    toggleableCurrency.wrappedValue = toggleableCurrency.wrappedValue == "USD" ? "ETB" : "USD"
                    Haptics.shared.tap()
                } label: {
                    HStack(spacing: 3) {
                        Text(toggleableCurrency.wrappedValue)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Currency: \(toggleableCurrency.wrappedValue). Tap to switch."))
            } else if !prominent {
                Text(currencyCode)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(titleKey))
    }
}
