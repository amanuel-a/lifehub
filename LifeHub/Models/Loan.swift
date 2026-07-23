//
//  Loan.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A bank or formal loan with a fixed installment schedule.
@Model
final class Loan {
    @Attribute(.unique) var uuid: UUID
    var lender: String
    var principal: Decimal
    var totalRepayable: Decimal
    var installmentAmount: Decimal
    var frequencyRaw: String
    /// The next installment due date. Advanced by one period each time an
    /// installment is recorded.
    var nextDueDate: Date
    var startDate: Date
    var note: String
    var isClosed: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LoanPayment.loan)
    var payments: [LoanPayment] = []

    init(
        lender: String,
        principal: Decimal,
        totalRepayable: Decimal,
        installmentAmount: Decimal,
        frequency: LoanFrequency = .monthly,
        nextDueDate: Date,
        startDate: Date = .now,
        note: String = ""
    ) {
        self.uuid = UUID()
        self.lender = lender
        self.principal = principal
        self.totalRepayable = totalRepayable
        self.installmentAmount = installmentAmount
        self.frequencyRaw = frequency.rawValue
        self.nextDueDate = nextDueDate
        self.startDate = startDate
        self.note = note
        self.isClosed = false
        self.createdAt = .now
    }

    var frequency: LoanFrequency {
        get { LoanFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var totalPaid: Decimal {
        payments.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Remaining balance out of the total repayable (never below zero).
    var remainingBalance: Decimal {
        max(0, totalRepayable - totalPaid)
    }

    /// Progress from 0 to 1, safe against a zero total.
    var progress: Double {
        guard totalRepayable > 0 else { return 0 }
        let paid = NSDecimalNumber(decimal: totalPaid).doubleValue
        let total = NSDecimalNumber(decimal: totalRepayable).doubleValue
        return min(1, max(0, paid / total))
    }

    /// Payments sorted newest first.
    var sortedPayments: [LoanPayment] {
        payments.sorted { $0.date > $1.date }
    }

    /// Upcoming installment due dates inside `range` (used by the calendar).
    func dueDates(in range: DateInterval, calendar: Calendar = .current) -> [Date] {
        guard !isClosed else { return [] }
        var results: [Date] = []
        var cursor = nextDueDate
        var guardCounter = 0
        while cursor <= range.end && guardCounter < 120 {
            if cursor >= range.start { results.append(cursor) }
            guard let next = calendar.date(byAdding: frequency.dateComponents, to: cursor) else { break }
            cursor = next
            guardCounter += 1
        }
        return results
    }

    /// Records an installment payment and advances the schedule.
    func recordInstallment(amount: Decimal? = nil, date: Date = .now, calendar: Calendar = .current) {
        let payment = LoanPayment(amount: amount ?? installmentAmount, date: date)
        payment.loan = self
        payments.append(payment)
        if let advanced = calendar.date(byAdding: frequency.dateComponents, to: nextDueDate) {
            nextDueDate = advanced
        }
        if remainingBalance == 0 { isClosed = true }
    }
}

/// One installment paid against a loan.
@Model
final class LoanPayment {
    @Attribute(.unique) var uuid: UUID
    var amount: Decimal
    var date: Date
    var loan: Loan?

    init(amount: Decimal, date: Date = .now) {
        self.uuid = UUID()
        self.amount = amount
        self.date = date
    }
}
