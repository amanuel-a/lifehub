//
//  PaydayCalculator.swift
//  LifeHub
//

import Foundation

/// Pure date math for payday schedules: "every Friday", "every other Friday
/// anchored to a known payday", "the 28th of each month" (clamped to short
/// months).
enum PaydayCalculator {
    /// The next payday strictly after `date`. Returns start-of-day dates;
    /// the notification scheduler applies the reminder hour.
    static func nextPayday(
        frequency: PayFrequency,
        weekday: Int?,
        biweeklyAnchor: Date?,
        dayOfMonth: Int?,
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch frequency {
        case .weekly:
            guard let weekday else { return nil }
            return nextWeekday(weekday, after: date, calendar: calendar)

        case .biweekly:
            if let anchor = biweeklyAnchor {
                let anchorDay = calendar.startOfDay(for: anchor)
                var candidate = anchorDay
                // Roll the anchor forward in 14-day steps until past `date`.
                for _ in 0..<2000 {
                    if candidate > date { return candidate }
                    guard let next = calendar.date(byAdding: .day, value: 14, to: candidate) else { return nil }
                    candidate = next
                }
                return nil
            }
            // Without an anchor, fall back to the next matching weekday.
            guard let weekday else { return nil }
            return nextWeekday(weekday, after: date, calendar: calendar)

        case .monthly:
            guard let dayOfMonth else { return nil }
            var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            for _ in 0..<24 {
                if let candidate = clampedDate(dayOfMonth: dayOfMonth, inMonthContaining: monthStart, calendar: calendar),
                   candidate > date {
                    return candidate
                }
                guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
                monthStart = next
            }
            return nil
        }
    }

    /// All paydays inside `range`.
    static func paydays(
        frequency: PayFrequency,
        weekday: Int?,
        biweeklyAnchor: Date?,
        dayOfMonth: Int?,
        in range: DateInterval,
        calendar: Calendar = .current,
        limit: Int = 60
    ) -> [Date] {
        var results: [Date] = []
        var cursor = range.start.addingTimeInterval(-1)
        while results.count < limit {
            guard let next = nextPayday(
                frequency: frequency,
                weekday: weekday,
                biweeklyAnchor: biweeklyAnchor,
                dayOfMonth: dayOfMonth,
                after: cursor,
                calendar: calendar
            ), next <= range.end else { break }
            if next >= range.start { results.append(next) }
            cursor = next
        }
        return results
    }

    // MARK: - Helpers

    private static func nextWeekday(_ weekday: Int, after date: Date, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        return calendar.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        ).map(calendar.startOfDay(for:))
    }

    /// The requested day-of-month clamped to the month's length
    /// (the 31st becomes Feb 28/29, Apr 30, …).
    static func clampedDate(dayOfMonth: Int, inMonthContaining date: Date, calendar: Calendar) -> Date? {
        guard let dayRange = calendar.range(of: .day, in: .month, for: date) else { return nil }
        let day = min(max(dayOfMonth, 1), dayRange.upperBound - 1)
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = day
        return calendar.date(from: components).map(calendar.startOfDay(for:))
    }
}
