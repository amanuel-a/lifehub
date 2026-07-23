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
}
