//
//  AgendaRow.swift
//  LifeHub
//

import SwiftUI

/// One row of the unified agenda: color-coded type badge, title, timing,
/// and an optional amount.
struct AgendaRow: View {
    let item: AgendaItem
    var showsDate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            KindBadge(kind: item.kind)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if let subtitle = detailText {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if let amount = item.amount {
                    AmountText(amount: amount)
                        .font(.subheadline.weight(.semibold))
                }
                if item.hasTime {
                    Text(item.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if showsDate {
                    Text(item.date.relativeDayDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var detailText: String? {
        if let subtitle = item.subtitle, !subtitle.isEmpty { return subtitle }
        return nil
    }
}
