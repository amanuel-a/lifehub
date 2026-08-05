//
//  MoneyFormat.swift
//  LifeHub (app + widgets)
//

import Foundation

/// Currency formatting shared by the app and widgets.
/// Amounts always show thousands separators (per the requirements) and use
/// the configured currency, defaulting to US Dollars.
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

    // MARK: Per-currency totals

    /// How to show a per-currency total on one card or widget: a main amount
    /// in one currency plus an optional "+ 100 USD" line for other buckets.
    /// Amounts are never converted.
    struct TotalDisplay {
        var amount: Decimal = 0
        var code: String
        var extra: String?
    }

    /// Picks the app-currency bucket as the main amount (or the largest other
    /// bucket when the app-currency one is empty) and formats the rest.
    static func display(of totals: [String: Decimal], appCurrency: String) -> TotalDisplay {
        var buckets = totals.filter { $0.value != 0 }
        let mainCode: String
        if buckets[appCurrency] != nil || buckets.isEmpty {
            mainCode = appCurrency
        } else {
            mainCode = buckets.max { $0.value < $1.value }!.key
        }
        let main = buckets.removeValue(forKey: mainCode) ?? 0
        let extra = buckets
            .sorted { $0.key < $1.key }
            .map { "+ \(compactString($0.value, code: $0.key))" }
            .joined(separator: "  ")
        return TotalDisplay(amount: main, code: mainCode, extra: extra.isEmpty ? nil : extra)
    }
}
