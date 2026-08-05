//
//  SharedTypes.swift
//  LifeHub
//
//  Shared enums and value types used across the data model.
//

import Foundation
import SwiftUI

// MARK: - Income

/// The kind of income an `IncomeSource` represents.
enum IncomeType: String, Codable, CaseIterable, Identifiable, Sendable {
    case salary
    case sideWork
    case freelance
    case business
    case other

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .salary: "Salary"
        case .sideWork: "Side Work"
        case .freelance: "Freelance"
        case .business: "Business"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .salary: "building.2.fill"
        case .sideWork: "hammer.fill"
        case .freelance: "laptopcomputer"
        case .business: "storefront.fill"
        case .other: "banknote.fill"
        }
    }
}

/// How often an income source pays out.
enum PayFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Bi-weekly"
        case .monthly: "Monthly"
        }
    }
}

// MARK: - Bills & Loans

/// How often a recurring bill repeats.
enum BillFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Every 3 Months"
        case .yearly: "Yearly"
        }
    }

    /// Calendar components to add to advance from one billing period to the next.
    var dateComponents: DateComponents {
        switch self {
        case .weekly: DateComponents(day: 7)
        case .monthly: DateComponents(month: 1)
        case .quarterly: DateComponents(month: 3)
        case .yearly: DateComponents(year: 1)
        }
    }

    /// Noun for one billing period, used in "3 months" style labels.
    var periodNoun: String {
        switch self {
        case .weekly: String(localized: "weeks")
        case .monthly: String(localized: "months")
        case .quarterly: String(localized: "quarters")
        case .yearly: String(localized: "years")
        }
    }
}

/// How often a loan installment is due.
enum LoanFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Bi-weekly"
        case .monthly: "Monthly"
        }
    }

    /// Calendar components to add to advance from one due date to the next.
    var dateComponents: DateComponents {
        switch self {
        case .weekly: DateComponents(day: 7)
        case .biweekly: DateComponents(day: 14)
        case .monthly: DateComponents(month: 1)
        }
    }
}

// MARK: - Debts

/// Whether the owner owes money or is owed money.
enum DebtDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case iOwe
    case owedToMe

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .iOwe: "I Owe"
        case .owedToMe: "Owed to Me"
        }
    }
}

// MARK: - Tasks

enum TaskPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case high
    case normal
    case low

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .high: "High"
        case .normal: "Normal"
        case .low: "Low"
        }
    }

    var sortRank: Int {
        switch self {
        case .high: 0
        case .normal: 1
        case .low: 2
        }
    }

    var tint: Color {
        switch self {
        case .high: .red
        case .normal: .blue
        case .low: .gray
        }
    }
}

// MARK: - Repeat rules

/// A flexible repeat rule shared by events and tasks.
/// Supports the "richer recurring rules" of Phase 2: intervals ("every 2 weeks")
/// and specific weekdays ("every Mon/Wed/Fri").
struct RepeatRule: Codable, Hashable, Sendable {
    enum Frequency: String, Codable, CaseIterable, Identifiable, Sendable {
        case never
        case daily
        case weekly
        case monthly
        case yearly

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .never: "Never"
            case .daily: "Daily"
            case .weekly: "Weekly"
            case .monthly: "Monthly"
            case .yearly: "Yearly"
            }
        }
    }

    var frequency: Frequency = .never
    /// Every `interval` days / weeks / months / years. Minimum 1.
    var interval: Int = 1
    /// For weekly rules: specific weekdays (Calendar weekday numbers, 1 = Sunday).
    /// Empty means "same weekday as the start date".
    var weekdays: Set<Int> = []

    static let never = RepeatRule(frequency: .never)

    var repeats: Bool { frequency != .never }

    /// The next occurrence strictly after `date`, anchored to `start`.
    func nextOccurrence(after date: Date, anchoredTo start: Date, calendar: Calendar = .current) -> Date? {
        guard repeats else { return nil }
        let step = max(1, interval)
        var candidate = start
        // Walk forward from the anchor. Bounded to avoid infinite loops on
        // pathological data (~10 years of daily occurrences).
        for _ in 0..<4000 {
            if candidate > date { return candidate }
            switch frequency {
            case .never:
                return nil
            case .daily:
                candidate = calendar.date(byAdding: .day, value: step, to: candidate) ?? candidate.addingTimeInterval(86_400)
            case .weekly:
                if weekdays.isEmpty {
                    candidate = calendar.date(byAdding: .day, value: 7 * step, to: candidate) ?? candidate
                } else {
                    // Move day by day; skip days whose weekday is not selected.
                    var next = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                    for _ in 0..<(7 * step + 7) {
                        if weekdays.contains(calendar.component(.weekday, from: next)), next > date {
                            return next
                        }
                        next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
                    }
                    candidate = next
                }
            case .monthly:
                candidate = calendar.date(byAdding: .month, value: step, to: candidate) ?? candidate
            case .yearly:
                candidate = calendar.date(byAdding: .year, value: step, to: candidate) ?? candidate
            }
        }
        return nil
    }

    /// All occurrences that fall inside `interval`, anchored to `start`.
    func occurrences(in range: DateInterval, anchoredTo start: Date, calendar: Calendar = .current, limit: Int = 120) -> [Date] {
        guard repeats else {
            return range.contains(start) ? [start] : []
        }
        var results: [Date] = []
        if range.contains(start) { results.append(start) }
        var cursor = start
        while results.count < limit {
            guard let next = nextOccurrence(after: cursor, anchoredTo: start, calendar: calendar) else { break }
            if next > range.end { break }
            if next >= range.start { results.append(next) }
            cursor = next
        }
        return results
    }
}

// MARK: - Notes

/// One line of a note's checklist.
struct ChecklistItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var text: String = ""
    var isDone: Bool = false
}

/// A lightweight, type-safe link from a note to another record.
struct LinkedRecord: Codable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case task
        case event
        case debt
        case loan
        case incomeSource
        case bill

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .task: "Task"
            case .event: "Event"
            case .debt: "Debt"
            case .loan: "Loan"
            case .incomeSource: "Income Source"
            case .bill: "Bill"
            }
        }

        var symbolName: String {
            switch self {
            case .task: "checkmark.circle"
            case .event: "calendar"
            case .debt: "person.2"
            case .loan: "building.columns"
            case .incomeSource: "banknote"
            case .bill: "doc.text"
            }
        }
    }

    var kind: Kind
    var recordID: UUID
    /// Display label captured at link time so the chip renders without a fetch.
    var label: String
}
