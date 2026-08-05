//
//  LifeHubWidgetBundle.swift
//  LifeHubWidgets
//

import WidgetKit
import SwiftUI

@main
struct LifeHubWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TasksWidget()
        NotesWidget()
        ProjectsWidget()
        MoneyWidget()
        PaydayWidget()
        CountdownLiveActivity()
    }
}

// MARK: - Shared timeline plumbing

/// One entry carrying the app-produced snapshot.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// All widgets read the same snapshot the app writes to the app group.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot: WidgetSnapshot = context.isPreview ? .placeholder : WidgetSnapshotStore.load()
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        // The app pushes reloads on every change; refresh hourly as a fallback
        // so countdown labels stay honest.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension WidgetSnapshot {
    /// Sample data for widget gallery previews.
    static var placeholder: WidgetSnapshot {
        var snapshot = WidgetSnapshot()
        snapshot.currencyCode = "USD"
        snapshot.monthIncome = 48_000
        snapshot.monthExpenses = 21_500
        snapshot.totalIOwe = 5_000
        snapshot.totalOwedToMe = 2_000
        snapshot.monthIncomeByCurrency = ["USD": 48_000]
        snapshot.iOweByCurrency = ["USD": 5_000]
        snapshot.owedToMeByCurrency = ["USD": 2_000]
        snapshot.nextPayday = .init(sourceName: "Kayo", amount: 40_000, date: .now.addingTimeInterval(3 * 86_400))
        snapshot.nextRent = .init(title: "Rent", amount: 9_000, date: .now.addingTimeInterval(6 * 86_400))
        snapshot.todayLines = [
            .init(title: "Team standup", time: .now.addingTimeInterval(3_600), symbolName: "calendar"),
            .init(title: "Backup laptop", time: nil, symbolName: "checkmark.circle.fill"),
            .init(title: "Pay electricity", time: nil, symbolName: "doc.text.fill")
        ]
        snapshot.openTaskCount = 4
        snapshot.openTasks = [
            .init(id: "1", title: "Finish widget design", due: .now, overdue: false),
            .init(id: "2", title: "Pay electricity bill", due: .now.addingTimeInterval(-86_400), overdue: true),
            .init(id: "3", title: "Call the landlord", due: .now.addingTimeInterval(2 * 86_400), overdue: false),
            .init(id: "4", title: "Buy groceries", due: nil, overdue: false)
        ]
        snapshot.recentNotes = [
            .init(id: "1", title: "Project ideas", snippet: "A budgeting app for freelancers…", pinned: true),
            .init(id: "2", title: "Groceries", snippet: "Milk, eggs, coffee", pinned: false),
            .init(id: "3", title: "Meeting notes", snippet: "Ship v1 by Friday", pinned: false)
        ]
        snapshot.projects = [
            .init(id: "1", name: "LifeHub", status: "Active", progress: 0.6),
            .init(id: "2", name: "Side Store", status: "Planning", progress: 0.2)
        ]
        snapshot.activeProjectCount = 2
        return snapshot
    }
}

/// Relative day text used across widgets ("Today", "Tomorrow", "In 5 days").
func relativeDayText(for date: Date) -> String {
    let calendar = Calendar.current
    let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: .now),
        to: calendar.startOfDay(for: date)
    ).day ?? 0
    switch days {
    case 0: return String(localized: "Today")
    case 1: return String(localized: "Tomorrow")
    case 2...: return String(localized: "In \(days) days")
    default: return String(localized: "Overdue")
    }
}
