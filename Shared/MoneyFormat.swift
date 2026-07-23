//
//  MoneyFormat.swift
//  LifeHub (app + widgets)
//

import Foundation

/// Currency formatting shared by the app and widgets.
/// Amounts always show thousands separators (per the requirements) and use
/// the configured currency, defaulting to Ethiopian Birr.
enum MoneyFormat {
    /// "12,500 ETB" style — whole numbers unless cents exist.
    static func string(_ amount: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = hasFraction(amount) ? 2 : 0
        let number = NSDecimalNumber(decimal: amount)
        let digits = formatter.string(from: number) ?? "\(amount)"
        return "\(digits) \(code)"
    }

    /// Compact form for tight widget spaces: "12.5K ETB".
    static func compactString(_ amount: Decimal, code: String) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        let formatted: String
        switch absValue {
        case 1_000_000...:
            formatted = String(format: "%@%.1fM", sign, absValue / 1_000_000)
        case 10_000...:
            formatted = String(format: "%@%.1fK", sign, absValue / 1_000)
        default:
            return string(amount, code: code)
        }
        return "\(formatted) \(code)"
    }

    private static func hasFraction(_ amount: Decimal) -> Bool {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded != amount
    }
}
