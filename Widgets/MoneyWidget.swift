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

    /// Per-currency displays, matching the app's cards exactly.
    private var income: MoneyFormat.TotalDisplay {
        display(entry.snapshot.monthIncomeByCurrency, fallback: entry.snapshot.monthIncome)
    }

    private var iOwe: MoneyFormat.TotalDisplay {
        display(entry.snapshot.iOweByCurrency, fallback: entry.snapshot.totalIOwe)
    }

    private var owedToMe: MoneyFormat.TotalDisplay {
        display(entry.snapshot.owedToMeByCurrency, fallback: entry.snapshot.totalOwedToMe)
    }

    private func display(_ buckets: [String: Decimal], fallback: Decimal) -> MoneyFormat.TotalDisplay {
        buckets.isEmpty
            ? MoneyFormat.TotalDisplay(amount: fallback, code: code, extra: nil)
            : MoneyFormat.display(of: buckets, appCurrency: code)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This Month", systemImage: "banknote.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)

            if family == .systemSmall {
                stat("In", income)
                stat("Out", MoneyFormat.TotalDisplay(amount: entry.snapshot.monthExpenses, code: code, extra: nil), tint: .orange)
                stat("Saved", MoneyFormat.TotalDisplay(amount: entry.snapshot.monthSavings, code: code, extra: nil), tint: entry.snapshot.monthSavings >= 0 ? .mint : .red)
            } else {
                HStack(spacing: 12) {
                    bigStat("Income", income, tint: .green)
                    bigStat("Spent", MoneyFormat.TotalDisplay(amount: entry.snapshot.monthExpenses, code: code, extra: nil), tint: .orange)
                    bigStat("Saved", MoneyFormat.TotalDisplay(amount: entry.snapshot.monthSavings, code: code, extra: nil), tint: entry.snapshot.monthSavings >= 0 ? .mint : .red)
                }
                Divider()
                HStack(spacing: 12) {
                    smallLine("I owe", iOwe, tint: .pink)
                    smallLine("Owed to me", owedToMe, tint: .teal)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func text(for display: MoneyFormat.TotalDisplay) -> String {
        let main = MoneyFormat.compactString(display.amount, code: display.code)
        guard let extra = display.extra else { return main }
        return "\(main) \(extra)"
    }

    private func stat(_ title: LocalizedStringKey, _ display: MoneyFormat.TotalDisplay, tint: Color = .green) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(text(for: display))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func bigStat(_ title: LocalizedStringKey, _ display: MoneyFormat.TotalDisplay, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(MoneyFormat.compactString(display.amount, code: display.code))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let extra = display.extra {
                Text(extra)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallLine(_ title: LocalizedStringKey, _ display: MoneyFormat.TotalDisplay, tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text(for: display))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
