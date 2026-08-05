//
//  AppGroup.swift
//  LifeHub (app + widgets)
//

import Foundation

/// The shared app-group container used by the app, widgets, and Live Activities.
enum AppGroup {
    static let identifier = "group.app.startupagile.lifehub"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// Task UUIDs completed from an interactive widget, applied by the app on
    /// its next launch / foreground.
    static let pendingCompletedTasksKey = "pending-completed-task-ids"
}
