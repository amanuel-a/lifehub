//
//  Expense.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A single expense. Designed so logging takes seconds: amount, category,
/// date, optional note, and an optional receipt photo.
@Model
final class Expense {
    @Attribute(.unique) var uuid: UUID
    var amount: Decimal
    var date: Date
    var note: String
    var category: ExpenseCategory?
    /// Set when this expense was created by paying a recurring bill (e.g. rent),
    /// which is how the rent payment history is built.
    var bill: RecurringBill?
    /// Optional receipt photo, stored outside the database file.
    @Attribute(.externalStorage) var receiptImageData: Data?
    var createdAt: Date

    init(
        amount: Decimal,
        date: Date = .now,
        note: String = "",
        category: ExpenseCategory? = nil,
        bill: RecurringBill? = nil,
        receiptImageData: Data? = nil
    ) {
        self.uuid = UUID()
        self.amount = amount
        self.date = date
        self.note = note
        self.category = category
        self.bill = bill
        self.receiptImageData = receiptImageData
        self.createdAt = .now
    }
}
