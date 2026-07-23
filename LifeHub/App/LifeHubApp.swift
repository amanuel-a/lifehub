//
//  LifeHubApp.swift
//  LifeHub
//

import SwiftUI
import SwiftData
import UserNotifications

/// Holds the app-wide model container so the app delegate and App Intents
/// can reach it without recreating stores.
enum AppContainer {
    static let shared: ModelContainer = ModelContainerFactory.makeContainer()
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private var notificationHandler: NotificationHandler?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let handler = NotificationHandler(container: AppContainer.shared)
        notificationHandler = handler
        UNUserNotificationCenter.current().delegate = handler
        NotificationScheduler.registerCategories()
        return true
    }
}

@main
struct LifeHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppContainer.shared)
    }
}
