//
//  EmptyStateView.swift
//  LifeHub
//

import SwiftUI

/// A friendly, native empty state built on `ContentUnavailableView`.
struct EmptyStateView: View {
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey
    let symbolName: String

    var body: some View {
        ContentUnavailableView {
            Label(titleKey, systemImage: symbolName)
        } description: {
            Text(messageKey)
        }
    }
}
