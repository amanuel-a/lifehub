//
//  AmountText.swift
//  LifeHub
//

import SwiftUI

/// Formats a money amount with thousands separators and the configured
/// currency, with rounded monospaced digits for a first-party feel.
struct AmountText: View {
    @Environment(\.currencyCode) private var currencyCode

    let amount: Decimal
    var compact: Bool = false

    var body: some View {
        Text(formatted)
            .fontDesign(.rounded)
            .monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel(Text(formatted))
    }

    private var formatted: String {
        compact
            ? MoneyFormat.compactString(amount, code: currencyCode)
            : MoneyFormat.string(amount, code: currencyCode)
    }
}
