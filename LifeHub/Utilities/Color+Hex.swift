//
//  Color+Hex.swift
//  LifeHub
//

import SwiftUI

extension Color {
    /// Creates a color from "#RRGGBB" / "RRGGBB".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.5; g = 0.5; b = 0.5
        }
        self.init(red: r, green: g, blue: b)
    }
}

/// The palette offered in category / group editors.
enum PaletteColors {
    static let hexes: [String] = [
        "#F97316", "#EAB308", "#22C55E", "#06B6D4", "#3B82F6",
        "#6E7DF6", "#8B5CF6", "#EC4899", "#EF4444", "#6B7280"
    ]
}
