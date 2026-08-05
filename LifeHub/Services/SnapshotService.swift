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
        applyPendingWidgetActions(context: context)

        let settings = AppSettings.fetchOrCreate(in: context)
        var snapshot = WidgetSnapshot()
        snapshot.currencyCode = settings.currencyCode
        snapshot.generatedAt = .now

        // Month money (buckets carry every currency, exactly as entered)
        let summary = StatsService.summary(forMonthContaining: .now, context: context, calendar: calendar)
        snapshot.monthIncome = summary.income
        snapshot.monthIncomeByCurrency = summary.incomeByCurrency
        snapshot.monthExpenses = summary.expenses

        // Debts
        let debtTotals = StatsService.debtTotals(context: context)
        snapshot.iOweByCurrency = debtTotals.iOwe
        snapshot.owedToMeByCurrency = debtTotals.owedToMe
        snapshot.totalIOwe = debtTotals.iOwe[settings.currencyCode] ?? 0
        snapshot.totalOwedToMe = debtTotals.owedToMe[settings.currencyCode] ?? 0

        // Next payday across active sources
        let sources = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
        let nextPaydays: [(IncomeSource, Date)] = sources.compactMap { source in
            guard let next = source.nextPayday(calendar: calendar) else { return nil }
            return (source, next)
        }
        if let (source, date) = nextPaydays.min(by: { $0.1 < $1.1 }) {
            snapshot.nextPayday = .init(
                sourceName: source.name,
                amount: source.amount,
                date: date,
                currencyCode: source.currencyCode
            )
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

        // Open tasks (count + list for the Tasks widget)
        let openDescriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isCompleted })
        let openTasks = (try? context.fetch(openDescriptor)) ?? []
        snapshot.openTaskCount = openTasks.count
        snapshot.openTasks = openTasks
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.priority.sortRank < rhs.priority.sortRank
                }
            }
            .prefix(6)
            .map { task in
                WidgetSnapshot.TaskLine(
                    id: task.uuid.uuidString,
                    title: task.title,
                    due: task.dueDate,
                    overdue: task.isOverdue
                )
            }

        // Recent notes (pinned first, then most recently updated)
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        snapshot.recentNotes = notes
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
            .prefix(4)
            .map { note in
                let title = note.title.isEmpty ? String(note.body.prefix(40)) : note.title
                let snippet = note.title.isEmpty ? "" : String(note.body.prefix(60))
                return WidgetSnapshot.NoteLine(
                    id: note.uuid.uuidString,
                    title: title.isEmpty ? String(localized: "Untitled") : title,
                    snippet: snippet,
                    pinned: note.isPinned
                )
            }

        // Projects (progress)
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        snapshot.activeProjectCount = projects.filter { $0.status != .archived }.count
        snapshot.projects = projects
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map { project in
                WidgetSnapshot.ProjectLine(
                    id: project.uuid.uuidString,
                    name: project.name,
                    status: project.status.rawValue.capitalized,
                    progress: project.progress
                )
            }

        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Completes any tasks that were checked off from an interactive widget
    /// while the app was closed, then clears the pending queue.
    private static func applyPendingWidgetActions(context: ModelContext) {
        let defaults = AppGroup.defaults
        let ids = defaults.stringArray(forKey: AppGroup.pendingCompletedTasksKey) ?? []
        guard !ids.isEmpty else { return }
        for idString in ids {
            guard let uuid = UUID(uuidString: idString) else { continue }
            var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == uuid })
            descriptor.fetchLimit = 1
            if let task = try? context.fetch(descriptor).first, !task.isCompleted {
                task.complete()
            }
        }
        defaults.removeObject(forKey: AppGroup.pendingCompletedTasksKey)
        try? context.save()
    }
}
