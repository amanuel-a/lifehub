//
//  IncomeSource.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A source of income: a job, side work, freelance client, or business.
/// Each source has its own pay schedule and, for jobs, a start date used to
/// compute tenure and a salary-change history.
@Model
final class IncomeSource {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var typeRaw: String
    var amount: Decimal
    var frequencyRaw: String

    /// Weekly / bi-weekly: the payday weekday (Calendar weekday, 1 = Sunday).
    var paydayWeekday: Int?
    /// Bi-weekly: a known past payday used as the anchor for the 14-day cycle.
    var biweeklyAnchor: Date?
    /// Monthly: the day of the month pay arrives (1...31, clamped to month length).
    var paydayDayOfMonth: Int?

    /// The date the owner started at this company / client.
    var startDate: Date?
    /// Set when the owner leaves; a nil end date means this is a current source.
    var endDate: Date?

    var note: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SalaryChange.source)
    var salaryChanges: [SalaryChange] = []

    @Relationship(deleteRule: .cascade, inverse: \IncomeEntry.source)
    var entries: [IncomeEntry] = []

    init(
        name: String,
        type: IncomeType = .salary,
        amount: Decimal = 0,
        frequency: PayFrequency = .monthly,
        paydayWeekday: Int? = nil,
        biweeklyAnchor: Date? = nil,
        paydayDayOfMonth: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        note: String = ""
    ) {
        self.uuid = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.amount = amount
        self.frequencyRaw = frequency.rawValue
        self.paydayWeekday = paydayWeekday
        self.biweeklyAnchor = biweeklyAnchor
        self.paydayDayOfMonth = paydayDayOfMonth
        self.startDate = startDate
        self.endDate = endDate
        self.note = note
        self.createdAt = .now
    }

    // MARK: Typed accessors

    var type: IncomeType {
        get { IncomeType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var frequency: PayFrequency {
        get { PayFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    /// A source with no end date is still paying.
    var isActive: Bool { endDate == nil }

    // MARK: Salary history

    /// Salary changes sorted oldest → newest.
    var sortedSalaryChanges: [SalaryChange] {
        salaryChanges.sorted { $0.effectiveDate < $1.effectiveDate }
    }

    /// The amount effective on a given date, walking the salary history.
    func amount(on date: Date) -> Decimal {
        let history = sortedSalaryChanges.filter { $0.effectiveDate <= date }
        return history.last?.amount ?? sortedSalaryChanges.first?.amount ?? amount
    }

    /// Records a new salary with an effective date and makes it current.
    func recordSalaryChange(amount newAmount: Decimal, effectiveDate: Date, note: String = "") {
        let change = SalaryChange(amount: newAmount, effectiveDate: effectiveDate, note: note)
        change.source = self
        salaryChanges.append(change)
        if effectiveDate <= .now { amount = newAmount }
    }

    // MARK: Payday schedule

    /// The next payday strictly after `date` (default: now).
    func nextPayday(after date: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isActive else { return nil }
        return PaydayCalculator.nextPayday(
            frequency: frequency,
            weekday: paydayWeekday,
            biweeklyAnchor: biweeklyAnchor,
            dayOfMonth: paydayDayOfMonth,
            after: date,
            calendar: calendar
        )
    }

    /// All paydays inside `range`.
    func paydays(in range: DateInterval, calendar: Calendar = .current) -> [Date] {
        guard isActive else { return [] }
        return PaydayCalculator.paydays(
            frequency: frequency,
            weekday: paydayWeekday,
            biweeklyAnchor: biweeklyAnchor,
            dayOfMonth: paydayDayOfMonth,
            in: range,
            calendar: calendar
        )
    }

    // MARK: Tenure

    /// How long the owner has worked at this source, e.g. "1 year, 4 months".
    /// Uses the end date for past jobs and today for current ones.
    var tenureDescription: String? {
        guard let startDate else { return nil }
        return TenureFormatter.string(from: startDate, to: endDate ?? .now)
    }

    /// The next yearly work anniversary (for the "2 years at Kayo!" reminder).
    func nextAnniversary(after date: Date = .now, calendar: Calendar = .current) -> (date: Date, years: Int)? {
        guard let startDate, isActive else { return nil }
        var comps = calendar.dateComponents([.month, .day], from: startDate)
        comps.hour = 9
        guard let next = calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) else {
            return nil
        }
        let years = calendar.dateComponents([.year], from: startDate, to: next).year ?? 0
        return years >= 1 ? (next, years) : nil
    }
}

/// One entry in a source's salary history.
@Model
final class SalaryChange {
    @Attribute(.unique) var uuid: UUID
    var amount: Decimal
    var effectiveDate: Date
    var note: String
    var source: IncomeSource?

    init(amount: Decimal, effectiveDate: Date, note: String = "") {
        self.uuid = UUID()
        self.amount = amount
        self.effectiveDate = effectiveDate
        self.note = note
    }
}
