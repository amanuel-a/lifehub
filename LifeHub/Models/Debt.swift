//
//  Debt.swift
//  LifeHub
//

import Foundation
import SwiftData

/// Money between the owner and another person, in either direction.
/// Supports partial repayments; the remaining balance is always derived
/// from the original amount minus recorded repayments.
@Model
final class Debt {
    @Attribute(.unique) var uuid: UUID
    var person: String
    var directionRaw: String
    var originalAmount: Decimal
    var date: Date
    var dueDate: Date?
    var note: String
    var isSettled: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DebtPayment.debt)
    var repayments: [DebtPayment] = []

    init(
        person: String,
        direction: DebtDirection,
        amount: Decimal,
        date: Date = .now,
        dueDate: Date? = nil,
        note: String = ""
    ) {
        self.uuid = UUID()
        self.person = person
        self.directionRaw = direction.rawValue
        self.originalAmount = amount
        self.date = date
        self.dueDate = dueDate
        self.note = note
        self.isSettled = false
        self.createdAt = .now
    }

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .iOwe }
        set { directionRaw = newValue.rawValue }
    }

    var totalRepaid: Decimal {
        repayments.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Remaining balance after all partial repayments (never below zero).
    var remaining: Decimal {
        max(0, originalAmount - totalRepaid)
    }

    var isFullyRepaid: Bool { remaining == 0 }

    /// Repayments sorted newest first.
    var sortedRepayments: [DebtPayment] {
        repayments.sorted { $0.date > $1.date }
    }

    /// Records a partial (or full) repayment and settles the debt when cleared.
    func addRepayment(amount: Decimal, date: Date = .now, note: String = "") {
        let payment = DebtPayment(amount: amount, date: date, note: note)
        payment.debt = self
        repayments.append(payment)
        if remaining == 0 { isSettled = true }
    }
}

/// One repayment against a debt.
@Model
final class DebtPayment {
    @Attribute(.unique) var uuid: UUID
    var amount: Decimal
    var date: Date
    var note: String
    var debt: Debt?

    init(amount: Decimal, date: Date = .now, note: String = "") {
        self.uuid = UUID()
        self.amount = amount
        self.date = date
        self.note = note
    }
}
