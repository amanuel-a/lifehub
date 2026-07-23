//
//  ExpenseCategory.swift
//  LifeHub
//

import Foundation
import SwiftData

/// An editable spending category. Ships with sensible defaults (rent, food,
/// transport, …) and supports an optional monthly budget with warnings.
@Model
final class ExpenseCategory {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var symbolName: String
    var colorHex: String
    var sortOrder: Int
    /// Optional simple budget: warn when the month's spending approaches this.
    var monthlyBudget: Decimal?

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(name: String, symbolName: String = "tag.fill", colorHex: String = "#6E7DF6", sortOrder: Int = 0, monthlyBudget: Decimal? = nil) {
        self.uuid = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.monthlyBudget = monthlyBudget
    }

    /// The default category set from the requirements document.
    static func defaultCategories() -> [ExpenseCategory] {
        let defaults: [(String, String, String)] = [
            ("Rent", "house.fill", "#F97316"),
            ("Food", "fork.knife", "#22C55E"),
            ("Transport", "bus.fill", "#3B82F6"),
            ("Utilities", "bolt.fill", "#EAB308"),
            ("Phone", "iphone", "#8B5CF6"),
            ("Family", "figure.2.and.child.holdinghands", "#EC4899"),
            ("Fun", "party.popper.fill", "#06B6D4"),
            ("Other", "tag.fill", "#6B7280")
        ]
        return defaults.enumerated().map { index, item in
            ExpenseCategory(name: item.0, symbolName: item.1, colorHex: item.2, sortOrder: index)
        }
    }
}
