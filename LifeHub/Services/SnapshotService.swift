//
//  SnapshotService.swift
//  LifeHub
//

import Foundation
import SwiftData
import WidgetKit

/// Recomputes the widget snapshot after every meaningful data change and
/// asks WidgetKit to reload timelines.
@MainActor
enum SnapshotService {
    static func refresh(context: ModelContext, calendar: Calendar = .current) {
        let settings = AppSettings.fetchOrCreate(in: context)
        var snapshot = WidgetSnapshot()
        snapshot.currencyCode = settings.currencyCode
        snapshot.generatedAt = .now

        // Month money
        let summary = StatsService.summary(forMonthContaining: .now, context: context, calendar: calendar)
        snapshot.monthIncome = summary.income
        snapshot.monthExpenses = summary.expenses

        // Debts
        let debtTotals = StatsService.debtTotals(context: context)
        snapshot.totalIOwe = debtTotals.iOwe
        snapshot.totalOwedToMe = debtTotals.owedToMe

        // Next payday across active sources
        let sources = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
        let nextPaydays: [(IncomeSource, Date)] = sources.compactMap { source in
            guard let next = source.nextPayday(calendar: calendar) else { return nil }
            return (source, next)
        }
        if let (source, date) = nextPaydays.min(by: { $0.1 < $1.1 }) {
            snapshot.nextPayday = .init(sourceName: source.name, amount: source.amount, date: date)
        }

        // Next rent / bill
        let bills = (try? context.fetch(FetchDescriptor<RecurringBill>())) ?? []
        let rentDues: [(RecurringBill, Date)] = bills.filter(\.isRent).compactMap { bill in
            guard let next = bill.nextDueDate(calendar: calendar) else { return nil }
            return (bill, next)
        }
        if let (bill, date) = rentDues.min(by: { $0.1 < $1.1 }) {
            snapshot.nextRent = .init(title: bill.name, amount: bill.amount, date: date)
        }
        let otherDues: [(RecurringBill, Date)] = bills.filter { !$0.isRent }.compactMap { bill in
            guard let next = bill.nextDueDate(calendar: calendar) else { return nil }
            return (bill, next)
        }
        if let (bill, date) = otherDues.min(by: { $0.1 < $1.1 }) {
            snapshot.nextBill = .init(title: bill.name, amount: bill.amount, date: date)
        }

        // Next loan installment
        let loans = (try? context.fetch(FetchDescriptor<Loan>(predicate: #Predicate { !$0.isClosed }))) ?? []
        if let loan = loans.min(by: { $0.nextDueDate < $1.nextDueDate }) {
            snapshot.nextLoanInstallment = .init(title: loan.lender, amount: loan.installmentAmount, date: loan.nextDueDate)
        }

        // Today's agenda lines
        let today = AgendaService.items(on: .now, context: context, calendar: calendar)
        snapshot.todayLines = today.prefix(6).map { item in
            WidgetSnapshot.AgendaLine(
                title: item.title,
                time: item.hasTime ? item.date : nil,
                symbolName: item.kind.symbolName
            )
        }

        // Open task count
        let openTasks = (try? context.fetchCount(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isCompleted }))) ?? 0
        snapshot.openTaskCount = openTasks

        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
