//
//  AppRouter.swift
//  LifeHub
//

import Foundation
import Observation

/// The app's tabs.
enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case money
    case projects
    case calendar
    case tasks
    case notes

    var id: String { rawValue }
}

/// Lightweight navigation coordinator so notifications and App Intents can
/// deep-link into the right tab.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var selectedTab: AppTab = .dashboard
    /// Set to present the matching quick-add sheet from anywhere.
    var pendingQuickAdd: QuickAddKind?

    enum QuickAddKind: String, Identifiable {
        case expense, income, task, note, event
        var id: String { rawValue }
    }

    func route(toCategoryRaw raw: String, uuid: UUID?) {
        switch raw {
        case NotificationScheduler.Category.payday.rawValue,
             NotificationScheduler.Category.bill.rawValue,
             NotificationScheduler.Category.loan.rawValue,
             NotificationScheduler.Category.debt.rawValue:
            selectedTab = .money
        case NotificationScheduler.Category.event.rawValue:
            selectedTab = .calendar
        case NotificationScheduler.Category.task.rawValue:
            selectedTab = .tasks
        default:
            selectedTab = .dashboard
        }
    }
}
