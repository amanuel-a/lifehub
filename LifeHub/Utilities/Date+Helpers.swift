//
//  Date+Helpers.swift
//  LifeHub
//

import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// "Today", "Tomorrow", "In 5 days", "3 days ago" — for countdowns.
    var relativeDayDescription: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date.now.startOfDay, to: startOfDay).day ?? 0
        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        case -1: return String(localized: "Yesterday")
        case 2...: return String(localized: "In \(days) days")
        default: return String(localized: "\(-days) days ago")
        }
    }

    /// Days from today (start-of-day to start-of-day).
    var daysFromToday: Int {
        Calendar.current.dateComponents([.day], from: Date.now.startOfDay, to: startOfDay).day ?? 0
    }
}
