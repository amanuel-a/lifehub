//
//  AppSettings.swift
//  LifeHub
//

import Foundation
import SwiftData

/// Singleton settings record. The PIN itself is stored in the Keychain,
/// never in the database.
@Model
final class AppSettings {
    /// Fixed key so exactly one instance exists.
    @Attribute(.unique) var key: String
    var currencyCode: String
    /// Default early-warning days for each reminder family (all adjustable).
    var rentRemindBeforeDays: Int
    var billRemindBeforeDays: Int
    var debtRemindBeforeDays: Int
    var loanRemindBeforeDays: Int
    /// Default event reminder, minutes before start.
    var eventReminderMinutes: Int
    /// Hour of the morning (0–23) for payday / day-of reminders.
    var reminderHour: Int
    /// Unlock with Face ID / Touch ID in addition to the PIN.
    var useBiometrics: Bool
    /// "system", "en", or "am".
    var languageCode: String
    /// Fire the end-of-month review summary notification.
    var monthlyReviewEnabled: Bool
    /// Celebrate work anniversaries.
    var anniversaryRemindersEnabled: Bool
    /// Pull meetings/events from the device's calendars (incl. Google accounts
    /// added in iOS Settings) into the app's calendar and agenda.
    var syncDeviceCalendars: Bool = false

    init() {
        self.key = "app-settings"
        self.currencyCode = "USD"
        self.rentRemindBeforeDays = 3
        self.billRemindBeforeDays = 1
        self.debtRemindBeforeDays = 3
        self.loanRemindBeforeDays = 3
        self.eventReminderMinutes = 30
        self.reminderHour = 8
        self.useBiometrics = true
        self.languageCode = "system"
        self.monthlyReviewEnabled = true
        self.anniversaryRemindersEnabled = true
        self.syncDeviceCalendars = false
    }

    /// Fetches the singleton, creating and seeding defaults on first launch.
    static func fetchOrCreate(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
