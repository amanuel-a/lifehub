//
//  Decimal+Parsing.swift
//  LifeHub
//

import Foundation

extension Decimal {
    /// Parses user-typed amounts, tolerating grouping separators and either
    /// decimal separator ("12,500.50", "12 500,50", "12500").
    static func fromUserInput(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try the current locale first.
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let number = formatter.number(from: trimmed) {
            return number.decimalValue
        }

        // Fall back to a normalized plain form.
        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Decimal(string: normalized)
    }

    var isPositive: Bool { self > 0 }
}
