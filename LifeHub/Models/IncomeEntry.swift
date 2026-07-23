//
//  IncomeEntry.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A single received payment — created automatically when the owner confirms
/// a payday, or added manually for one-off income.
@Model
final class IncomeEntry {
    @Attribute(.unique) var uuid: UUID
    var amount: Decimal
    var dateReceived: Date
    var note: String
    var source: IncomeSource?

    init(amount: Decimal, dateReceived: Date = .now, note: String = "", source: IncomeSource? = nil) {
        self.uuid = UUID()
        self.amount = amount
        self.dateReceived = dateReceived
        self.note = note
        self.source = source
    }
}
