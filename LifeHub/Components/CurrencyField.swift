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

    var body: some View {
        HStack(spacing: 8) {
            TextField(titleKey, text: $text)
                .keyboardType(.decimalPad)
                .font(prominent ? .system(.largeTitle, design: .rounded).weight(.semibold) : .body)
                .monospacedDigit()
                .multilineTextAlignment(prominent ? .center : .leading)
            if !prominent {
                Text(currencyCode)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(titleKey))
    }
}
