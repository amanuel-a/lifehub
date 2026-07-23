//
//  MoneyWidget.swift
//  LifeHubWidgets
//

import WidgetKit
import SwiftUI

/// "Money" — this month's income vs. expenses and debt totals at a glance.
struct MoneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeHubMoney", provider: SnapshotProvider()) { entry in
            MoneyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Money at a Glance")
        .description("This month's income, spending, savings, and debts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MoneyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var code: String { entry.snapshot.currencyCode }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This Month", systemImage: "banknote.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)

            if family == .systemSmall {
                stat("In", entry.snapshot.monthIncome, .green)
                stat("Out", entry.snapshot.monthExpenses, .orange)
                stat("Saved", entry.snapshot.monthSavings, entry.snapshot.monthSavings >= 0 ? .mint : .red)
            } else {
                HStack(spacing: 12) {
                    bigStat("Income", entry.snapshot.monthIncome, .green)
                    bigStat("Spent", entry.snapshot.monthExpenses, .orange)
                    bigStat("Saved", entry.snapshot.monthSavings, entry.snapshot.monthSavings >= 0 ? .mint : .red)
                }
                Divider()
                HStack(spacing: 12) {
                    smallLine("I owe", entry.snapshot.totalIOwe, .pink)
                    smallLine("Owed to me", entry.snapshot.totalOwedToMe, .teal)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func stat(_ title: LocalizedStringKey, _ amount: Decimal, _ tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(MoneyFormat.compactString(amount, code: code))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    private func bigStat(_ title: LocalizedStringKey, _ amount: Decimal, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(MoneyFormat.compactString(amount, code: code))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallLine(_ title: LocalizedStringKey, _ amount: Decimal, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(MoneyFormat.compactString(amount, code: code))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
