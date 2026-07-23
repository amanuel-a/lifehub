//
//  RecurringBill.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A recurring expense set up once: rent, subscriptions, utility bills.
/// Rent is a first-class bill (`isRent`) with a landlord and a payment history.
@Model
final class RecurringBill {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var amount: Decimal
    var frequencyRaw: String
    /// Monthly / quarterly / yearly: the due day of the month (1...31, clamped).
    var dueDay: Int
    /// Yearly: the due month (1...12). Ignored for other frequencies.
    var dueMonth: Int
    /// Weekly: the due weekday (Calendar weekday, 1 = Sunday).
    var dueWeekday: Int?
    /// Landlord for rent, or company for subscriptions/utilities.
    var payee: String
    /// Remind this many days before the due date (default 3 for rent, 1 for bills).
    var remindBeforeDays: Int
    var isRent: Bool
    var isActive: Bool
    var note: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Expense.bill)
    var payments: [Expense] = []

    init(
        name: String,
        amount: Decimal,
        frequency: BillFrequency = .monthly,
        dueDay: Int = 1,
        dueMonth: Int = 1,
        dueWeekday: Int? = nil,
        payee: String = "",
        remindBeforeDays: Int = 1,
        isRent: Bool = false,
        note: String = ""
    ) {
        self.uuid = UUID()
        self.name = name
        self.amount = amount
        self.frequencyRaw = frequency.rawValue
        self.dueDay = dueDay
        self.dueMonth = dueMonth
        self.dueWeekday = dueWeekday
        self.payee = payee
        self.remindBeforeDays = remindBeforeDays
        self.isRent = isRent
        self.isActive = true
        self.note = note
        self.createdAt = .now
    }

    var frequency: BillFrequency {
        get { BillFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Payments sorted newest first.
    var sortedPayments: [Expense] {
        payments.sorted { $0.date > $1.date }
    }

    /// The next due date strictly after `date`, skipping periods already paid.
    func nextDueDate(after date: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isActive else { return nil }
        var cursor = date
        // Skip up to 24 periods that are already marked paid.
        for _ in 0..<24 {
            guard let due = BillScheduler.nextDueDate(
                frequency: frequency,
                dueDay: dueDay,
                dueMonth: dueMonth,
                dueWeekday: dueWeekday,
                after: cursor,
                calendar: calendar
            ) else { return nil }
            if !isPaid(forPeriodContaining: due, calendar: calendar) { return due }
            cursor = due
        }
        return nil
    }

    /// All due dates inside `range` (ignores paid state; used by the calendar).
    func dueDates(in range: DateInterval, calendar: Calendar = .current) -> [Date] {
        guard isActive else { return [] }
        return BillScheduler.dueDates(
            frequency: frequency,
            dueDay: dueDay,
            dueMonth: dueMonth,
            dueWeekday: dueWeekday,
            in: range,
            calendar: calendar
        )
    }

    /// Whether a payment exists in the same period (week/month/quarter/year) as `dueDate`.
    func isPaid(forPeriodContaining dueDate: Date, calendar: Calendar = .current) -> Bool {
        switch frequency {
        case .weekly:
            return payments.contains { calendar.isDate($0.date, equalTo: dueDate, toGranularity: .weekOfYear) }
        case .monthly:
            return payments.contains { calendar.isDate($0.date, equalTo: dueDate, toGranularity: .month) }
        case .quarterly:
            // Foundation's `.quarter` component is unreliable; compare
            // (year, month/3) manually instead.
            func quarterKey(_ date: Date) -> (Int, Int) {
                let comps = calendar.dateComponents([.year, .month], from: date)
                return (comps.year ?? 0, ((comps.month ?? 1) - 1) / 3)
            }
            let target = quarterKey(dueDate)
            return payments.contains { quarterKey($0.date) == target }
        case .yearly:
            return payments.contains { calendar.isDate($0.date, equalTo: dueDate, toGranularity: .year) }
        }
    }

    /// Marks the current period as paid by creating a linked expense.
    /// Returns the created expense so callers can attach a category.
    @discardableResult
    func markPaid(on date: Date = .now, amount overrideAmount: Decimal? = nil, category: ExpenseCategory?) -> Expense {
        let expense = Expense(
            amount: overrideAmount ?? amount,
            date: date,
            note: isRent ? String(localized: "Rent — \(payee)") : name,
            category: category,
            bill: self
        )
        payments.append(expense)
        return expense
    }
}
