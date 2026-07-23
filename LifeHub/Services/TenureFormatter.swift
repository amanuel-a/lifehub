//
//  TenureFormatter.swift
//  LifeHub
//

import Foundation

/// Formats job tenure like "1 year, 4 months" — the "how long have I stayed
/// at this company" number the requirements call for.
enum TenureFormatter {
    static func string(from start: Date, to end: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: start, to: max(start, end))
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0

        var formatter: DateComponentsFormatter {
            let f = DateComponentsFormatter()
            f.unitsStyle = .full
            f.maximumUnitCount = 2
            f.calendar = calendar
            return f
        }

        let f = formatter
        if years > 0 {
            f.allowedUnits = [.year, .month]
        } else if months > 0 {
            f.allowedUnits = [.month, .day]
        } else {
            f.allowedUnits = [.day]
        }
        var comps = DateComponents()
        comps.year = years
        comps.month = months
        comps.day = max(days, years == 0 && months == 0 ? 1 : 0)
        return f.string(from: comps) ?? ""
    }
}
