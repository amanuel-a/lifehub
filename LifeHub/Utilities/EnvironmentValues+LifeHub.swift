//
//  EnvironmentValues+LifeHub.swift
//  LifeHub
//

import SwiftUI

private struct CurrencyCodeKey: EnvironmentKey {
    static let defaultValue: String = "USD"
}

extension EnvironmentValues {
    /// The configured currency code, injected at the root from settings so
    /// every view formats money consistently.
    var currencyCode: String {
        get { self[CurrencyCodeKey.self] }
        set { self[CurrencyCodeKey.self] = newValue }
    }
}
