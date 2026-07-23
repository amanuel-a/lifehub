//
//  CalendarEvent.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A calendar event with optional location, notes, repeat rule, and reminders.
@Model
final class CalendarEvent {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var startDate: Date
    /// Duration in minutes; 0 means a point-in-time event.
    var durationMinutes: Int
    var isAllDay: Bool
    var location: String
    var notes: String
    var repeatRule: RepeatRule
    /// Reminder offsets in minutes before the start (0 = at time of event).
    var reminderMinutesBefore: [Int]
    var createdAt: Date

    init(
        title: String,
        startDate: Date,
        durationMinutes: Int = 60,
        isAllDay: Bool = false,
        location: String = "",
        notes: String = "",
        repeatRule: RepeatRule = .never,
        reminderMinutesBefore: [Int] = [30]
    ) {
        self.uuid = UUID()
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.repeatRule = repeatRule
        self.reminderMinutesBefore = reminderMinutesBefore
        self.createdAt = .now
    }

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    /// Occurrence start dates inside `range`, honoring the repeat rule.
    func occurrences(in range: DateInterval, calendar: Calendar = .current) -> [Date] {
        repeatRule.repeats
            ? repeatRule.occurrences(in: range, anchoredTo: startDate, calendar: calendar)
            : (range.contains(startDate) ? [startDate] : [])
    }

    /// The next occurrence at or after `date`.
    func nextOccurrence(onOrAfter date: Date = .now, calendar: Calendar = .current) -> Date? {
        if startDate >= date { return startDate }
        guard repeatRule.repeats else { return nil }
        return repeatRule.nextOccurrence(after: date, anchoredTo: startDate, calendar: calendar)
    }
}
