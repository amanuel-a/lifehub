//
//  StatCard.swift
//  LifeHub
//

import SwiftUI

/// A small glanceable stat used across the dashboard and money screens.
struct StatCard: View {
    let titleKey: LocalizedStringKey
    let amount: Decimal
    let symbolName: String
    let tint: Color
    /// Extra line under the amount, e.g. "+ 100 USD" for a second currency.
    var extraText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.gradient, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                AmountText(amount: amount, compact: true)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let extraText {
                    Text(extraText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.fill.tertiary, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
