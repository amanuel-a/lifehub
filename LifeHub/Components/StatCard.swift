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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(titleKey, systemImage: symbolName)
                .font(.caption.weight(.medium))
                .foregroundStyle(tint)
                .labelStyle(.titleAndIcon)
            AmountText(amount: amount, compact: true)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
