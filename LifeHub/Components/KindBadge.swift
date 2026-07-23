//
//  KindBadge.swift
//  LifeHub
//

import SwiftUI

/// The color-coded icon shown next to every agenda item, keyed by type.
struct KindBadge: View {
    let kind: AgendaKind
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(kind.tint)
            .frame(width: size, height: size)
            .background(kind.tint.opacity(0.14), in: .circle)
            .accessibilityLabel(Text(kind.titleKey))
    }
}

/// A small colored circle with an SF Symbol — categories, groups, sources.
struct SymbolBadge: View {
    let symbolName: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .circle)
    }
}
