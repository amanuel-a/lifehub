//
//  ReportsView.swift
//  LifeHub
//

import SwiftUI
import SwiftData
import Charts

/// Spending charts and the monthly review: income vs. expenses trend,
/// spending by category, biggest expenses.
struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyCode) private var currencyCode

    @State private var month = Date.now
    @State private var summary: MonthlySummary?
    @State private var trend: [MonthlySummary] = []

    var body: some View {
        List {
            Section {
                MonthSwitcher(month: $month)
            }

            monthlyReviewSection
            categoryChartSection
            trendSection
            biggestExpensesSection
        }
        .navigationTitle("Reports")
        .onAppear(perform: refresh)
        .onChange(of: month) { refresh() }
    }

    // MARK: Monthly review

    private var monthlyReviewSection: some View {
        Section("Monthly Review") {
            if let summary {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        StatCard(titleKey: "Income", amount: summary.income, symbolName: "arrow.down.circle.fill", tint: .green)
                        StatCard(titleKey: "Spent", amount: summary.expenses, symbolName: "arrow.up.circle.fill", tint: .orange)
                        StatCard(titleKey: "Saved", amount: summary.savings, symbolName: "leaf.fill", tint: summary.savings >= 0 ? .mint : .red)
                    }
                    if summary.income > 0 {
                        savingsLine(summary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
    }

    private func savingsLine(_ summary: MonthlySummary) -> some View {
        let rate = NSDecimalNumber(decimal: summary.savings).doubleValue
            / NSDecimalNumber(decimal: summary.income).doubleValue
        return Label {
            rate >= 0
                ? Text("You kept \(rate, format: .percent.precision(.fractionLength(0))) of this month's income.")
                : Text("You spent more than you earned this month.")
        } icon: {
            Image(systemName: rate >= 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(rate >= 0 ? .green : .orange)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Category chart

    private var categoryChartSection: some View {
        Section("Spending by Category") {
            if let totals = summary?.categoryTotals.filter({ $0.total > 0 }), !totals.isEmpty {
                Chart(totals) { item in
                    SectorMark(
                        angle: .value("Amount", NSDecimalNumber(decimal: item.total).doubleValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Color(hex: item.colorHex))
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .padding(.vertical, 6)
                .accessibilityLabel(Text("Spending by category chart"))

                ForEach(totals) { item in
                    HStack {
                        Circle()
                            .fill(Color(hex: item.colorHex))
                            .frame(width: 10, height: 10)
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        AmountText(amount: item.total)
                            .font(.subheadline.weight(.medium))
                    }
                }
            } else {
                Text("No spending recorded for this month.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Trend

    private var trendSection: some View {
        Section("Last 6 Months") {
            if trend.contains(where: { $0.income > 0 || $0.expenses > 0 }) {
                Chart {
                    ForEach(trend, id: \.month) { item in
                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Income", NSDecimalNumber(decimal: item.income).doubleValue)
                        )
                        .position(by: .value("Kind", "Income"))
                        .foregroundStyle(.green.gradient)
                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Expenses", NSDecimalNumber(decimal: item.expenses).doubleValue)
                        )
                        .position(by: .value("Kind", "Expenses"))
                        .foregroundStyle(.orange.gradient)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .frame(height: 180)
                .padding(.vertical, 6)
                .accessibilityLabel(Text("Income versus expenses for the last six months"))

                HStack(spacing: 16) {
                    Label("Income", systemImage: "square.fill")
                        .foregroundStyle(.green)
                    Label("Expenses", systemImage: "square.fill")
                        .foregroundStyle(.orange)
                }
                .font(.caption)
                .labelStyle(.titleAndIcon)
            } else {
                Text("Charts appear as you log income and expenses.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Biggest expenses

    private var biggestExpensesSection: some View {
        Section("Biggest Expenses") {
            if let biggest = summary?.biggestExpenses, !biggest.isEmpty {
                ForEach(biggest) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.categoryName ?? String(localized: "Uncategorized"))
                                .font(.body.weight(.medium))
                            if !expense.note.isEmpty {
                                Text(expense.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            AmountText(amount: expense.amount)
                                .font(.subheadline.weight(.semibold))
                            Text(expense.date, format: .dateTime.day().month())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Nothing here yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func refresh() {
        summary = StatsService.summary(forMonthContaining: month, context: modelContext)
        trend = StatsService.monthlyTrend(monthsBack: 6, context: modelContext)
    }
}
