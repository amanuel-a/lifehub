//
//  BillScheduler.swift
//  LifeHub
//

import Foundation

/// Pure date math for recurring bill due dates.
enum BillScheduler {
    /// The next due date strictly after `date`.
    static func nextDueDate(
        frequency: BillFrequency,
        dueDay: Int,
        dueMonth: Int,
        dueWeekday: Int?,
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch frequency {
        case .weekly:
            var components = DateComponents()
            components.weekday = dueWeekday ?? 2 // Monday fallback
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
                .map(calendar.startOfDay(for:))

        case .monthly:
            var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            for _ in 0..<24 {
                if let candidate = PaydayCalculator.clampedDate(dayOfMonth: dueDay, inMonthContaining: monthStart, calendar: calendar),
                   candidate > date {
                    return candidate
                }
                guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
                monthStart = next
            }
            return nil

        case .quarterly:
            // Anchored to `dueMonth`: fires in months congruent to it mod 3.
            var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            for _ in 0..<36 {
                let month = calendar.component(.month, from: monthStart)
                if (month - dueMonth) %% 3 == 0,
                   let candidate = PaydayCalculator.clampedDate(dayOfMonth: dueDay, inMonthContaining: monthStart, calendar: calendar),
                   candidate > date {
                    return candidate
                }
                guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
                monthStart = next
            }
            return nil

        case .yearly:
            var yearStart = calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
            for _ in 0..<3 {
                var components = calendar.dateComponents([.year], from: yearStart)
                components.month = dueMonth
                if let monthDate = calendar.date(from: components),
                   let candidate = PaydayCalculator.clampedDate(dayOfMonth: dueDay, inMonthContaining: monthDate, calendar: calendar),
                   candidate > date {
                    return candidate
                }
                guard let next = calendar.date(byAdding: .year, value: 1, to: yearStart) else { return nil }
                yearStart = next
            }
            return nil
        }
    }

    /// All due dates inside `range`.
    static func dueDates(
        frequency: BillFrequency,
        dueDay: Int,
        dueMonth: Int,
        dueWeekday: Int?,
        in range: DateInterval,
        calendar: Calendar = .current,
        limit: Int = 60
    ) -> [Date] {
        var results: [Date] = []
        var cursor = range.start.addingTimeInterval(-1)
        while results.count < limit {
            guard let next = nextDueDate(
                frequency: frequency,
                dueDay: dueDay,
                dueMonth: dueMonth,
                dueWeekday: dueWeekday,
                after: cursor,
                calendar: calendar
            ), next <= range.end else { break }
            if next >= range.start { results.append(next) }
            cursor = next
        }
        return results
    }
}

/// True mathematical modulo (Swift's `%` can return negatives).
infix operator %%: MultiplicationPrecedence
func %% (lhs: Int, rhs: Int) -> Int {
    let remainder = lhs % rhs
    return remainder >= 0 ? remainder : remainder + rhs
}
