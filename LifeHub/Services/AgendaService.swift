//
//  AgendaService.swift
//  LifeHub
//

import Foundation
import SwiftData
import SwiftUI

/// The kind of item appearing on the unified calendar / today list.
/// Everything is color-coded by type, per the requirements.
enum AgendaKind: String, CaseIterable, Identifiable, Sendable {
    case event
    case task
    case payday
    case rent
    case bill
    case debt
    case loan

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .event: "Event"
        case .task: "Task"
        case .payday: "Payday"
        case .rent: "Rent"
        case .bill: "Bill"
        case .debt: "Debt"
        case .loan: "Loan"
        }
    }

    var symbolName: String {
        switch self {
        case .event: "calendar"
        case .task: "checkmark.circle.fill"
        case .payday: "banknote.fill"
        case .rent: "house.fill"
        case .bill: "doc.text.fill"
        case .debt: "person.2.fill"
        case .loan: "building.columns.fill"
        }
    }

    var tint: Color {
        switch self {
        case .event: .blue
        case .task: .indigo
        case .payday: .green
        case .rent: .orange
        case .bill: .yellow
        case .debt: .pink
        case .loan: .purple
        }
    }
}

/// One row on the calendar, dashboard, or Today / Upcoming list.
struct AgendaItem: Identifiable, Hashable, Sendable {
    let id: String
    let kind: AgendaKind
    let date: Date
    /// Whether `date`'s time component is meaningful (events with times).
    let hasTime: Bool
    let title: String
    let subtitle: String?
    let amount: Decimal?
    /// UUID of the underlying record, for actions like "mark paid".
    let recordUUID: UUID?
}

/// Builds the unified agenda — events, task deadlines, paydays, rent day,
/// bill due dates, and debt/loan due dates — for any date range.
@MainActor
enum AgendaService {
    static func items(in range: DateInterval, context: ModelContext, calendar: Calendar = .current) -> [AgendaItem] {
        var items: [AgendaItem] = []

        // Events (with repeat expansion)
        if let events = try? context.fetch(FetchDescriptor<CalendarEvent>()) {
            for event in events {
                for occurrence in event.occurrences(in: range, calendar: calendar) {
                    items.append(AgendaItem(
                        id: "event-\(event.uuid)-\(occurrence.timeIntervalSince1970)",
                        kind: .event,
                        date: occurrence,
                        hasTime: !event.isAllDay,
                        title: event.title,
                        subtitle: event.location.isEmpty ? nil : event.location,
                        amount: nil,
                        recordUUID: event.uuid
                    ))
                }
            }
        }

        // Task deadlines (open tasks only)
        let openTasks = FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isCompleted })
        if let tasks = try? context.fetch(openTasks) {
            for task in tasks {
                guard let due = task.dueDate, range.contains(due) else { continue }
                items.append(AgendaItem(
                    id: "task-\(task.uuid)",
                    kind: .task,
                    date: due,
                    hasTime: task.hasDueTime,
                    title: task.title,
                    subtitle: task.group?.name,
                    amount: nil,
                    recordUUID: task.uuid
                ))
            }
        }

        // Paydays per income source
        if let sources = try? context.fetch(FetchDescriptor<IncomeSource>()) {
            for source in sources where source.isActive {
                for payday in source.paydays(in: range, calendar: calendar) {
                    items.append(AgendaItem(
                        id: "payday-\(source.uuid)-\(payday.timeIntervalSince1970)",
                        kind: .payday,
                        date: payday,
                        hasTime: false,
                        title: source.name,
                        subtitle: nil,
                        amount: source.amount,
                        recordUUID: source.uuid
                    ))
                }
            }
        }

        // Rent and bills
        if let bills = try? context.fetch(FetchDescriptor<RecurringBill>()) {
            for bill in bills where bill.isActive {
                for due in bill.dueDates(in: range, calendar: calendar) {
                    items.append(AgendaItem(
                        id: "bill-\(bill.uuid)-\(due.timeIntervalSince1970)",
                        kind: bill.isRent ? .rent : .bill,
                        date: due,
                        hasTime: false,
                        title: bill.name,
                        subtitle: bill.payee.isEmpty ? nil : bill.payee,
                        amount: bill.amount,
                        recordUUID: bill.uuid
                    ))
                }
            }
        }

        // Debt due dates (unsettled only)
        let openDebts = FetchDescriptor<Debt>(predicate: #Predicate { !$0.isSettled })
        if let debts = try? context.fetch(openDebts) {
            for debt in debts {
                guard let due = debt.dueDate, range.contains(due), debt.remaining > 0 else { continue }
                items.append(AgendaItem(
                    id: "debt-\(debt.uuid)",
                    kind: .debt,
                    date: due,
                    hasTime: false,
                    title: debt.person,
                    subtitle: nil,
                    amount: debt.remaining,
                    recordUUID: debt.uuid
                ))
            }
        }

        // Loan installments
        let openLoans = FetchDescriptor<Loan>(predicate: #Predicate { !$0.isClosed })
        if let loans = try? context.fetch(openLoans) {
            for loan in loans {
                for due in loan.dueDates(in: range, calendar: calendar) {
                    items.append(AgendaItem(
                        id: "loan-\(loan.uuid)-\(due.timeIntervalSince1970)",
                        kind: .loan,
                        date: due,
                        hasTime: false,
                        title: loan.lender,
                        subtitle: nil,
                        amount: loan.installmentAmount,
                        recordUUID: loan.uuid
                    ))
                }
            }
        }

        return items.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.title < rhs.title
        }
    }

    /// Items for a single day.
    static func items(on day: Date, context: ModelContext, calendar: Calendar = .current) -> [AgendaItem] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return items(in: DateInterval(start: start, end: end.addingTimeInterval(-1)), context: context, calendar: calendar)
    }
}
