//
//  NotificationScheduler.swift
//  LifeHub
//
//  Reminders are the heart of the app. This scheduler recomputes all pending
//  local notifications from the database — paydays, rent, bills, debts,
//  loans, events, tasks, anniversaries, and the monthly review — every time
//  the data changes, staying within iOS's 64-pending-notification budget.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationScheduler {
    // MARK: Categories & actions

    enum Category: String {
        case payday = "LIFEHUB_PAYDAY"
        case bill = "LIFEHUB_BILL"
        case loan = "LIFEHUB_LOAN"
        case debt = "LIFEHUB_DEBT"
        case event = "LIFEHUB_EVENT"
        case task = "LIFEHUB_TASK"
        case info = "LIFEHUB_INFO"
    }

    enum Action: String {
        case confirmPayday = "CONFIRM_PAYDAY"
        case markPaid = "MARK_PAID"
        case markDone = "MARK_DONE"
        case snoozeHour = "SNOOZE_HOUR"
    }

    /// How far ahead notifications are materialized.
    private static let horizonDays = 35
    /// Stay under iOS's 64 pending-notification limit.
    private static let budget = 60

    // MARK: Setup

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        registerCategories(center)
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func registerCategories(_ center: UNUserNotificationCenter = .current()) {
        let snooze = UNNotificationAction(
            identifier: Action.snoozeHour.rawValue,
            title: String(localized: "Snooze 1 Hour")
        )
        let confirm = UNNotificationAction(
            identifier: Action.confirmPayday.rawValue,
            title: String(localized: "Money Arrived ✓")
        )
        let markPaid = UNNotificationAction(
            identifier: Action.markPaid.rawValue,
            title: String(localized: "Mark Paid")
        )
        let markDone = UNNotificationAction(
            identifier: Action.markDone.rawValue,
            title: String(localized: "Mark Done")
        )

        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.payday.rawValue, actions: [confirm, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.bill.rawValue, actions: [markPaid, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.loan.rawValue, actions: [markPaid, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.debt.rawValue, actions: [snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.event.rawValue, actions: [snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.task.rawValue, actions: [markDone, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.info.rawValue, actions: [], intentIdentifiers: [])
        ])
    }

    // MARK: Refresh

    /// One pending notification, before scheduling.
    private struct Candidate {
        let fireDate: Date
        let title: String
        let body: String
        let category: Category
        let recordUUID: UUID?
        let occurrenceDate: Date
    }

    /// Rebuilds every pending notification from the current database state.
    static func refreshAll(context: ModelContext, calendar: Calendar = .current) {
        let settings = AppSettings.fetchOrCreate(in: context)
        let now = Date.now
        guard let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now) else { return }
        let window = DateInterval(start: now, end: horizon)

        var candidates: [Candidate] = []
        candidates += paydayCandidates(context: context, settings: settings, window: window, calendar: calendar)
        candidates += billCandidates(context: context, settings: settings, window: window, calendar: calendar)
        candidates += debtCandidates(context: context, settings: settings, window: window, calendar: calendar)
        candidates += loanCandidates(context: context, settings: settings, window: window, calendar: calendar)
        candidates += eventCandidates(context: context, window: window, calendar: calendar)
        candidates += taskCandidates(context: context, settings: settings, window: window, calendar: calendar)
        candidates += anniversaryCandidates(context: context, settings: settings, window: window, calendar: calendar)
        candidates += monthlyReviewCandidates(settings: settings, window: window, calendar: calendar)

        let scheduled = candidates
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(budget)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for candidate in scheduled {
            let content = UNMutableNotificationContent()
            content.title = candidate.title
            content.body = candidate.body
            content.sound = .default
            content.categoryIdentifier = candidate.category.rawValue
            content.interruptionLevel = .timeSensitive
            var userInfo: [String: Any] = [
                "category": candidate.category.rawValue,
                "occurrence": candidate.occurrenceDate.timeIntervalSince1970
            ]
            if let uuid = candidate.recordUUID {
                userInfo["uuid"] = uuid.uuidString
            }
            content.userInfo = userInfo

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(candidate.category.rawValue)|\(candidate.recordUUID?.uuidString ?? "-")|\(Int(candidate.fireDate.timeIntervalSince1970))"
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    // MARK: Candidate builders

    private static func at(hour: Int, on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: calendar.startOfDay(for: day)) ?? day
    }

    private static func paydayCandidates(context: ModelContext, settings: AppSettings, window: DateInterval, calendar: Calendar) -> [Candidate] {
        guard let sources = try? context.fetch(FetchDescriptor<IncomeSource>()) else { return [] }
        var results: [Candidate] = []
        for source in sources where source.isActive {
            for payday in source.paydays(in: window, calendar: calendar) {
                results.append(Candidate(
                    fireDate: at(hour: settings.reminderHour, on: payday, calendar: calendar),
                    title: String(localized: "Payday — \(source.name)"),
                    body: String(localized: "\(MoneyFormat.string(source.amount, code: settings.currencyCode)) expected today. Did the money arrive?"),
                    category: .payday,
                    recordUUID: source.uuid,
                    occurrenceDate: payday
                ))
            }
        }
        return results
    }

    private static func billCandidates(context: ModelContext, settings: AppSettings, window: DateInterval, calendar: Calendar) -> [Candidate] {
        guard let bills = try? context.fetch(FetchDescriptor<RecurringBill>()) else { return [] }
        var results: [Candidate] = []
        for bill in bills where bill.isActive {
            for due in bill.dueDates(in: window, calendar: calendar) {
                if bill.isPaid(forPeriodContaining: due, calendar: calendar) { continue }
                let amountText = MoneyFormat.string(bill.amount, code: settings.currencyCode)
                let name = bill.isRent && !bill.payee.isEmpty ? "\(bill.name) (\(bill.payee))" : bill.name

                // Early warning
                if bill.remindBeforeDays > 0,
                   let early = calendar.date(byAdding: .day, value: -bill.remindBeforeDays, to: due) {
                    results.append(Candidate(
                        fireDate: at(hour: settings.reminderHour, on: early, calendar: calendar),
                        title: bill.isRent
                            ? String(localized: "Rent due in \(bill.remindBeforeDays) days")
                            : String(localized: "\(bill.name) due in \(bill.remindBeforeDays) days"),
                        body: String(localized: "\(name) — \(amountText)"),
                        category: .bill,
                        recordUUID: bill.uuid,
                        occurrenceDate: due
                    ))
                }
                // Day-of
                results.append(Candidate(
                    fireDate: at(hour: settings.reminderHour, on: due, calendar: calendar),
                    title: bill.isRent ? String(localized: "Rent is due today") : String(localized: "\(bill.name) is due today"),
                    body: String(localized: "\(name) — \(amountText)"),
                    category: .bill,
                    recordUUID: bill.uuid,
                    occurrenceDate: due
                ))
            }
        }
        return results
    }

    private static func debtCandidates(context: ModelContext, settings: AppSettings, window: DateInterval, calendar: Calendar) -> [Candidate] {
        let descriptor = FetchDescriptor<Debt>(predicate: #Predicate { !$0.isSettled })
        guard let debts = try? context.fetch(descriptor) else { return [] }
        var results: [Candidate] = []
        for debt in debts {
            guard let due = debt.dueDate, debt.remaining > 0 else { continue }
            let amountText = MoneyFormat.string(debt.remaining, code: settings.currencyCode)
            let title = debt.direction == .iOwe
                ? String(localized: "Debt to \(debt.person)")
                : String(localized: "\(debt.person) owes you")
            if let early = calendar.date(byAdding: .day, value: -settings.debtRemindBeforeDays, to: due),
               window.contains(at(hour: settings.reminderHour, on: early, calendar: calendar)) {
                results.append(Candidate(
                    fireDate: at(hour: settings.reminderHour, on: early, calendar: calendar),
                    title: title,
                    body: String(localized: "\(amountText) due in \(settings.debtRemindBeforeDays) days."),
                    category: .debt,
                    recordUUID: debt.uuid,
                    occurrenceDate: due
                ))
            }
            if window.contains(at(hour: settings.reminderHour, on: due, calendar: calendar)) {
                results.append(Candidate(
                    fireDate: at(hour: settings.reminderHour, on: due, calendar: calendar),
                    title: title,
                    body: String(localized: "\(amountText) is due today."),
                    category: .debt,
                    recordUUID: debt.uuid,
                    occurrenceDate: due
                ))
            }
        }
        return results
    }

    private static func loanCandidates(context: ModelContext, settings: AppSettings, window: DateInterval, calendar: Calendar) -> [Candidate] {
        let descriptor = FetchDescriptor<Loan>(predicate: #Predicate { !$0.isClosed })
        guard let loans = try? context.fetch(descriptor) else { return [] }
        var results: [Candidate] = []
        for loan in loans {
            for due in loan.dueDates(in: window, calendar: calendar) {
                let amountText = MoneyFormat.string(loan.installmentAmount, code: settings.currencyCode)
                if let early = calendar.date(byAdding: .day, value: -settings.loanRemindBeforeDays, to: due) {
                    results.append(Candidate(
                        fireDate: at(hour: settings.reminderHour, on: early, calendar: calendar),
                        title: String(localized: "Loan installment — \(loan.lender)"),
                        body: String(localized: "\(amountText) due in \(settings.loanRemindBeforeDays) days."),
                        category: .loan,
                        recordUUID: loan.uuid,
                        occurrenceDate: due
                    ))
                }
                results.append(Candidate(
                    fireDate: at(hour: settings.reminderHour, on: due, calendar: calendar),
                    title: String(localized: "Loan installment — \(loan.lender)"),
                    body: String(localized: "\(amountText) is due today."),
                    category: .loan,
                    recordUUID: loan.uuid,
                    occurrenceDate: due
                ))
            }
        }
        return results
    }

    private static func eventCandidates(context: ModelContext, window: DateInterval, calendar: Calendar) -> [Candidate] {
        guard let events = try? context.fetch(FetchDescriptor<CalendarEvent>()) else { return [] }
        var results: [Candidate] = []
        for event in events {
            for occurrence in event.occurrences(in: window, calendar: calendar) {
                for minutes in event.reminderMinutesBefore {
                    let fireDate = occurrence.addingTimeInterval(TimeInterval(-minutes * 60))
                    let body = minutes == 0
                        ? String(localized: "Starting now.")
                        : String(localized: "Starts in \(minutes) minutes.")
                    results.append(Candidate(
                        fireDate: fireDate,
                        title: event.title,
                        body: event.location.isEmpty ? body : "\(body) \(event.location)",
                        category: .event,
                        recordUUID: event.uuid,
                        occurrenceDate: occurrence
                    ))
                }
            }
        }
        return results
    }

    private static func taskCandidates(context: ModelContext, settings: AppSettings, window: DateInterval, calendar: Calendar) -> [Candidate] {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isCompleted })
        guard let tasks = try? context.fetch(descriptor) else { return [] }
        var results: [Candidate] = []
        for task in tasks {
            guard let due = task.dueDate, window.contains(due) || window.contains(at(hour: settings.reminderHour, on: due, calendar: calendar)) else { continue }
            let fireDate = task.hasDueTime ? due : at(hour: settings.reminderHour, on: due, calendar: calendar)
            results.append(Candidate(
                fireDate: fireDate,
                title: String(localized: "Task due: \(task.title)"),
                body: task.group.map { String(localized: "In \($0.name).") } ?? String(localized: "Due today."),
                category: .task,
                recordUUID: task.uuid,
                occurrenceDate: due
            ))
        }
        return results
    }

    private static func anniversaryCandidates(context: ModelContext, settings: AppSettings, window: DateInterval, calendar: Calendar) -> [Candidate] {
        guard settings.anniversaryRemindersEnabled,
              let sources = try? context.fetch(FetchDescriptor<IncomeSource>()) else { return [] }
        var results: [Candidate] = []
        for source in sources {
            guard let anniversary = source.nextAnniversary(after: window.start, calendar: calendar),
                  window.contains(anniversary.date) else { continue }
            results.append(Candidate(
                fireDate: anniversary.date,
                title: String(localized: "Work anniversary 🎉"),
                body: String(localized: "\(anniversary.years) years at \(source.name) today!"),
                category: .info,
                recordUUID: source.uuid,
                occurrenceDate: anniversary.date
            ))
        }
        return results
    }

    private static func monthlyReviewCandidates(settings: AppSettings, window: DateInterval, calendar: Calendar) -> [Candidate] {
        guard settings.monthlyReviewEnabled else { return [] }
        var results: [Candidate] = []
        var cursor = window.start
        for _ in 0..<2 {
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: cursor)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else { break }
            let fireDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: lastDay) ?? lastDay
            if window.contains(fireDate) {
                results.append(Candidate(
                    fireDate: fireDate,
                    title: String(localized: "Monthly review is ready"),
                    body: String(localized: "See this month's income, spending, and savings."),
                    category: .info,
                    recordUUID: nil,
                    occurrenceDate: fireDate
                ))
            }
            cursor = nextMonth
        }
        return results
    }
}
