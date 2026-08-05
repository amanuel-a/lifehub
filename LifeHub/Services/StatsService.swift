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
    /// Income grouped by currency code, amounts exactly as entered.
    var incomeByCurrency: [String: Decimal] = [:]
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

        // Income received this month, kept in each entry's own currency —
        // never converted. `income` carries the app-currency bucket; other
        // currencies ride along in `incomeByCurrency`.
        let settings = AppSettings.fetchOrCreate(in: context)
        let incomeDescriptor = FetchDescriptor<IncomeEntry>(
            predicate: #Predicate { $0.dateReceived >= start && $0.dateReceived <= end }
        )
        let entries = (try? context.fetch(incomeDescriptor)) ?? []
        for entry in entries {
            let code = entry.source?.currencyCode ?? settings.currencyCode
            summary.incomeByCurrency[code, default: .zero] += entry.amount
        }
        summary.income = summary.incomeByCurrency[settings.currencyCode] ?? 0

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
    /// Amounts stay in each debt's own currency — never converted — grouped
    /// into per-currency buckets ("ETB": 12,500, "USD": 100).
    static func debtTotals(context: ModelContext) -> (iOwe: [String: Decimal], owedToMe: [String: Decimal]) {
        let settings = AppSettings.fetchOrCreate(in: context)
        let descriptor = FetchDescriptor<Debt>(predicate: #Predicate { !$0.isSettled })
        let debts = (try? context.fetch(descriptor)) ?? []
        var iOwe: [String: Decimal] = [:]
        var owedToMe: [String: Decimal] = [:]
        for debt in debts {
            let code = debt.currencyCode ?? settings.currencyCode
            switch debt.direction {
            case .iOwe: iOwe[code, default: .zero] += debt.remaining
            case .owedToMe: owedToMe[code, default: .zero] += debt.remaining
            }
        }
        // Open loans count toward what the owner owes (app currency).
        let loanDescriptor = FetchDescriptor<Loan>(predicate: #Predicate { !$0.isClosed })
        let loans = (try? context.fetch(loanDescriptor)) ?? []
        let loanSum = loans.reduce(Decimal.zero) { $0 + $1.remainingBalance }
        if loanSum > 0 {
            iOwe[settings.currencyCode, default: .zero] += loanSum
        }
        return (iOwe, owedToMe)
    }

    /// Shared per-currency display logic (also used by the widgets, so the
    /// app cards and Home Screen always match).
    typealias TotalDisplay = MoneyFormat.TotalDisplay

    static func display(of totals: [String: Decimal], appCurrency: String) -> TotalDisplay {
        MoneyFormat.display(of: totals, appCurrency: appCurrency)
    }
}
