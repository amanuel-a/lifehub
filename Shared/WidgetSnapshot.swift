//
//  WidgetSnapshot.swift
//  LifeHub (app + widgets)
//
//  The app serializes a small, glanceable snapshot into the app group after
//  every meaningful change; widgets read it without needing database access.
//

import Foundation

/// Everything the widgets need, precomputed by the app.
struct WidgetSnapshot: Codable, Sendable {
    struct PaydayInfo: Codable, Sendable {
        var sourceName: String
        var amount: Decimal
        var date: Date
        /// The source's own currency; nil falls back to the app currency.
        var currencyCode: String?
    }

    struct DueInfo: Codable, Sendable {
        var title: String
        var amount: Decimal
        var date: Date
    }

    struct AgendaLine: Codable, Sendable {
        var title: String
        var time: Date?
        var symbolName: String
    }

    struct TaskLine: Codable, Sendable, Identifiable {
        var id: String
        var title: String
        var due: Date?
        var overdue: Bool
    }

    struct NoteLine: Codable, Sendable, Identifiable {
        var id: String
        var title: String
        var snippet: String
        var pinned: Bool
    }

    struct ProjectLine: Codable, Sendable, Identifiable {
        var id: String
        var name: String
        var status: String
        var progress: Double
    }

    var generatedAt: Date = .now
    var currencyCode: String = "USD"

    // Money at a glance
    var monthIncome: Decimal = 0
    var monthExpenses: Decimal = 0
    var totalIOwe: Decimal = 0
    var totalOwedToMe: Decimal = 0

    // Per-currency buckets (amounts as entered, never converted) so widgets
    // show exactly what the app's cards show.
    var monthIncomeByCurrency: [String: Decimal] = [:]
    var iOweByCurrency: [String: Decimal] = [:]
    var owedToMeByCurrency: [String: Decimal] = [:]

    // Upcoming
    var nextPayday: PaydayInfo?
    var nextRent: DueInfo?
    var nextBill: DueInfo?
    var nextLoanInstallment: DueInfo?

    // Today
    var todayLines: [AgendaLine] = []
    var openTaskCount: Int = 0

    // Lists for the dedicated widgets
    var openTasks: [TaskLine] = []
    var recentNotes: [NoteLine] = []
    var projects: [ProjectLine] = []
    var activeProjectCount: Int = 0

    var monthSavings: Decimal { monthIncome - monthExpenses }
}

/// Reads and writes the snapshot in the shared app group.
enum WidgetSnapshotStore {
    private static let storageKey = "widget-snapshot-v1"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: storageKey)
    }

    static func load() -> WidgetSnapshot {
        guard
            let data = AppGroup.defaults.data(forKey: storageKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return WidgetSnapshot()
        }
        return snapshot
    }
}
