//
//  CountdownActivityAttributes.swift
//  LifeHub (app + widgets)
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// A Live Activity counting down to a money milestone — the next payday,
/// rent due day, or a loan installment — on the Lock Screen and in the
/// Dynamic Island.
struct CountdownActivityAttributes: ActivityAttributes {
    enum Kind: String, Codable, Sendable {
        case payday
        case rent
        case loan
        case debt

        var symbolName: String {
            switch self {
            case .payday: "banknote.fill"
            case .rent: "house.fill"
            case .loan: "building.columns.fill"
            case .debt: "person.2.fill"
            }
        }
    }

    struct ContentState: Codable, Hashable, Sendable {
        /// The moment being counted down to.
        var targetDate: Date
        /// Marked true once the owner confirms receipt / payment.
        var isDone: Bool = false
    }

    var kind: Kind
    var title: String
    var amount: Decimal
    var currencyCode: String
}
#endif
