//
//  StatsService.swift
//  LifeHub
//
//  Monthly money math: income vs. expenses, per-category totals, biggest
//  expenses, savings, and budget status. Used by the dashboard, the reports
//  screen, and the monthly review.
//

import Foundation
import SwiftData

struct CategoryTotal: Identifiable, Hashable {
    let id: UUID
    let name: String
    let symbolName: String
    let colorHex: String
    let total: Decimal
    let budget: Decimal?

    /// 0...1+ of budget used; nil when no budget is set.
    var budgetUsage: Double? {
        guard let budget, budget > 0 else { return nil }
        return NSDecimalNumber(decimal: total).doubleValue / NSDecimalNumber(decimal: budget).doubleValue
    }
}

struct MonthlySummary {
    var month: Date
    var income: Decimal = 0
    var expenses: Decimal = 0
    var categoryTotals: [CategoryTotal] = []
    var biggestExpenses: [ExpenseSnapshot] = []

    var savings: Decimal { income - expenses }

    struct ExpenseSnapshot: Identifiable, Hashable {
        let id: UUID
        let amount: Decimal
        let date: Date
        let note: String
        let categoryName: String?
    }
}

@MainActor
enum StatsService {
    /// The calendar month containing `date`.
    static func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? date
        return DateInterval(start: start, end: end)
    }

    static func summary(forMonthContaining date: Date, context: ModelContext, calendar: Calendar = .current) -> MonthlySummary {
        let interval = monthInterval(containing: date, calendar: calendar)
        var summary = MonthlySummary(month: interval.start)

        let start = interval.start
        let end = interval.end

        // Income received this month
        let incomeDescriptor = FetchDescriptor<IncomeEntry>(
            predicate: #Predicate { $0.dateReceived >= start && $0.dateReceived <= end }
        )
        let entries = (try? context.fetch(incomeDescriptor)) ?? []
        summary.income = entries.reduce(Decimal.zero) { $0 + $1.amount }

        // Expenses this month
        let expenseDescriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= start && $0.date <= end }
        )
        let expenses = (try? context.fetch(expenseDescriptor)) ?? []
        summary.expenses = expenses.reduce(Decimal.zero) { $0 + $1.amount }

        // Per-category totals (categories with spending or a budget)
        let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
        var totals: [CategoryTotal] = []
        for category in categories.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let total = expenses
                .filter { $0.category?.uuid == category.uuid }
                .reduce(Decimal.zero) { $0 + $1.amount }
            if total > 0 || category.monthlyBudget != nil {
                totals.append(CategoryTotal(
                    id: category.uuid,
                    name: category.name,
                    symbolName: category.symbolName,
                    colorHex: category.colorHex,
                    total: total,
                    budget: category.monthlyBudget
                ))
            }
        }
        let uncategorized = expenses
            .filter { $0.category == nil }
            .reduce(Decimal.zero) { $0 + $1.amount }
        if uncategorized > 0 {
            totals.append(CategoryTotal(
                id: UUID(),
                name: String(localized: "Uncategorized"),
                symbolName: "questionmark.circle",
                colorHex: "#9CA3AF",
                total: uncategorized,
                budget: nil
            ))
        }
        summary.categoryTotals = totals.sorted { $0.total > $1.total }

        // Biggest expenses
        summary.biggestExpenses = expenses
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { expense in
                MonthlySummary.ExpenseSnapshot(
                    id: expense.uuid,
                    amount: expense.amount,
                    date: expense.date,
                    note: expense.note,
                    categoryName: expense.category?.name
                )
            }

        return summary
    }

    /// Income vs. expense totals for the last `count` months, oldest first.
    /// Feeds the Swift Charts trend view.
    static func monthlyTrend(monthsBack count: Int, context: ModelContext, calendar: Calendar = .current) -> [MonthlySummary] {
        (0..<count).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: .now) else { return nil }
            return summary(forMonthContaining: month, context: context, calendar: calendar)
        }
    }

    /// Debt totals for the overview: "How much do I owe? How much is owed to me?"
    static func debtTotals(context: ModelContext) -> (iOwe: Decimal, owedToMe: Decimal) {
        let descriptor = FetchDescriptor<Debt>(predicate: #Predicate { !$0.isSettled })
        let debts = (try? context.fetch(descriptor)) ?? []
        var iOwe = Decimal.zero
        var owedToMe = Decimal.zero
        for debt in debts {
            switch debt.direction {
            case .iOwe: iOwe += debt.remaining
            case .owedToMe: owedToMe += debt.remaining
            }
        }
        // Open loans count toward what the owner owes.
        let loanDescriptor = FetchDescriptor<Loan>(predicate: #Predicate { !$0.isClosed })
        let loans = (try? context.fetch(loanDescriptor)) ?? []
        iOwe += loans.reduce(Decimal.zero) { $0 + $1.remainingBalance }
        return (iOwe, owedToMe)
    }
}
